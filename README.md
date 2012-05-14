# NAME

File::Set::Writer - Buffered writes with a file handle pool

# DESCRIPTION

File::Set::Writer gives you the ability to write to many different 
file handles without worrying about breaking file handle limits.  
Additionally it can buffer writes so that a file is only written when
you have submitted N lines to write to the given file.  You can
place limits on the number of file handles, number of lines per
file, and number of files that can be buffered at once.  

The real-world use-case for this module is a situation where you have
one large file that must be split into thousands or hundreds of thousands
of files based on arbitrary conditions and want to avoid an Out Of Memory!
error while reducing the number of `open`, `close` and `write` syscalls 
being made.

Write ALL the files.

# SYNOPSIS

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

# CONSTRUCTOR

The constructor accepts the following parameters, and
each of the following may be called as a method on the
object after instantiation:

- max\_handles (Required)

    $writer->max_handles( 512 );

How many files may be open at one time.  You MUST set this.

If you do not know how many open handles you might want you
should check `ulimit -n` on your system and cut this number
in half.

When this number is meet or exceeded, the amount of file
handles given by expire\_handles\_batch\_size will be closed
and deleted from the cache in order of the oldest-accessed
file handles.

- max\_lines

    $writer->max_lines( 500 );

How many lines may be queued per-file before the lines
are written to disk.  This defaults to 500.

- max\_files

    $writer->max_files( 100 )

How many files may be written to before some files are
automatically written to disk.  

When this number is meet or exceeded the amount of files
given by expire\_files\_batch\_size will be written to disk
in order of which have the highest count of lines currently
buffered.

This defaults to 100.

- expire\_handles\_batch\_size

    $writer->expire_handles_batch_size( int($writer->max_handles * .2) );

The count of file handles to purge from the cache when 
max\_handles has been reached or exceeded.

This defaults to 20% of max\_handles.  If you manually
set it at any point the default will not be used.

- expire\_files\_batch\_size

    $writer->expire_files_batch_size( int($writer->max_files * .2) );

The count of files to be written to disk when max\_files
has been reached or exceeded.

This defaults to 20% of max\_files.  If you manually
set it at any point the default will not be used.

- line\_join

When writing to the disk, join the lines with the character
given here.

By default a UNIX newline is used.  Set to "" to disable new-lines 
in the join (but you should totally have a seperation of display logic 
and business logic!)

# METHODS

## print

    $writer->print( "filename", @lines )

This is the only method that you would normally want to use.

Write lines to the given filename.  This will stage the data 
for the file in memory.  

Data will be written to disk in the following situations:

- max\_lines has been met for a given file.  The file will be written.
- max\_files has been met.  The most-used files will be written.
- $writer goes out of scope.  Everything will be written.

# AUTHOR

SymKat _<symkat@symkat.com>_ ( Blog: [http://symkat.com/](http://symkat.com/) )

## CONTRIBUTORS

- Matt S. Trout (mst) _<mst@shadowcat.co.uk>_

# COPYRIGHT

Copyright (c) 2012 the File::Set::Writer ["AUTHOR"](#AUTHOR) and 
["CONTRIBUTORS"](#CONTRIBUTORS) as listed above.

# LICENSE 

This library is free software and may be distributed under the 
same terms as perl itself.

## AVAILABILITY

The most current version of File::Set::Writer can be found 
at [https://github.com/symkat/File-Set-Writer](https://github.com/symkat/File-Set-Writer)
