package ProtocolAnalyser;
use strict;

our %patterns = (
		"send" => "\^send> (.+) ::end\$", 
		"chat" => "\^chat> (.+?) to> (.+) ::end\$", 
		"log" => "\^log> (.+?), (.+?) ::end\$", 
		"list" => "\^list ::end\$", 
		"quit" => "\^quit ::end\$", 
		"help" => "\^help ::end\$"
);

our %descriptions = (
		"send" => "to send messages on the channel ", 
		"chat" => "to send a private message to someone ", 
		"log" => "to log in", 
		"list" => "to display the list of logged users ", 
		"quit" => "to quit ", 
		"help" => "to display the command list "
);

sub isValidMessage {

 my $message = shift;
 
 if($message=~/^(.+?) ::end$/s) {
 
  return 1;
 
 } else {
 
  return 0;
 
 }
 
}

sub parse {

 my $message = shift;
 
 my %action = ();
 
 if($message=~/$patterns{"send"}/s) {
 
  $action{"command"} = "SEND";
  $action{"message"} = $1;
 
 } elsif($message=~/$patterns{"chat"}/s) {
 
  $action{"command"} = "CHAT";
  $action{"message"} = $1;
  $action{"to"} = $2;
 
 } elsif($message=~/$patterns{"log"}/s) {
 
  $action{"command"} = "LOG";
  $action{"username"} = $1;
  $action{"password"} = $2;
 
 } elsif($message=~/$patterns{"list"}/s) {
 
  $action{"command"} = "LIST";
 
 } elsif($message=~/$patterns{"quit"}/s) {
 
  $action{"command"} = "QUIT";
 
 } elsif($message=~/$patterns{"help"}/s) {
 
  $action{"command"} = "HELP";
 
 } else {
 
  $action{"command"} = "A couple of nothing!";
 
 }
 
 return %action;
 
}

1;