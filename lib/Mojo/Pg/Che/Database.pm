package Mojo::Pg::Che::Database;

use Mojo::Base 'Mojo::Pg::Database';
#~ use Mojo::Base -base;
use Carp qw(croak shortmess);
use DBD::Pg ':async';
#~ use Mojo::JSON 'to_json';

#~ my $handler_err => ;

has [qw(dbh pg)];

has result_class => sub {
  require Mojo::Pg::Che::Results;
  'Mojo::Pg::Che::Results';
};

#~ has mojo_db => sub {
  #~ my $self = shift;
  #~ require Mojo::Pg::Database;
  #~ Mojo::Pg::Database->new(pg=>$self->pg, dbh=>$self->dbh);
#~ };

sub query_sth {
  my ($self, $sth,) = map shift, 1..2;
  
  my $cb = ref $_[-1] eq 'CODE' ? pop : undef;
  
  croak 'Non-blocking query already in progress'
    if $self->{waiting};
  
  #~ my $dbh = $self->dbh;
  local $sth->{HandleError} = sub {$_[0] = shortmess $_[0]; 0;};
  $sth->{pg_async} = PG_ASYNC
    if $cb;
  #~ $sth->execute(map { _json($_) ? to_json $_->{json} : $_ } @_);
  $sth->execute(@_);#binds
  
  # Blocking
  unless ($cb) {
    $self->_notifications;
    return $self->result_class->new(sth => $sth);
  }
  
  # Non-blocking
  $self->{waiting} = {cb => $cb, sth => $sth};
  $self->_watch;
}

sub query_string {
  my ($self, $query, $attrs,) = map shift, 1..3;
  
  my $dbh = $self->dbh;
  
  my $sth = $self->prepare($query, $attrs, 3);
  
  return $self->query_sth($sth, @_);
  
}

sub prepare {
  my ($self, $query, $attrs, $flag,)  = @_;
  
  my $dbh = $self->dbh;
  
  return $dbh->prepare_cached($query, $attrs, $flag)
    if delete $attrs->{cached};
  
  return $dbh->prepare($query, $attrs,);
  
}

sub prepare_cached { shift->dbh->prepare_cached(@_); }

my @AUTOLOAD_METHODS = qw(
selectrow_array
selectrow_arrayref
selectrow_hashref
selectall_arrayref
selectall_array
selectall_hashref
selectcol_arrayref
);

our $AUTOLOAD;
sub  AUTOLOAD {
  my ($method) = $AUTOLOAD =~ /([^:]+)$/;
  my $self = shift;
  my $dbh = $self->dbh;
  
  if ($dbh->can($method) && scalar grep $_ eq $method, @AUTOLOAD_METHODS) {
    my ($sth, $query) = ref $_[0] ? (shift, undef) : (undef, shift);
    
    my $key_field = shift
      if $method eq 'selectall_hashref';
    my $attrs = shift;
    my $async = delete $attrs->{async};
    my $cb = ref $_[-1] eq 'CODE' ? pop : undef;
    
    $sth ||= $self->prepare($query, $attrs, 3,);
    my $result;
    $cb ||= sub {
      my ($db, $err) = map shift, 1..2;
      croak "Error on non-blocking $method: ",$err
        if $err;
      $result = shift;
      
    } if $async;
    
    my @bind = @_;
    
    $result = $self->query_sth($sth, @bind, $cb ? ($cb) : ());
    
    Mojo::IOLoop->start if $async && not(Mojo::IOLoop->is_running);
    
    (my $fetch_method = $method) =~ s/select/fetch/;;
    
    return $result->$fetch_method(defined $key_field ? ($key_field) : ());
  }
  
  die sprintf qq{Can't locate autoloaded object method "%s" (%s) via package "%s" at %s line %s.\n}, $method, $AUTOLOAD, ref $self, (caller)[1,2];
  
}

1;