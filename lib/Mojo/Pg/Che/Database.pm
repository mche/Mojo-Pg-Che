package Mojo::Pg::Che::Database;

use Mojo::Base 'Mojo::Pg::Database';
use Carp qw(croak shortmess);
use DBD::Pg ':async';
#~ use Mojo::JSON 'to_json';

has handler_err => sub {sub {$_[0] = shortmess $_[0]; 0;}};

sub query_sth {
  my ($self, $sth, $attrs, @bind) = @_;
  
  croak 'Non-blocking query already in progress' if $self->{waiting};
  
  if ($attrs) {
    $sth->{pg_async} = PG_ASYNC
      if delete $attrs->{pg_async};
    
    @$sth{ keys %$attrs } = values %$attrs;
  }
  
  local $sth->{HandleError} = $self->handler_err;
  #~ $sth->execute(map { _json($_) ? to_json $_->{json} : $_ } @_);
  $sth->execute(@bind);
  
  # Blocking
  unless ($sth->{pg_async}) {
    $self->_notifications;
    return Mojo::Pg::Results->new(sth => $sth);
  }
  
  my $result;
  
  my $cb = sub {
    my ($db, $err) = map shift, 1..2;
    die $err if $err;
    $result = shift;
  };
  
  # Non-blocking
  $self->{waiting} = {cb => $cb, sth => $sth};
  $self->_watch;
  
  return $result;
}

sub query_string {
  my ($self, $query, $attrs, @bind) = @_;
  
  $attrs->{pg_async} = PG_ASYNC
    if delete $attrs->{pg_async};
  
  my $sth = $self->dbh->prepare_cached($query, $attrs, 3)
    if delete $attrs->{cached};
  
  $sth ||= $self->dbh->prepare($query, $attrs,);
  
  return $self->query_sth($sth, undef, @bind);
  
}

1;