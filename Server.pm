# Server.pm
package Server;
use strict;
use Socket; 
use User;
use ProtocolAnalyser;
use Utils;

# Filehandles (aka GLOBs) cannot be passed between ithreads; 
# hence, any objects which contain GLOB's (e.g., IO::Socket) 
# also cannot readily be passed. The recommended method for 
# passing filehandles between threads is to pass the fileno()
# and reconstruct the filehandle in the receiving thread #
#(via either IO::Handle::fdopen() or open(FH, "&$fileno")).
# http://search.cpan.org/~darnold/Thread-Apartment-0.51/lib/Thread/Apartment.pod#Passing_filehandles
# and in case you are willing to create a threaded version I suggest you read this first
# http://www.perlmonks.org/?node_id=288022

# Methods
#	new - Returns a server instance
#	start - Calls listen
#	listen
#	getSockets
#	getReadySockets - Returns all the sockets which data is available for
#	getUserBySocket
#	removeUser
#	process
#	display
#	displayTo
#	getUserByUsername
#	isUser
#	getUsers
#	getCommands
#	stop



sub new {

 unlink "log.txt";
 
 my $class = shift; 
 
 # This is temp hash (Data have to be read from a database)
 my %accounts = ("user1" => "pwd1", "user2" => "pwd2"); 
 
 my $self = {
		"address" => shift, 
		"port" => shift, 
		"max" => shift || 30, 
		"users" => {}, 
		"accounts" => \%accounts 
 };
 
 return bless($self, $class);
 
}

sub start {
 
 shift->listen();
 
}

sub listen {
 
 my $self = shift;
 
 my $server;
 
 socket($server, AF_INET, SOCK_STREAM, getprotobyname("tcp")) || die "#socket: $!";
 setsockopt($server, SOL_SOCKET, SO_REUSEADDR, 1) || die "#setsockopt: $!";
 # INADDR_ANY, inet_aton($self->{"address"})
 bind($server, sockaddr_in($self->{"port"}, INADDR_ANY)) || die "#bind: $!";
 listen($server, $self->{"max"}) || die "#listen: $!";
 
 $self->{"socket"} = $server;
 
 undef $server;
 
 while(1) {
  
  my @sockets = $self->getSockets();
  my @t = $self->getReadySockets(@sockets);
  
  foreach my $socket (@t) {
  
   if($socket == $self->{"socket"}) {
   
    my $client;
	
	my $packedAddress = accept($client, $self->{"socket"});
	
	if(defined($client)) {
	
	 if($#sockets <= $self->{"max"}) {
	 
	  my $user = new User($self, $client, sockaddr_in($packedAddress));
	  
	  $self->{"users"}->{$user->getHash()} = $user;
	  
	  $user->display("Welcome!");
	  $user->displayCommands();
	 
	 } else {
	 
	  send($client, "Max number of users exceeded!", 0);
	  
	  close($client);
	 	 
	 }
	
	}
   
   } else {
   
    my $user = $self->getUserBySocket($socket);
	
	$user->process();
   
   }
   
  }
 
 }

 $self->stop();

}

sub getSockets {

 my $self = shift;
 
 my @sockets = ($self->{"socket"});
 
 foreach my $key (keys %{$self->{"users"}}) {
 
  $sockets[$#sockets+1] = $self->{"users"}->{$key}->{"socket"};
 
 }
 
 return @sockets; 
 
}

sub getReadySockets {

 my $self = shift;
 
 my @sockets = @_;
 
 my $bits = "";
 
 for my $t (@sockets) {
 
  vec($bits, fileno($t), 1) = 1;
  
 }
 
 my $any = select(my $r = $bits, undef, undef, undef); 
 
 my @t = ( );
 
 for(my $i = 0; $i <= $#sockets; $i++) {
 
  if(vec($bits, fileno($sockets[$i]), 1) & vec($r, fileno($sockets[$i]), 1)) {
  
   $t[$#t+1] = $sockets[$i];  
  
  }
 
 }
 
 return @t;
  
}

sub getUserBySocket {

 return shift->{"users"}->{fileno(shift)};

}

sub removeUser() {

 my $self = shift;
 my $user = shift;
 
 delete($self->{"users"}->{$user->getHash()});
 
}

sub process {

 my $self = shift;
 my $user = shift;
 
 my %action = ProtocolAnalyser::parse(Utils::trim($user->{"buffer"}));
 
 if($action{"command"} eq "SEND") {
 
  if($user->{"state"} == User::LOGGED) {
  
    $self->display($user, $action{"message"});
	$user->display("");
  
  } else {
  
   $user->display("You are not logged in!");
   $user->display("Type help for the commands list");
  
  }
 
 } elsif($action{"command"} eq "CHAT") {
 
  if($user->{"state"} == User::LOGGED) {
   
   $self->displayTo($user->{"username"}, $action{"to"}, $action{"message"});
   $user->display("");
  
  } else {
  
   $user->display("You are not logged in!");
   $user->display("Type help for the commands list");
  
  }
 
 } elsif($action{"command"} eq "LOG") {
 
  if($self->isUser(Utils::trim($action{"username"}), Utils::trim($action{"password"}))) {
  
   $user->logAs($action{"username"});
  
  } else {
  
   $user->display("Bad username or password!");
  
  }
 
 } elsif($action{"command"} eq "LIST") {

  if($user->{"state"} == User::LOGGED) {
  
   $user->displayUsers();
  
  } else {
  
   $user->display("You are not logged in!");
   $user->display("Type help for the commands list");
  
  } 
 
 } elsif($action{"command"} eq "HELP") {
 
  $user->displayCommands();
 
 } elsif($action{"command"} eq "QUIT") {
  
  $user->quit();
 
 } else {
 
  $user->display("Bad command, try again...");
 
 }

}

sub display {

 my $self = shift;
 my $user = shift;
 my $message = shift;
 
 foreach my $key (keys %{$self->{"users"}}) {
 
  if(
		$self->{"users"}->{$key}->{"state"} == User::LOGGED && 
		$self->{"users"}->{$key}->{"socket"} != $user->{"socket"}
	) {
  
   $self->{"users"}->{$key}->display($user->{"username"}." says ".$message);  
  
  }
 
 }

}

sub displayTo {

 my $self = shift;
 my $from = shift;
 my $to = shift;
 my $message = shift;
 
 my $user = $self->getUserByUsername($to);
 
 if(defined($user)) {
  
  $user->display("$from says to you $message");
  
 }
 
}

sub getUserByUsername {

 my $self = shift;
 my $username = shift;

 foreach my $key (keys %{$self->{"users"}}) {
 
  if($self->{"users"}->{$key}->{"username"} eq $username) {
  
   return $self->{"users"}->{$key};
   
  }
 
 }
 
 return undef;
 
}

sub isUser {

 my $self = shift;
 my $username = shift;
 my $password = shift;
 
 if(exists $self->{"accounts"}->{$username}) {
 
  if($self->{"accounts"}->{$username} == $password) {
  
   return 1;
  
  }
 
 }
 
 return 0;

}

sub getUsers {

 my $self = shift;
 
 my @users = ();
 
 foreach my $key (keys %{$self->{"users"}}) {
 
  if($self->{"users"}->{$key}->{"state"} == User::LOGGED) {
  
   $users[$#users+1] = $self->{"users"}->{$key}->{"username"};
   
  }
  
 }
 
 return @users;

}

sub getCommands {

 my $self = shift;
 my $user = shift;
 
 my @commands = ();
 
 foreach my $key (keys %ProtocolAnalyser::patterns) {
 
  $commands[$#commands+1] = {"command" => $ProtocolAnalyser::patterns{$key}, "descriptio" => $ProtocolAnalyser::descriptions{$key}};
  
 }
 
 return @commands;

}

sub stop {

 my $self = shift;

 close($self->{"socket"});

 foreach my $key (keys %{$self->{"users"}}) {

  $self->{"users"}->{$key}->close();

 }

}

sub report {

 open(TEMP, ">>log.txt");
 print TEMP shift;
 print TEMP "\r\n";
 close(TEMP);

}

1;
