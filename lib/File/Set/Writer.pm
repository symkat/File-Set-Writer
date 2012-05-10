package File::Set::Writer;
use warnings;
use strict;


__END__

=head1 NAME

File::Set::Writer - Buffered writes with a file handle pool

=head1 DESCRIPTION

File::Set::Writer gives you the ability to write to many different 
file handles  without worrying about breaking file handle limits.  
Additionally it can buffer writes so that a file is only written when
you have submitted N lines to write to the given file.  You can
place limits on the number of file handles, number of lines per
file, and number of files that can be buffered at once.  Write ALL
the files without worrying.

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

=item max_handles

    $writer->max_handles( 512 );

How many files may be open at one time.  By default this
will use the number yielded from ulimit -n, subtracting
double the amount of file handles currently-used by your
process, plus 10.  You really should set this yourself.

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

Write lines to the given filename.  This will stage the data 
for the file in memory.  When max_lines has been reached
or exceeded for the given file, the file will be written 
to disk.  The file may be written before max_lines if
max_files has been exceeded and the file is selected as
one to write.

=head2 sync

    $writer->sync;

Write all staged data to disk.  This happens automatically
at the objects destruction.

=head2 handles

    $writer->handles;

Return the count of open file handles currently in the cache.

=head2 files

    $writer->files;

Return the count of files currently staged for being written.

=head2 lines 

    $writer->lines( "filename" );

Return the count of lines staged for the given filename.

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
