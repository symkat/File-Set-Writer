#!/usr/bin/perl
use warnings;
use strict;
use File::Set::Writer;
use Test::More;

my $writer = File::Set::Writer->new(
    max_handles => 100,
);


# Standard Defaults have been set.
is( $writer->max_handles, 100, "Max handles set" );
is( $writer->max_files, 100, "Max files set." );
is( $writer->max_lines, 500, "Max lines set." );
is( $writer->expire_handles_batch_size, 20, "Expire Handles set" );
is( $writer->expire_files_batch_size, 20, "Expire Files set" );
is( $writer->line_join, "\n", "Line Join set." );

# Update our limits.
ok( $writer->max_handles( 500 ), "Can Set Max Handles" );
ok( $writer->max_files( 1000 ), "Can Set Max Files" );
ok( $writer->max_lines( 1000 ), "Can Set Max Lines" );

# Ensure everything was properly set.
is( $writer->max_handles, 500, "Max Handles reset" );
is( $writer->max_files, 1000, "Max files reset." );
is( $writer->max_lines, 1000, "Max lines reset." );
is( $writer->expire_handles_batch_size, 100, "Expire Handles reset" );
is( $writer->expire_files_batch_size, 200, "Expire Files reset" );

# Make sure once we hard-set the expires, they stay as the user
# wanted them.
ok( $writer->expire_handles_batch_size( 500 ), "Can set expire handles" );
ok( $writer->expire_files_batch_size( 500 ), "Can set expire handles" );
ok( $writer->max_handles( 100 ), "Can Set Max Handles" );
ok( $writer->max_files( 100 ), "Can Set Max Files" );
ok( $writer->max_lines( 100 ), "Can Set Max Lines" );

is( $writer->max_handles, 100, "Max handles new setting." );
is( $writer->max_files, 100, "Max files new setting." );
is( $writer->max_lines, 100, "Max lines new setting." );
is( $writer->expire_handles_batch_size, 500, "Expire handle respects user" );
is( $writer->expire_files_batch_size, 500, "Expire files respects user" );


done_testing();
