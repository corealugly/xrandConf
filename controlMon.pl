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

#home
#xrandr --output eDP-1 --off --output DP-3-1 --auto --pos 2560x0 --output DP-3-2  --primary --auto --pos 0x0
#work
#xrandr --output eDP-1 --primary --mode 1920x1080 --pos 0x0 --rotate normal --output HDMI-3 --off --output HDMI-2 --off --output HDMI-1 --mode 1920x1080 --pos 1920x0 --rotate normal --output DP-3 --off --output DP-2 --off --output DP-1 --off

my $cmd = xrandrMirror('eDP-1', true);
# system(join(" ",@$cmd));
$log->info(join(" ",@$cmd));
