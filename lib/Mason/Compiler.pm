# Copyright (c) 1998-2005 by Jonathan Swartz. All rights reserved.
# This program is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.

package Mason::Parser;
use Moose;
use Data::Dumper;
use Mason::Compilation;
use Mason::Util qw(checksum);
use strict;
use warnings;

has 'allow_globals' => ( is => 'ro', default => sub { [] } );
has 'block_types' => ( is => 'ro', lazy_build => 1, init_arg => undef );
has 'block_regex' => ( is => 'ro', lazy_build => 1, init_arg => undef );
has 'compilation_class'    => ( is => 'ro', default => 'Mason::Compilation' );
has 'default_base_class'   => ( is => 'ro', default => 'Mason::Component' );
has 'default_escape_flags' => ( is => 'ro', default => sub { [] } );
has 'no_source_line_numbers' => ( is => 'ro' );
has 'parser_id' => ( is => 'ro', lazy_build => 1, init_arg => undef );

# Default list of blocks - may be augmented in subclass
#
sub _build_block_types {
    return qw(class doc init perl text);
}

sub _build_block_regex {
    my $self = shift;
    my $re = join '|', $self->block_types;
    return qr/$re/i;
}

sub _build_parser_id {
    my $self = shift;

    # TODO - collect all attributes automatically
    my @vals = ( 'Mason::VERSION', $Mason::VERSION );
    my @attrs = qw(default_escape_flags use_source_line_numbers);
    foreach my $k (@attrs) {
        push @vals, $k, $self->{$k};
    }
    my $dumped_vals = Data::Dumper->new( \@vals )->Indent(0)->Dump;
    return checksum($dumped_vals);
}

# Like [a-zA-Z_] but respects locales
sub escape_flag_regex { qr/[[:alpha:]_]\w*/ }

sub compile {
    my ( $self, $source_file, $path ) = @_;

    my $compilation = $self->compilation_class->new(
        source_file => $source_file,
        path => $path,
        parser      => $self,
    );
    return $compilation->compile();
}

sub compile_to_file {
    my ( $self, $source_file, $path, $dest_file ) = @_;

    # We attempt to handle several cases in which a file already exists
    # and we wish to create a directory, or vice versa.  However, not
    # every case is handled; to be complete, mkpath would have to unlink
    # any existing file in its way.
    #
    if ( defined $dest_file && !-f $dest_file ) {
        my ($dirname) = dirname($dest_file);
        if ( !-d $dirname ) {
            unlink($dirname) if ( -e _ );
            mkpath( $dirname, 0, 0775 );
        }
        rmtree($dest_file) if ( -d $dest_file );
    }
    write_file( $dest_file, $self->compile( $source_file, $path ) );
}

1;