package Mojo::Pg::Che::Database;

use Mojo::Base 'Mojo::Pg::Database';
use Carp qw(croak shortmess);
use DBD::Pg ':async';
#~ use Mojo::JSON 'to_json';

#~ my $handler_err => ;

sub query_sth {
  my ($self, $sth, @bind) = @_;
  
  croak 'Non-blocking query already in progress' if $self->{waiting};
  
  my $dbh = $self->dbh;
  my $result;
  my $cb = sub {
    my ($db, $err) = map shift, 1..2;
    croak "Error: ",$err if $err;
    #~ die shift;
    $result = shift;
  }
    if $dbh->{private_che_async};
  
  
  local $sth->{HandleError} = sub {$_[0] = shortmess $_[0]; 0;};
  #~ $sth->execute(map { _json($_) ? to_json $_->{json} : $_ } @_);
  $sth->execute(@bind);
  
  # Blocking
  unless ($dbh->{private_che_async}) {
    $self->_notifications;
    return Mojo::Pg::Results->new(sth => $sth);
  }
  
  # Non-blocking
  #~ print STDERR "Starting non-blocking query ..."
    #~ if $self->pg->debug;
  
  $self->{waiting} = {cb => $cb, sth => $sth};
  $self->_watch;
  
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

sub DESTROY000 {
  #~ shift->SUPER::DESTROY;
  
}

sub _watch {
  my $self = shift;

  return if $self->{watching} || $self->{watching}++;

  my $dbh = $self->dbh;
  unless ($self->{handle}) {
    open $self->{handle}, '<&', $dbh->{pg_socket} or die "Can't dup: $!";
  }
  Mojo::IOLoop->singleton->reactor->io(
    $self->{handle} => sub {
      #~ die 146;
      my $reactor = shift;

      $self->_unwatch if !eval { $self->_notifications; 1 };
      warn '_Watch', $self->{waiting};
      return unless $self->{waiting} && $dbh->pg_ready;
      my ($sth, $cb) = @{delete $self->{waiting}}{qw(sth cb)};

      # Do not raise exceptions inside the event loop
      my $result = do { local $dbh->{RaiseError} = 0; $dbh->pg_result };
      my $err = defined $result ? undef : $dbh->errstr;

      $self->$cb($err, Mojo::Pg::Results->new(sth => $sth));
      $self->_unwatch unless $self->{waiting} || $self->is_listening;
    }
  )->watch($self->{handle}, 1, 0);
}

1;