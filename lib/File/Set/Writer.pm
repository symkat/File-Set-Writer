package File::Set::Writer;
use warnings;
use strict;
use Scalar::Util qw( looks_like_number );

my @attrs = qw( max_handles max_lines max_files line_join );
my @extra_attrs = qw( expire_files_batch_size expire_handles_batch_size );

sub new {
    my ( $class, @args ) = @_;
    my %args = @args == 1 ? %{ $args[0] } : @args;
    my $self = bless {
        max_lines       => 500,
        max_files       => 100,
        line_join       => "\n",
    }, $class;

    foreach my $method ( @attrs, @extra_attrs ) {
        $self->$method( delete $args{$method} )
            if exists $args{$method};
    }

    die "Error: Unknown class arguments: " . join(", ", keys %args) . "."
        if ( keys %args );

    die "Error: max_handles is a required class argument"
        unless looks_like_number $self->max_handles;

    return $self;
}

# Create accessors
foreach my $attr ( @attrs ) {
    no strict 'refs';
    *$attr = sub {
        my $self = shift;
        $self->{$attr} = shift if @_;

        die "Error: $attr MUST be a number"
            unless looks_like_number($self->{$attr}) or $attr eq 'line_join';

        return $self->{$attr};
    };
}

# If the user doesn't set a batch_size for files or handles
# we will use 20% of max_(files|handles).  This will be updated
# if max_files or max_handles is updated _unless_ the user explictly
# sets the batch_size, at which point it becomes their responsiblity
# to manage the values.

sub expire_files_batch_size {
    my ( $self, $value ) = @_;

    return $self->{expire_files_batch_size}
        if exists $self->{expire_files_batch_size};

    return int( $self->max_files / 5 )
        unless $value;
    
    die "Error: expire_files_batch_size MUST be a number"
        unless looks_like_number $value;

    return $self->{expire_files_batch_size} = $value;
}

sub expire_handles_batch_size {
    my ( $self, $value ) = @_;

    return $self->{expire_handles_batch_size}
        if exists $self->{expire_handles_batch_size};

    return int( $self->max_handles / 5 )
        unless $value;

    die "Error: expire_handles_batch_size MUST be a number"
        unless looks_like_number $value;

    return $self->{expire_handles_batch_size} = $value;
}

sub print {
    my ( $self, $file, @lines ) = @_;
    
    push @{$self->{queue}->{$file}}, @lines;

    $self->_write_file( $file )
        if @{$self->{queue}->{$file}} >= $self->max_lines;

    $self->_write_pending_files 
        if $self->_files >= $self->max_files;
    
    return $self;
}

sub _write_pending_files {
    my ( $self ) = @_;
            
    my @files = sort { 
        scalar @{$self->{queue}->{$a} || []} <=> scalar @{$self->{queue}->{$b} || []}
    } keys %{$self->{queue}};

    foreach my $i ( 0 .. $self->expire_files_batch_size ) {
        $self->_write_file( $files[$i] ) if $files[$i];
    }
}

sub _close_pending_filehandles {
    my ( $self )  = @_;

    my @files = sort { 
        $self->{fcache}->{$a}->{stamp} <=> $self->{fcache}->{$b}->{stamp}
    } keys %{$self->{fcache}};
    
    foreach my $i ( 0 .. $self->expire_handles_batch_size ) {
        last unless $files[$i];
        delete $self->{fcache}->{$files[$i]};
    }
}

sub _write_file {
    my ( $self, $file ) = @_;

    die "Error _write_file called with invalid argument \"$file\""
        unless defined $file and exists $self->{queue}->{$file};

    $self->_write( 
        $file, 
        join( $self->line_join, @{$self->{queue}->{$file}} ) . $self->line_join
    );
    delete $self->{queue}->{$file};
}

sub _write {
    my ( $self, $file, @contents ) = @_;
        
    if ( $self->_handles >= $self->max_handles ) {
        $self->_close_pending_filehandles();
    }

    if ( ! exists $self->{fcache}->{$file} ) {
        open my $new_fh, ">>", $file
            or die "Failed to open $file for writing: $!";
        $self->{fcache}->{$file} = {
            fh          => $new_fh,
            name        => $file,
            stamp       => time(),
        };
    }

    my $wfh = $self->{fcache}->{$file}->{fh};
    my $content = join ("", @contents);
    print $wfh $content
        or die "Failed to write $file: $!";
    $self->{fcache}->{$file}->{stamp} = time;
}

# Write all staged data to disk and closes all currently-open
# file handles.  This happens automatically at the objects 
# destruction.

sub _sync {
    my ( $self ) = @_;
    
    foreach my $file ( keys %{$self->{queue}} ) {
        $self->_write_file( $file );
    }

    return $self;
}

# Return the count of open file handles currently in the cache.

sub _handles {
    return scalar keys %{ shift->{fcache} || {} };
}

# Return the count of files currently staged for being written.

sub _files {
    return scalar keys %{ shift->{queue} || {} };
}

# $self->_lines( "filename" );
#
# Return the count of lines staged for the given filename.

sub _lines {
    return scalar @{ shift->{queue}->{ shift() } || [] };
}

# Push our buffered arrays into the file handles before
# we close the file handles.
sub DESTROY { shift->_sync; }

1;


__END__

=head1 NAME

File::Set::Writer - Buffered writes with a file handle pool

=head1 DESCRIPTION

File::Set::Writer gives you the ability to write to many different 
file handles without worrying about breaking file handle limits.  
Additionally it can buffer writes so that a file is only written when
you have submitted N lines to write to the given file.  You can
place limits on the number of file handles, number of lines per
file, and number of files that can be buffered at once.  

The real-world use-case for this module is a situation where you have
one large file that must be split into thousands or hundreds of thousands
of files based on arbitrary conditions and want to avoid an Out Of Memory!
error while reducing the number of C<open>, C<close> and C<write> syscalls 
being made.

Write ALL the files.

=head1 SYNOPSIS

    my $writer = File::Set::Writer->new({
        max_handles               => 512,
        max_lines                 => 100,
        max_files                 => 500,
        expire_handles_batch_size => 200,
        expire_files_batch_size   => 200,
        line_join                 => '',
    });

    $writer->print( "somefile", "Hello World" );
    $writer->print( "thatotherfile", @lines );

=head1 CONSTRUCTOR

The constructor accepts the following parameters, and
each of the following may be called as a method on the
object after instantiation:

=over 4

=item max_handles (Required)

    $writer->max_handles( 512 );

How many files may be open at one time.  You MUST set this.

If you do not know how many open handles you might want you
should check C<ulimit -n> on your system and cut this number
in half.

When this number is meet or exceeded, the amount of file
handles given by expire_handles_batch_size will be closed
and deleted from the cache in order of the oldest-accessed
file handles.

=item max_lines

    $writer->max_lines( 500 );

How many lines may be queued per-file before the lines
are written to disk.  This defaults to 500.

=item max_files

    $writer->max_files( 100 )

How many files may be written to before some files are
automatically written to disk.  

When this number is meet or exceeded the amount of files
given by expire_files_batch_size will be written to disk
in order of which have the highest count of lines currently
buffered.

This defaults to 100.

=item expire_handles_batch_size

    $writer->expire_handles_batch_size( int($writer->max_handles * .2) );

The count of file handles to purge from the cache when 
max_handles has been reached or exceeded.

This defaults to 20% of max_handles.  If you manually
set it at any point the default will not be used.

=item expire_files_batch_size

    $writer->expire_files_batch_size( int($writer->max_files * .2) );

The count of files to be written to disk when max_files
has been reached or exceeded.

This defaults to 20% of max_files.  If you manually
set it at any point the default will not be used.

=item line_join

When writing to the disk, join the lines with the character
given here.

By default a UNIX newline is used.  Set to "" to disable new-lines 
in the join (but you should totally have a seperation of display logic 
and business logic!)

=back

=head1 METHODS

=head2 print

    $writer->print( "filename", @lines )

This is the only method that you would normally want to use.

Write lines to the given filename.  This will stage the data 
for the file in memory.  

Data will be written to disk in the following situations:

=over 4

=item * max_lines has been met for a given file.  The file will be written.

=item * max_files has been met.  The most-used files will be written.

=item * $writer goes out of scope.  Everything will be written.

=back

=head1 AUTHOR

SymKat I<E<lt>symkat@symkat.comE<gt>> ( Blog: L<http://symkat.com/> )

=head2 CONTRIBUTORS

=head1 COPYRIGHT

Copyright (c) 2012 the File::Set::Writer L</AUTHOR> and 
L</CONTRIBUTORS> as listed above.

=head1 LICENSE 

This library is free software and may be distributed under the 
same terms as perl itself.

=head2 AVAILABILITY

The most current version of File::Set::Writer can be found 
at L<https://github.com/symkat/File-Set-Writer>
