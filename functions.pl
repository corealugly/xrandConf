
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
                    push @cmd,getPortResolution($defaultDisplay);
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

#my $cmd = xrandrMirror('eDP-1', true);
#system(join(" ",@$cmd));

#($triger) open --> TRUE    close --> FALSE
sub lockLid($) {
    my($triger) = @_;
    if ($triger) {
        system("xrandr", "--output", "eDP1", "--auto");
    } else { 
        system("xrandr", "--output", "eDP1", "--off");
    }
}

sub statusLid() {
    my $libStatusFile="/proc/acpi/button/lid/LID/state";
    open(my $fd, '<:encoding(UTF-8)', $libStatusFile) or die "Could not open file '$libStatusFile' $!";
    while (my $row = <$fd>) {
        chomp $row;
        if ($row =~ /open/) { return true;
        } else { return false; }
    }
}

#my $status = statusLid();
#$log->info("statusLid --> $status");

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

#EXAMPLE
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

#createEventHandler ($scriptARGS)  --> no file validation exist --> control RUN EVENT
sub createEventHandler(;$) {
    my($scriptARGS) = @_;
    my $fileName = "thinkpad-lidbutton";
    my $filePath = "/etc/acpi/events/";
    if ( -d $filePath) {
        open(my $fd, ">$filePath$fileName") or die "Could not open file $fileName $!";
        print $fd "#vim $filePath$fileName" . "\n";
        print $fd "event=button[ /]lid" . "\n";
        if (defined $scriptARGS) {
            print $fd "action=" . abs_path($0) . " $scriptARGS " ."\n";
            #print $fd "action=$scriptARGS" . "\n";
        } else { 
            print $fd "action=" . abs_path($0) . "\n";
        }
    }
}

#createUdevHandler  ($scriptARGS)  --> no file validation exist --> control RUN EVENT
sub createUdevHandler(;$) {
    my($scriptARGS) = @_;
    my $fileName = "99-change-monitor.rules";
    my $filePath = "/etc/udev/rules.d";
    my @row;
    if ( -d $filePath) {
        open(my $fd, ">$filePath/$fileName") or die "Could not open file $fileName $!";
        push @row, "ACTION==\"change\"";
        push @row, "SUBSYSTEM==\"drm\"";
        push @row, "ENV{DISPLAY}=\":0\"";
        push @row, "ENV{XAUTHORITY}=\"/home/corealugly/.Xauthority\"";
        push @row, "RUN+=\"/home/corealugly/dotfiles/scripts/mirror.pl\"";
        print $fd join(", ", @row);
        if (defined $scriptARGS) {
            print $fd "$scriptARGS" . "\n";
        } else { 
            print $fd "action=" . abs_path($0) . "\n";
        }
    }
}

sub getPixelCount($) {
    my($resolution) = @_;
    return 0 if ( ! defined $resolution );
    my @splResolution = split("x",$resolution);
    return $splResolution[0] + $splResolution[0];
    }


sub getPortResolution($;$) {
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


true;