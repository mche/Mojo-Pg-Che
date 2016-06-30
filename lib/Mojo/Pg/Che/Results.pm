package Mojo::Pg::Che::Results;

use Mojo::Base 'Mojo::Pg::Results';

#~ sub fetchrow_hashref { shift->sth->fetchrow_hashref }
#~ sub selectrow_array { shift->sth->selectrow_array }

sub fetchcol_arrayref {
  my $self = shift;
  my ($columns, $maxrows) = @_;
  $columns ||= [1];
  $self->fetchall_arrayref($columns, $maxrows);
}

my @AUTOLOAD_METHODS = qw(
fetchrow_arrayref
fetchrow_array
fetchrow_hashref
fetchall_arrayref
fetchall_hashref
);

our $AUTOLOAD;
sub  AUTOLOAD {
  my ($method) = $AUTOLOAD =~ /([^:]+)$/;
  my $self = shift;
  my $sth = $self->sth;
  
  if ($sth->can($method) && scalar grep $_ eq $method, @AUTOLOAD_METHODS) {
    return $sth->$method(@_);
  }
  
  die sprintf qq{Can't locate autoloaded object method "%s" (%s) via package "%s" at %s line %s.\n}, $method, $AUTOLOAD, ref $self, (caller)[1,2];
  
}

1;