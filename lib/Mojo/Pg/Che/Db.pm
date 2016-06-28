package Mojo::Pg::Che::Db;

#~ use Mojo::Base 'Mojo::Pg::Database';
use Mojo::Base -base;
use Carp qw(croak shortmess);
use DBD::Pg ':async';
#~ use Mojo::JSON 'to_json';

#~ my $handler_err => ;

has [qw(dbh pg)];

has mojo_db => sub {
  my $self = shift;
  require Mojo::Pg::Database;
  Mojo::Pg::Database->new(pg=>$self->pg, dbh=>$self->dbh);
};

sub query_sth {
  my ($self, $sth, @bind) = @_;
  
  croak 'Non-blocking query already in progress' if $self->mojo_db->{waiting};
  
  my $dbh = $self->dbh;
  my $result;
  my $cb = sub {
    my ($db, $err) = map shift, 1..2;
    croak "Error (cb): ",$err if $err;
    #~ die shift;
    $result = shift;
  }
    if $dbh->{private_che_async};
  
  
  local $sth->{HandleError} = sub {$_[0] = shortmess $_[0]; 0;};
  #~ $sth->execute(map { _json($_) ? to_json $_->{json} : $_ } @_);
  $sth->execute(@bind);
  
  # Blocking
  unless ($dbh->{private_che_async}) {
    $self->mojo_db->_notifications;
    return Mojo::Pg::Results->new(sth => $sth);
  }
  
  # Non-blocking
  #~ print STDERR "Starting non-blocking query ..."
    #~ if $self->pg->debug;
  
  $self->mojo_db->{waiting} = {cb => $cb, sth => $sth};
  $self->mojo_db->_watch;
  
  #~ print STDERR "... done non-blocking query"
    #~ if $self->pg->debug;
  
  $dbh->{private_che_async} = undef;
  
  return $result;
}

sub query_string {
  my ($self, $query, $attrs, @bind) = @_;
  
  my $dbh = $self->dbh;
  
  #~ use Data::Dumper;
  ($dbh->{private_che_async} = delete $attrs->{async})
    and ($attrs->{pg_async} = PG_ASYNC)
    #~ and die Dumper($attrs);
    if $attrs->{async};
  
  my $sth;
  if (delete $attrs->{cached}) {
    $sth = $dbh->prepare_cached($query, $attrs, 3);
  } else {
    $sth = $dbh->prepare($query, $attrs,);
  }
  
  #~ die Dumper($sth->private_attribute_info)
    #~ if $self->pg->debug;
  
  return $self->query_sth($sth, @bind);
  
}

sub DESTROY {
  my $self = shift;

  my $waiting = $self->mojo_db->{waiting};
  $waiting->{cb}($self, 'Premature connection close', undef) if $waiting->{cb};

  return unless (my $pg = $self->pg) && (my $dbh = $self->dbh);
  $pg->_enqueue($dbh);
}

1;