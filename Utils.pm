package Utils;
use strict;

sub trim {

 my $string = shift;
 $string =~ s/^\s+//;
 $string =~ s/\s+$//;

 chomp($string);
 
 return $string;
 
}

1;
