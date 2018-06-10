# User.pm
package User;
use strict;
use ProtocolAnalyser;
use Socket; 

use constant CONNECTED => 0;
use constant LOGGED => 1;
use constant CLOSED => 2;

# Methods
#	new
#	getHash
#	process
#	close
#	quit
#	display
#	logAs
#	displayUsers
#	displayCommands



sub new {

 my $class = shift;
 
 my $self = {
		"server" => shift, 
		"state" => CONNECTED, 
		"username" => "Guest".int(rand(1185)), 
		"socket" => shift, 
		"port" => shift, 
		"address" => inet_ntoa(shift), 
		"time" => time
 };
 
 return bless($self, $class);
 
}

sub getHash {
 
 return fileno(shift->{"socket"});

}

sub process {

 my $self = shift;
 
 my $data = "";
 
 recv($self->{"socket"}, $data, 1024, 0);
 
 if(length($data) == 0) {
 
  $self->quit();
  
 } else {
 
  $self->{"buffer"} .= $data;
  
  if(ProtocolAnalyser::isValidMessage(Utils::trim($self->{"buffer"}))) {
  
   $self->{"server"}->process($self);

   $self->{"buffer"} = "";
   
  }
  
 }
 
}

sub close() {

 my $self = shift;
 
 $self->display("You are out! Bye, bye! ");

 $self->{"state"} = CLOSED;

 close($self->{"socket"});

}

sub quit {

 #Server::report("user is quitting"); 

 my $self = shift;
 
 $self->close();
 
 $self->{"server"}->removeUser($self);

}

sub display {

 my $self = shift;
 
 send($self->{"socket"}, "\r\n".shift."\r\n", 0) || $self->quit();

}

sub logAs {

 my $self = shift;

 $self->{"state"} = LOGGED;
 $self->{"username"} = shift;
 
 $self->display("You are now logged in!");

}

sub displayUsers {

 my $self = shift;
 
 my @users = $self->{"server"}->getUsers();
 
 my $message = "Users list: ";
 $message .= "\r\n";
 
 for(my $i = 0; $i <= $#users; $i++) {
 
  $message .= "\t".$users[$i];
  $message .= "\r\n"; 

 }
 
 $self->display($message);
 
}

sub displayCommands {

 my $self = shift;
 
 my @commands = $self->{"server"}->getCommands();
 
 my $message = "Command list: ";
 $message .= "\r\n";
 
 for(my $i = 0; $i <= $#commands; $i++) {
 
  $message .= "\t".$commands[$i]->{"command"}." ".$commands[$i]->{"description"};
  $message .= "\r\n"; 
  
 }
 
 $self->display($message);

}

1;
