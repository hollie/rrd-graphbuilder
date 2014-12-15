#! /usr/bin/env perl -w

# PODNAME: rrd-graphbuilder.pl

use strict;
use warnings;
use 5.012;

use File::Find;
use File::Path qw/mkpath/;
use POSIX qw/strftime/;
use File::Slurp;
use RRDs;
use XML::Simple;

my $data_dir  = shift || "/var/lib/rrd";
my $graph_dir = shift || "/var/www/rrd";

my $time = time;

my @graph_default = (
    {
        span => '1h',
        name => "1 Hour",
    },
    {
        span => '6h',
        name => "6 Hours",
    },
    {
        span => '1d',
        name => "1 Day",
    },
    {
        span => '7d',
        name => "1 Week",
    },
    {
        span => '1m',
        name => "Month",
    },
    {
        span => '3mon',
        name => "3 Months",
    },
    {
        span => '6mon',
        name => "6 Months",
    },
    {
        span => '1y',
        name => "1 Year",
    },
    {
        span => '2y',
        name => "2 Year",
    },
);

# Find all configurations
my $xs = XML::Simple->new();

my @configurations = glob( $graph_dir . "/conf/*.xml" );

# Create the plot
foreach my $conf_file (@configurations) {

    print "$conf_file\n";

    my $config = $xs->XMLin($conf_file, ForceArray => ['set']);
    
    my $graph = $config->{'graph'};
    
    # If there is a specific graph set time configuration in the xml, then use that set
    # otherwise use the default.
    my @graphset = defined($graph->{'graphset'}->{'set'}) ? @{$graph->{'graphset'}->{'set'}} : @graph_default;
     
    # Create the graphs for the defined time intervals
    foreach my $rec (@graphset) {
        my $span = $rec->{span};
        my $name = $rec->{nicename};
        my $end  = $rec->{end};
        my $graph_config = $rec->{'config'};
        
        my $file = $graph->{'filename'} . "-" . $span . "-" . $end . ".png";
        print $span, ",";
        my $start = 'end-' . $span;
        my $rrd = $graph->{rrd};
        my @cfg   = eval($graph->{'config'}->{$graph_config}->{'content'});
        push (@cfg, "--end"   => $end, "--start" => $start, 
						"--title" => $graph->{'title'} . " ($name)",
                        "--imgformat" => "PNG", "--interlaced");

        RRDs::graph( $graph_dir . "/" . $file, @cfg );
        my $err = RRDs::error;
        if ($err) {
            warn "ERROR creating $file: $err\n";
            next;
        }
    }

}


# Allow the tool to fetch a configuration string for the current graph if it exists
sub get_config_string {
	my $path  = shift();
	my $file  = shift();
	my $rrd   = shift();
	my $title = shift();
	my $var   = shift();
	my $start = shift();
	
	my @configstring;
	
	my $local_file  = $path . "/". $file .".conf";
	my $global_file = $path . "/graph.conf";
	 
	return eval(File::Slurp::read_file($local_file)) if (-e $local_file);
	return eval(File::Slurp::read_file($global_file)) if (-e $global_file);
	
	# Default return
	return ("--start" => $start, "--end"   => "now",
						"--title" => "$title",
                        "--imgformat" => "PNG", "--interlaced", 
                        "DEF:avg=$rrd:$var:AVERAGE", "DEF:min=$rrd:$var:MIN",
                        "DEF:max=$rrd:$var:MAX",
                        "LINE1:min#0EEFD2:C Min",
                        "LINE1:avg#EFD80E:C Avg",
                        "LINE1:max#EF500E:C Max",
                        "GPRINT:min:MIN:Min %7.2lf",
                        "VDEF:gavg=avg,AVERAGE", "GPRINT:gavg:Avg %7.2lf",
                        "GPRINT:max:MAX:Max %7.2lf\\l",
                        "COMMENT:".strftime('%Y-%m-%d %H\:%m\r',
                                            localtime(time)),
                        );
	
}


