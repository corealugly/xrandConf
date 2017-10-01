#!/usr/bin/env perl 
use strict;
use warnings;
use utf8;
use Data::Dumper;
use boolean;
use Log::Any qw($log);
use Log::Any::Adapter ('Stdout');

# {{{ getXrandrStruct
sub getXrandrStruct() {
    my @output = `xrandr`;
    #my(%videoPort,@resolutionCase);
    my(%videoPort);
    for (my $i = 0; $i < $#output; $i++) {
        my(@resolutionCase);
        if ( $output[$i] =~ /(\S*)\s(connected)\s(\S*).*/ ) {
            for ($i++ ; $i < $#output; $i++) {
                my(%resolutionStruct);
                if ( $output[$i] =~ /connected/ ) { last; }
                $output[$i] =~ s/^\s+|\s+$//g;
                my @hz = split(/ +/, $output[$i]);
                $resolutionStruct{'resolution'} = shift @hz;
                $resolutionStruct{'hz'} = \@hz;
                if ( $output[$i] =~ /\*/ ) {
                    $resolutionStruct{'status'} = true;
                } else { $resolutionStruct{'status'} = false; }
                push @resolutionCase, \%resolutionStruct;
            }
            $videoPort{$1} =  \@resolutionCase;
        }
    }
    return \%videoPort;
}

#$VAR1 = {
#          'eDP1' => [
#                      {
#                        'hz' => [
#                                  '60.02*+',
#                                  '59.93'
#                                ],
#                        'resolution' => '1920x1080',
#                        'status' => bless( do{\(my $o = 1)}, 'boolean' )
#                      },
#                      {
#                        'status' => bless( do{\(my $o = 0)}, 'boolean' ),
#                        'resolution' => '1680x1050',
#                        'hz' => [
#                                  '59.95',
#                                  '59.88'
#                                ]
#                      },

# }}}

# {{{ getPixelCount 
sub getPixelCount($) {
    my($resolution) = @_;
    return 0 if ( ! defined $resolution );
    my @splResolution = split("x",$resolution);
    return $splResolution[0] + $splResolution[0];
    }
# }}}

# {{{ getPortResorution
sub getPortResorution($;$) {
    my($videoPort,$resolution) = @_;
    my $max = undef;
    my $videoPorts = getXrandrStruct();
    if ($videoPorts->{$videoPort}) {
        foreach my $key (@{$videoPorts->{$videoPort}}) {
            #if (! $max) { $max = $key->{$resolution}; }
            if (getPixelCount($key->{"resolution"}) > getPixelCount($max)) { 
                $max = $key->{"resolution"};
            }
            #$log->info($max);
            if ( defined $resolution and $resolution eq $key->{"resolution"}) { return  $key->{"resolution"}; }
        }
        return $max;
    } else {
        $log->error("video port not exist: $videoPort");
        return;
    }
}
# }}}

# {{{ xrandrMirror 
sub xrandrMirror($;$) {
    my($defaultDisplay, $sameResolution) = @_;
    my(@cmd);
    my $videoPorts = getXrandrStruct();
    if ($videoPorts->{$defaultDisplay}) {  
        push @cmd, "xrandr";
        push @cmd, "--output";
        push @cmd, $defaultDisplay;
        push @cmd, "--auto";
        foreach my $key (keys %$videoPorts) {
            $log->info("$key:  $videoPorts->{$key}[0]{'resolution'}");
            if ($key ne $defaultDisplay) {
                push @cmd,"--output";
                push @cmd,"$key";
                push @cmd,"--mode";
                if ($sameResolution) {
                    push @cmd,getPortResorution($defaultDisplay);
                } else { 
                    push @cmd,"$videoPorts->{$key}[0]{'resolution'}";
                }
                push @cmd,"--same-as";
                push @cmd,"$defaultDisplay";
            } #`xrandr --output eDP1 --auto --output DP3-1 --mode 1920x1080 --same-as eDP1`
        }
    }
   return \@cmd;
}
# }}}

sub locklid() {
    system("xrandr", "--output", "eDP1", "--off");
}

sub unlocklid() {
    system("xrandr", "--output", "eDP1", "--auto");
}

#xrandr --output eDP1 --auto --output DP3-1 --mode 1920x1080 --same-as eDP1
#xrandr --output eDP1 --auto --output DP3-1 --mode 1920x1080+0+0 --same-as eDP1
#xrandr --output eDP1 --auto --output DP2-8 --mode 1920x1080 --same-as eDP1
#xrandr --output eDP1 --auto --output DP2 --mode 1920x1080 --same-as eDP1

my $cmd = xrandrMirror('eDP1', true);
system(join(" ",@$cmd));
$log->info(join(" ",@$cmd));
