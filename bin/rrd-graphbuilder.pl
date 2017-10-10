#! /usr/bin/env perl

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
use Data::Dumper;

my $graph_dir = shift || "/var/www/rrd";

my $time = time;

my @graph_default = (
    {
        span => '1h',
        nicename => "1 Hour",
	end => "now",
    },
    {
        span => '6h',
        nicename => "6 Hours",
	end => "now",
    },
    {
        span => '1d',
        nicename => "1 Day",
	end => "now",
    },
    {
        span => '7d',
        nicename => "1 Week",
	end => "now",
    },
    {
        span => '1m',
        nicename => "Month",
	end => "now",
    },
    {
        span => '3mon',
        nicename => "3 Months",
	end => "now",
    },
    {
        span => '6mon',
        nicename => "6 Months",
	end => "now",
    },
    {
        span => '1y',
        nicename => "1 Year",
	end => "now",
    },
    {
        span => '2y',
        nicename => "2 Year",
	end => "now",
    },
);

# Find all configurations
my $xs = XML::Simple->new();

my @configurations = glob( $graph_dir . "/conf/*.xml" );

#print Dumper(@configurations);

# Create the plot
foreach my $conf_file (@configurations) {

    print "\n$conf_file ";

    my $config = $xs->XMLin($conf_file, ForceArray => ['set']);

    #print Dumper($config);

    
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

	#print "rrd: " . Dumper($rrd) . "\n";
	#print "config: " . Dumper($graph_config) . "\n"; 

        #print Dumper($graph->{'config'});
        my @cfg   = eval($graph->{'config'}->{$graph_config}->{'content'});
        my $subfolder =  $rec->{'subfolder'} || "";
        
        print $@ if $@;
        
        push (@cfg, "--end"   => $end, "--start" => $start, 
						"--title" => $graph->{'title'} . " ($name)",
                        "--imgformat" => "PNG", "--interlaced");

        RRDs::graph( $graph_dir . "/" . $subfolder . "/" . $file, @cfg );
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


