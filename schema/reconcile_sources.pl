#!/usr/bin/env perl
use warnings;
use strict;

=pod

A quick and dirty script for the purpose of reconciling the files to
run in the create scripts with the actual source files in the schema
sub-directories.

The idea is to ensure that any files listed in the create scripts that
do not exist in the schema source files are commented out while any new
source files are added.

=cut


my @create_files = `ls *create*.sql` ;
chomp @create_files;
my %create_schema_files;

foreach my $file (@create_files) {
    my (undef, $schema) = split /[-\.]/, $file;
    next if ($schema eq 'sql');
    $create_schema_files{$schema} = $file;
}

my @schemas = get_schemas();

foreach my $schema ( @schemas ) {
    reconcile_schema( $schema );
}

sub get_schemas {

    my $source_dir = './';
    opendir(my $dh, $source_dir) || warn "Can't open $source_dir: $!\n";
    return unless ( $dh ) ;

    my @listing = readdir($dh);
    closedir $dh;

    my @source_files = grep { /^[^\.]/ && -d "$source_dir/$_" } @listing;
    return @source_files;
}

sub get_source_list {
    my ( $schema ) = @_;
    my @source_files;

    foreach my $type (qw(foreign_table function materialized_view procedure sequence table type view)){

        my $source_dir = "$schema/$type" ;

        next unless ( -d $source_dir ) ;

        opendir(my $dh, $source_dir) || warn "Can't opendir $source_dir: $!\n";
        next unless ( $dh ) ;

        my @files = map { "$schema/$type/$_" } grep { /\.sql$/ && -f "$source_dir/$_" } readdir($dh);
        closedir $dh;

        foreach my $file (@files) {
            push @source_files, $file;
        }
    }

    return @source_files ;
}

sub reconcile_schema {
    my ( $schema ) = @_;

    my $fh;
    my @new_lines;
    my @orig_lines;
    my @source_files = get_source_list ($schema);
    my %avail = map { $_ => 'notseen' } @source_files;

    my $create_file = $create_schema_files{$schema} ;
    $create_file ||= "xx_create-${schema}.sql";

    if ( -f $create_file ) {
        if (open( $fh, '<:raw', $create_file )) {
            if ($fh) {
                @orig_lines = (<$fh>);
                close $fh;
                chomp @orig_lines;
            }
        } else {
            warn "Could not open $create_file.\n";
        }
    }

    foreach my $new_line (@orig_lines) {
        my $chk = $new_line;
        $chk =~ s/^[ \t]+//;

        # check included files
        if ( $chk =~ m/^\\i/ ) {
            my @ary = split /[ \t]+/, $chk;

            if ( exists $avail{ $ary[1] } ) {
                $avail{ $ary[1] } = 'seen 1';
                shift @ary;
                $new_line = '\i ' . join( '', @ary );
            }
            else {
                $new_line = '--' . $new_line;
            }
        }

        # check comments for included files. assert that if they are
        # commented out then there is a reason for having done so
        elsif ( $chk =~ m/^\-\-\\i/ ) {
            my @ary = split /[ \t]+/, $chk;
            if ( exists $avail{ $ary[1] } ) {
                $avail{ $ary[1] } = 'seen 2';
            }
        }

        push @new_lines, $new_line;
    }

    my @missing;
    foreach my $file ( sort keys %avail ) {
        if ( $avail{$file} eq 'notseen' ) {
            push @missing, '\i ' . $file;
        }
    }

    if (@missing) {
        push @new_lines, "\n-- NEW -------------------------------";
        push @new_lines, $_ for @missing;
        push @new_lines, '';
    }

    if ( join( "\n", @orig_lines ) ne join( "\n", @new_lines ) ) {
        open( $fh, '>:raw', $create_file )
          || die "Could not open $create_file. $!\n";
        print $fh join( "\n", @new_lines );
        close $fh;
    }
}
