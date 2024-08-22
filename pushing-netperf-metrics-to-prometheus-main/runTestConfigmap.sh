#!/usr/bin/perl -w

###################################################
### This script runs several kubectl commands   ###
### in order to measure the network performance ###
### between K8s nodes, pods and services       ###
### in various scenarios.                       ###
###                                             ###
### Requires JSON::Parse, so install it by:     ###
### sudo perl -MCPAN -e 'install JSON::Parse'   ###
###                                             ###
### Written by Megyo on 15. May 2018            ###
### Modified by Jose Santos 14 Oct 2021         ###
###################################################

use strict;
use JSON::Parse ':all';
use warnings;

my $filename = 'netperfMetrics.txt';

open(my $fh, '>', $filename) or die "Could not open file '$filename' $!";

# Maximum number of measurements in different types
my $numberOfLocalhostMeasurements = 20;
# my $numberOfInterNodeMeasurements = 20;
my $iperfTime = 2;

my $netperfRequestPacketSize = 32;
my $netperfResponsePacketSize = 1024;

# Hash to store every data on Nodes
my %nodes = ();

# Hash to store every data on NetPerf Pods
my %pods = ();

# Hash to store every data on Netperf Service
my %services = ();

# Simple IP address regular expression
my $IPregexp = '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}';

# Reading ARGV for --nobaseline flag
my $nobaseline = 0;
if ((defined($ARGV[0])) and ($ARGV[0] =~ /--nobaseline/)) {
    $nobaseline = 1;
}
print STDERR "No Baseline flag is: $nobaseline\n";

# Reading Node, POD, and Service information from Kubernetes
&getKubernetesInfo();

# Run Iperf between PODs located on the same host
my %randHash = randomPodPairsOnSameNode($numberOfLocalhostMeasurements);

# If only have one node, then exit
exit if (scalar(keys %nodes) < 2);

foreach my $n1 (keys %nodes) {
    foreach my $n2 (keys %nodes) {
        last if ($nobaseline);
        if ($n1 ne $n2) {
            my $podName = $nodes{$n1}->{'HostNetPerf'};
            my $targetIP = $nodes{$n2}->{'IPaddress'};

            my $netperfRR = &runNetperf($podName, $targetIP, $iperfTime, 'TCP_RR', 'P50_LATENCY,P90_LATENCY,P99_LATENCY,THROUGHPUT,THROUGHPUT_UNITS');
            print "InterNode NetPerf TCP_RR test between Node $n1 and Node $n2 (latency 50,90 and 99 percentiles in us and DB like transaction rate): $netperfRR\n";

            my ($sc1, $sc2, $sc3, $sc4) = split(',', $netperfRR, 4);

            print $fh "netperf_p90_latency_microseconds.origin.$n1.destination.$n2=$sc2\n";
        }
    }
}

close $fh;

sub runIperf {
    my ($pod, $serverIP, $time) = @_;
    print STDERR "running command: kubectl exec -it $pod -- iperf -c $serverIP -i 1 -t $time \n";
    open(IPERF, "kubectl exec -it $pod -- iperf -c $serverIP -i 1 -t $time | ");
    my $lastLine = '';
    while (<IPERF>) {
        print STDERR $_;
        $lastLine = $_;
    }
    close(IPERF);
    chomp($lastLine);
    $lastLine =~ s/.*?(\d+\.\d+ .bits\/sec).*/$1/;
    return $lastLine;
}

sub runNetperf {
    my ($pod, $serverIP, $time, $type, $format) = @_;
    my $lastLine = '';
    print STDERR "running command: kubectl exec -it $pod -- netperf -H $serverIP -l $time -P 1 -t $type -- -r $netperfRequestPacketSize,$netperfResponsePacketSize -o $format \n";
    open(NETPERF, "kubectl exec -it $pod -- netperf -H $serverIP -l $time -P 1 -t $type -- -r $netperfRequestPacketSize,$netperfResponsePacketSize -o $format | ");
    while (<NETPERF>) {
        print STDERR $_;
        $lastLine = $_;
    }
    chomp($lastLine);
    close(NETPERF);
    return $lastLine;
}

sub runFortio {
    my ($pod, $serverIP, $time, $flags) = @_;
    my $lastLine = '';
    my $outputstring = '';
    my $port = '';
    $port = ':8080' unless ($flags =~ /grpc/);
    print STDERR "running command: kubectl exec -it $pod -- fortio load $flags -t ${time}s $serverIP$port \n";
    open(FORTIO, "kubectl exec -it $pod -- fortio load $flags -t ${time}s $serverIP$port | ");
    while (my $line = <FORTIO>) {
        print STDERR $line;
        $line =~ s/\n|\r//g;
        $line =~ s/[^0-9a-zA-z %.,]//g;
        $line =~ s/\t/ /g;
        if ($line =~ /target 50% (.*)/) {
            $outputstring .= $1 . ', ';
        }
        elsif ($line =~ /target 90% (.*)/) {
            $outputstring .= $1 . ', ';
        }
        elsif ($line =~ /target 99% (.*)/) {
            $outputstring .= $1 . ', ';
        }
        $lastLine = $line;
    }
    $lastLine =~ s/^.*,//;
    $outputstring .= $lastLine;
    close(FORTIO);
    return $outputstring;
}

sub randomKeysFromHash {
    my $number = shift;
    my %hash = @_;
    my @randomList = ();

    while (($number > 0) and (scalar(keys %hash) > 0)) {
        my $randKey = (keys %hash)[rand keys %hash];
        push @randomList, $randKey;
        delete $hash{$randKey};
        $number--;
    }

    return @randomList;
}

sub randomPodPairsOnSameNode {
    my $number = shift;
    my %hash = ();

    foreach my $node (keys %nodes) {
        my @tmp = @{$nodes{$node}->{'pods'}};
        while (($number > 0) and (scalar(@tmp) > 1)) {
            $hash{$tmp[0]} = $tmp[1];
            shift @tmp;
            $number--;
        }
    }

    return %hash;
}

sub randomNodePairs {
    my $number = shift;
    my %hash = ();

    my @tmp = keys %nodes;

    return %hash if (scalar(@tmp) < 2);

    if (scalar(@tmp) == 2) {
        $hash{$tmp[0]} = $tmp[1];
        $hash{$tmp[1]} = $tmp[0];
        return %hash;
    }

    if (scalar(@tmp) == 3) {
        $hash{$tmp[0]} = $tmp[1];
        $hash{$tmp[1]} = $tmp[0];
        $hash{$tmp[1]} = $tmp[2];
        $hash{$tmp[0]} = $tmp[2];
        return %hash;
    }

    if (scalar(@tmp) == 4) {
        $hash{$tmp[0]} = $tmp[1];
        $hash{$tmp[0]} = $tmp[2];
        $hash{$tmp[0]} = $tmp[3];
        $hash{$tmp[1]} = $tmp[2];
        $hash{$tmp[2]} = $tmp[3];
        return %hash;
    }

    while (($number > 0) and (scalar(@tmp) > 1)) {
        $hash{$tmp[0]} = $tmp[1];
        shift @tmp;
        $number--;
    }

    return %hash;
}

sub randomPodsOnDifferentNodes {
    my %nodePairs = @_;
    my %hash = ();

    foreach my $nodeA (keys %nodePairs) {
        my @tmpA = @{$nodes{$nodeA}->{'pods'}};
        my @tmpB = @{$nodes{$nodePairs{$nodeA}}->{'pods'}};

        my $podA = $tmpA[rand @tmpA];
        my $podB = $tmpB[rand @tmpB];
        $hash{$podA} = $podB;
    }

    return %hash;
}

sub getKubernetesInfo {
    # Get name of all nodes in the cluster
    my $allNodes = `kubectl get nodes -o name`;
    foreach (split("\n", $allNodes)) {
        # This will be the temporary variable to store all relevant Node data
        my %tmp = ();

        # Add array for future POD information
        my @podsOnThisNode = ();
        $tmp{'pods'} = \@podsOnThisNode;

        $_ =~ s/node\///;
        print STDERR "Node: $_\n";

        # Get all the information on this particular Node
        my $res = `kubectl describe node $_`;
        foreach my $line (split("\n", $res)) {
            # Get IP address of the Node
            if ($line =~ /InternalIP:.*?($IPregexp)/) {
                $tmp{'IPaddress'} = $1;
            }

            # Get PodCIDR of the Node
            if ($line =~ /PodCIDR:.*?($IPregexp\/\d+)/) {
                $tmp{'PodCIDR'} = $1;
            }
        }
        $nodes{$_} = \%tmp;
    }

    # Get name of all pods in the cluster
    my $allPods = `kubectl get pods -o=custom-columns=NAME:.metadata.name,NAMESPACE:.metadata.namespace | grep netperf`;
    foreach (split("\n", $allPods)) {
        # This will be the temporary variable to store all relevant POD data
        my %tmp = ();

        my ($name, $namespace) = split(/ +/, $_);
        print STDERR "Pod: $name  in  $namespace \n";
        $tmp{'namespace'} = $namespace;

        # Get all the information on this particular Pod
        my $res = `kubectl describe pod $name --namespace=$namespace`;
        foreach my $line (split("\n", $res)) {
            # Get IP address of the POD
            if ($line =~ /IP:.*?($IPregexp)/) {
                $tmp{'IPaddress'} = $1;
            }

            # Get the Node that the POD is running on
            if ($line =~ /Node: +(.*?)\/($IPregexp)/) {
                $tmp{'NodeName'} = $1;
                $tmp{'NodeIP'} = $2;
            }
        }
        # If this POD runs in host mode, we add it to the node
        if ($tmp{'IPaddress'} eq $tmp{'NodeIP'}) {
            $nodes{$tmp{'NodeName'}}->{'HostNetPerf'} = $name;
        }
        # Adding the same POD to the Node's list and to the POD list
        else {
            push @{$nodes{$tmp{'NodeName'}}->{'pods'}}, $name;
            $pods{$name} = \%tmp;
        }
    }

    # Get all info on NetPerf service
    my $allServices = `kubectl get services --all-namespaces -o wide | grep netperf`;
    foreach (split("\n", $allServices)) {
        next if ($_ =~ /NAMESPACE/); # Just skip the first header line

        # This will be the temporary variable to store all relevant POD data
        my %tmp = ();

        my @podBackends = ();

        my ($namespace, $name, $type, $clusterIP, $externalIP, $port, $age, $selector) = split(/ +/, $_);
        print STDERR "Service: $name  in  $namespace IP=$clusterIP $externalIP $selector \n";
        $tmp{'namespace'} = $namespace;
        $tmp{'type'} = $type;
        $tmp{'clusterIP'} = $clusterIP;
        $tmp{'externalIP'} = $externalIP;
        $tmp{'selector'} = $selector;

        # Get all the POD backends for this service
        my $res = `kubectl get pods -l $selector --all-namespaces -o name`;
        foreach my $line (split("\n", $res)) {
            $line =~ s/pods\///;
            push @podBackends, $line;
        }
        $tmp{'podBackends'} = \@podBackends;

        $services{$name} = \%tmp;
    }

    # In order to get all the ports for the services we do a query in JSON
    my $json = `kubectl get services --all-namespaces -o json`;
    my $hash = parse_json($json);

    foreach my $svc (@{$hash->{'items'}}) {
        next unless (defined($services{$svc->{'metadata'}->{'name'}}));
        $services{$svc->{'metadata'}->{'name'}}->{'ports'} = $svc->{'spec'}->{'ports'};
    }

    print STDERR join(' ', %nodes), "\n";
    print STDERR join(' ', %pods), "\n";
    print STDERR join(' ', %services), "\n";
}
