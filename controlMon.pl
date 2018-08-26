#!/usr/bin/env perl 
use strict;
use warnings;
use utf8;
use Data::Dumper;
use boolean;
use Cwd 'abs_path';
use File::Basename;
use Getopt::Long qw(GetOptions);
use Log::Any qw($log);
use Log::Any::Adapter ('Stdout');

# require  "./" . dirname(__FILE__) . "/functions.pm";
require  (dirname(__FILE__) . "/functions.pl");

sub HelpMessage() {
    print "Usage: $0 
          --lidstatus           status lid on/off
          --lidlock             enable/disable eDP-1
          --createEventHandler  create event handler for lid
          --createUdevHandler   create udev handler for new video devices
          --xrandrMirror        make all the displays as current
          --sameResolution      make the same screen resolution (xrandrMirror)
          --help,-h             Print this help
          ";
    exit 0;
}

GetOptions(
    'lidstatus' => \(my $lidstatus=0),
    'lidlock' => \(my $lidlock=0),
    'createEventHandler' => \(my $createEventHandler=0),
    'createUdevHandler' => \(my $createUdevHandler=0),
    'xrandrMirror=s' => \(my $xrandrMirror=undef),
    'sameResolution' => \(my $sameResolution=0),
    'help|?' => sub { HelpMessage(); },
# ) or HelpMessage();
) or die HelpMessage();

# HelpMessage() unless $table;
# HelpMessage() unless $column;

# {{{ INFO
#apt-get install acpid acpi-support cpufrequtils
#------------- acpi example
#corealugly@corebook $ acpi_listen
#button/lid LID open
#button/lid LID close

# }}}

# my $test = getUserDisplayList();
# print Dumper $test;
# exit 1;

if ( $lidstatus ) {
    my $status = statusLid();
    if ($status) {
        print "Open" . "\n";
    } else { print "Close" . "\n"; }
}

if ( $lidlock ) { 
    if ( statusLid() )   { lockLid(true);  } 
    else { lockLid(false); }
    # if ( ! statusLid() ) { lockLid(false); }
}

if ( $createEventHandler ) {
    createEventHandler();
}

if ( $createUdevHandler ) {
    createUdevHandler();
}

#system("xrandr", "--output", "HDMI1", "--off")

#xrandr --output eDP1 --auto --output DP3-1 --mode 1920x1080 --same-as eDP1
#xrandr --output eDP1 --auto --output DP3-1 --mode 1920x1080+0+0 --same-as eDP1
#xrandr --output eDP1 --auto --output DP2-8 --mode 1920x1080 --same-as eDP1
#xrandr --output eDP1 --auto --output DP2 --mode 1920x1080 --same-as eDP1
#NEW
#system("xrandr --output eDP-1 --off --output DP-3-1 --mode 1920x1080 --right-of DP-3-2 --mode 1920x1080");
#xrandr --output eDP-1 --off && xrandr --output DP-3-1 --mode 1920x1080 --right-of DP-3-2 --mode 1920x1080
#xrandr --output DP-3-2 --mode 1920x1080 --primary --left-of DP-3-1 --mode 1920x1080  --output eDP-1 --off
#xrandr --output eDP-1 --off --output HDMI-3 --off --output HDMI-2 --off --output HDMI-1 --off --output DP-3-1 --mode 1920x1080 --pos 1920x0 --rotate normal --output DP-3-3 --off --output DP-3-2 --mode 1920x1080 --pos 0x0 --rotate normal --output DP-3 --off --output DP-2 --off --output DP-1 --off
# getEdidStruct();
#getXrandrStructV2();

#exit 1 ;
my $runningXserverList = getUserDisplayList();
#print Dumper $runningXserverList;
sendStatus($runningXserverList);
exit 1;

my $cmd = xrandrMirror('eDP-1', true);
system(join(" ",@$cmd));
$log->info(join(" ",@$cmd));
