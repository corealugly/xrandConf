use Log::Any qw($log);
use Log::Any::Adapter ('Stdout');
use Digest::MD5 qw(md5_hex);

sub sendStatus($;$) {
    my($user, $message) = @_;
    if (defined $message) { system("sudo -u $user/usr/bin/notify-send -t 5000 " . "\"" . $message . "\"" ); }
    else { system("sudo -u $user /usr/bin/notify-send -t 5000 " . "\"Status message!\"" ); }
}

#todo сделать обработку массива запущенных xsession
sub getUserDisplayList() {
    # my $cmd = 'w -h | awk \'{if (NF>8) {print $1 " " $11}}\' | head -n 1';
    my $cmd = 'ps -eo uname:15,cmd | awk -n  \'{ if ($2 ~ "xinit") { print $1}}\' | head -n 1';
    my $userDistplayList = `$cmd`;
    chomp $userDistplayList;
    return $userDistplayList;
}

#EXAMPLE
# sendStatus(getUserDisplayList());

sub convPortName($) {
    my($portName) = @_;
    if ($portName =~ /(DP)-(\d{1})-(\d{1})/) {
        # print $1 . "-" . ($2 + $3) . "\n";
        # print "convert1 --> " . $portName . "--> " . $1 . "-" . ($2 + $3) . "\n";
        return $1 . "-" . ($2 + $3);
    }
    if ($portName =~ /(HDMI)-(\d{1})-(\d{1})/) {
        # print $1 . "-" . ($2 + $3) . "\n";
        # print "convert2 --> " . $portName . "--> " . $1 . "-" . ($2 + $3) . "\n";
        return $1 . "-" . ($2 + $3);
    }
    if ($portName =~ /card0-(DP)-(\d{1})/) {
        # print $1 . "-" . ($2 + $3) . "\n";
        # print "convert3 --> " . $portName . "--> " . $1 . "-" . $2 . "\n";
        return $1 . "-" . $2;
    }
    if ($portName =~ /card0-(HDMI)-(\S{1})-(\d{1})/) {
        # print $1 . "-" . $3 . "\n";
        # print "convert4 --> " . "$portName" . "--> " . $1 . "-" . $3 . "\n";
        return $1 . "-" . $3;
    }
    if ($portName =~ /card0-(\S*)-(\d{1})/) {
        # print $1 . "-" . ($2 + $3) . "\n";
        # print "convert5 --> " . $portName . "--> " . $1 . "-" . $2 . "\n";
        return $1 . "-" . $2;
    }
    # print "without convert!!! --> ". $portName . "\n";
    return $portName;
}

sub getEdidStruct() {
    my @edidList = `find /sys/devices/ -iname "edid"`;
    # my @edidList = `ls /sys/class/drm/`;
    my(%devicePath);
    
    foreach $edidPath (@edidList) {
        chomp $edidPath;
        if (! -e $edidPath ) { $log->error("ERROR: edid not exists --> " .  $edidPath); }
        my @separatePath = split(/\//, $edidPath);
        my $newname = convPortName($separatePath[-2]);
        $devicePath{$newname} = $edidPath;
    }
    return \%devicePath;
}

sub getXrandrStructV2() {
    my @output = `xrandr`;
    my(%videoPorts);
    my $devicePath = getEdidStruct();
    for (my $i = 0; $i < $#output; $i++) {
        my(@resolutionCase);
        if ( $output[$i] =~ /(\S*)\s(connected).*/ ) {
            my $portName = $1;
            my %struct;
            for ($i++ ; $i < $#output; $i++) {      
                if ( $output[$i] =~ /connected/ ) { $i--; last; }
                my(%resolutionStruct);

                # check selected screen resolution status
                if ( $output[$i] =~ /\*/ ) {
                    $resolutionStruct{'status'} = true;
                } else { $resolutionStruct{'status'} = false; }

                # delete space start/end and symbol "+" "*"
                $output[$i] =~ s/^\s+|\s+$|\+|\*//g;

                my @hz = split(/ +/, $output[$i]);
                $resolutionStruct{'resolution'} = shift @hz;
                $resolutionStruct{'hz'} = \@hz;

                # $resolutionStruct{'edid'} = %$devicePath{convPortName($portName)};

                push @resolutionCase, \%resolutionStruct;
            }
            $struct{'rStruct'} = \@resolutionCase;

            # get monitor ID(edid) and get his hash
            $struct{'edid'} = %$devicePath{convPortName($portName)};
            $struct{'edid-md5'} = md5_hex($struct{'edid'});
            # print Dumper \%struct;
            $videoPorts{$1} =  \%struct;
        }
    }
    return \%videoPorts;
    # print Dumper \%videoPorts;
}

#`xrandr --output eDP1 --auto --output DP3-1 --mode 1920x1080 --same-as eDP1`
sub xrandrMirror($;$) {
    my($defaultDisplay, $sameResolution) = @_;
    my(@cmd);
    my $videoPorts = getXrandrStructV2();
    if ($videoPorts->{$defaultDisplay}) {  
        push @cmd, "xrandr";
        push @cmd, "--output";
        push @cmd, $defaultDisplay;

        # check open LID
        if ( statusLid() )
        { push @cmd, "--auto"; } 
        else
        { push @cmd, "--off"; }

        foreach my $key (keys %$videoPorts) {
            $log->info("$key:  $videoPorts->{$key}{'rStruct'}[0]{'resolution'}");
            if ($key ne $defaultDisplay) {
                push @cmd,"--output";
                push @cmd,"$key";
                push @cmd,"--mode";
                if ($sameResolution) {
                    push @cmd,getPortResolution($defaultDisplay);
                } else { 
                    push @cmd,"$videoPorts->{$key}{'rStruct'}[0]{'resolution'}";
                }
                push @cmd,"--same-as";
                push @cmd,"$defaultDisplay";
            } 
        }
    }
   return \@cmd;
}

#EXAMPLE
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

#EXAMPLE
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
            print $fd "action=" . abs_path($0) . " $scriptARGS " . "\n";
            #print $fd "action=$scriptARGS" . "\n";
        } else { 
            print $fd "action=" . abs_path($0) . "\n";
        }
    }
}

sub prompt ($) {
  my ($query) = @_; # take a prompt string as argument
  local $| = 1; # activate autoflush to immediately show the prompt
  print $query;
  chomp(my $answer = <STDIN>);
  return $answer;
}

sub prompt_yn ($) {
  my ($query) = @_;
  my $answer = prompt("$query (Y/N): ");
  return lc($answer) eq 'y';
}

#createUdevHandler  ($scriptARGS)  --> no file validation exist --> control RUN EVENT
sub createUdevHandler(;$) {
    my($scriptARGS) = @_;
    my $fileName = "99-change-monitor.rules";
    my $filePath = "/etc/udev/rules.d";
    my @row;
    push @row, "ACTION==\"change\"";
    push @row, "SUBSYSTEM==\"drm\"";
    push @row, "ENV{DISPLAY}=\":0\"";
    # push @row, "ENV{XAUTHORITY}=\"/home/corealugly/.Xauthority\"";
    # push @row, "RUN+=\"/home/corealugly/dotfiles/scripts/mirror.pl\"";
    if (defined $scriptARGS) { push @row, "RUN+=\"" . abs_path($0) . " " . $scriptARGS . "\""; "RUN+=\"\""; } 
    else { push @row, "RUN+=\"" . abs_path($0) . "\""; }
    if ( -d $filePath) {
        if ( -e "$filePath/$fileName" ) { 
            if ( prompt_yn("file $fileName is exist, rewrite?") ) { 
                open(my $fd, ">$filePath/$fileName") or die "Could not open file $fileName $!";
                print $fd join(", ", @row);
            }
        } else {
            open(my $fd, ">$filePath/$fileName") or die "Could not open file $fileName $!";
            print $fd join(", ", @row);
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
    my $videoPorts = getXrandrStructV2();
    # print Dumper $videoPorts->{$videoPort}->{'rStruct'};
    if ($videoPorts->{$videoPort}) {
        foreach my $key (@{$videoPorts->{$videoPort}->{'rStruct'}}) {
            if ( defined $resolution and $resolution eq $key->{"resolution"})
            { 
                return  $key->{"resolution"};
            }
            #if (! $max) { $max = $key->{$resolution}; }
            if (getPixelCount($key->{'resolution'}) > getPixelCount($max)) { 
                $max = $key->{"resolution"};
            }
            # $log->info($max);
        }
        return $max;
    } else {
        $log->error("video port not exist: $videoPort");
        return;
    }
}


true;