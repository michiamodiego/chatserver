#!/usr/bin/perl
# main.pl
use strict; 
use Server;

my $server = new Server("192.168.1.200", "3344");

#sub close {

# $server->stop();
 
# die(0);

#}

#$SIG{'INT'} = \&close;

$server->start();


