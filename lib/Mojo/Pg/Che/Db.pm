package Mojo::Pg::Che::Db;

use Mojo::Base 'Mojo::Pg::Database';
#~ use Mojo::Base -base;
use Carp qw(croak shortmess);
use DBD::Pg ':async';
#~ use Mojo::JSON 'to_json';

#~ my $handler_err => ;

has [qw(dbh pg)];

#~ has mojo_db => sub {
  #~ my $self = shift;
  #~ require Mojo::Pg::Database;
  #~ Mojo::Pg::Database->new(pg=>$self->pg, dbh=>$self->dbh);
#~ };

sub query_sth {
  my ($self, $sth,) = map shift, 1..2;
  
  my $cb = ref $_[-1] eq 'CODE' ? pop : undef;
  
  croak 'Non-blocking query already in progress' if $self->{waiting};
  
  my $dbh = $self->dbh;
  local $sth->{HandleError} = sub {$_[0] = shortmess $_[0]; 0;};
  #~ $sth->execute(map { _json($_) ? to_json $_->{json} : $_ } @_);
  $sth->execute(@_);#binds
  
  # Blocking
  unless ($cb) {
    $self->_notifications;
    return Mojo::Pg::Results->new(sth => $sth);
  }
  
  # Non-blocking
  $self->{waiting} = {cb => $cb, sth => $sth};
  $self->_watch;
}

sub query_string {
  my ($self, $query, $attrs,) = map shift, 1..3;
  
  my $dbh = $self->dbh;
  
  my $sth;
  if (delete $attrs->{cached}) {
    $sth = $dbh->prepare_cached($query, $attrs, 3);
  } else {
    $sth = $dbh->prepare($query, $attrs,);
  }
  
  return $self->query_sth($sth, @_);
  
}

sub DESTROY0000 {
  my $self = shift;

  my $waiting = $self->{waiting};
  $waiting->{cb}($self, 'Premature connection close', undef) if $waiting->{cb};

  return unless (my $pg = $self->pg) && (my $dbh = $self->dbh);
  #~ warn "Enqueque $dbh on destroy";
  $pg->_enqueue($dbh);
}

1;