package Mojo::Pg::Che;

use Mojo::Base 'Mojo::Pg';

=pod

=encoding utf-8

Доброго всем

=head1 Mojo::Pg::Che

¡ ¡ ¡ ALL GLORY TO GLORIA ! ! !

=head1 NAME

Mojo::Pg::Che - mix of parent Mojo::Pg and DBI.pm

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS



    use Mojo::Pg::Che;

    my $pg = Mojo::Pg::Che->connect("dbname=test;", "postgres", 'pg-pwd', \%attrs);
    # or
    my $pg = Mojo::Pg::Che->new
      ->dsn("DBI:Pg:dbname=test;")
      ->username("postgres")
      ->password('pg--pw')
      ->options(\%attrs);
    
    my $result = $pg->query('select ...', {<...sth attrs...>}, @bind);
    # Bloking query
    my $result = $pg->query('select ...', undef, @bind);
    # Non-blocking query
    my $result = $pg->query('select ...', {Async => 1, ...}, @bind);
    # Cached sth of query
    my $result = $pg->query('select ...', {Cached => 1, ...}, @bind);
    
    # Mojo::Pg style
    my $now = $pg->db->query('select now() as now')->hash->{now};
    # prepared sth
    my $sth = $pg->prepare('select ...');
    # Non-blocking query sth
    my $result = $pg->query($sth, undef, @bind, sub {my ($db, $err, $result) = @_; ...});
    Mojo::IOLoop->start unless Mojo::IOLoop->is_running;
    
    # Result non-blocking query sth
    my $result = $pg->query($sth, {Async => 1,}, @bind,);
    
    
    # DBI style (attr pg_async for non-blocking)
    my $now = $pg->selectrow_hashref('select pg_sleep(?), now() as now', {pg_async => 1,}, (3))->{now};

=head1 Non-blocking queryes cases

Depends on $attr->{Async} and callback:

1. $attr->{Async} set to 1. None $cb. Callback will create and Mojo::IOLoop will auto start. Method C<<->query()>> will return result object. Methods C<<->select...()>> will return there perl structures.

2. $attr->{Async} not set. $cb defined. All ->query() and ->select...() methods will return reactor object and results pass to $cb. You need start Mojo::IOLoop:

  my @results;
  my $cb = sub {
    my ($db, $err, $results) = @_;
    die $err if $err;
    push @results, $results;
  };
  $pg->query('select ?::date as d, pg_sleep(?::int)', undef, ("2016-06-$_", 1), $cb)
    for 17..23;
  Mojo::IOLoop->start unless Mojo::IOLoop->is_running;
  like($_->hash->{d}, qr/2016-06-\d+/, 'correct async query')
    for @results;


3. $attr->{Async} set to 1. $cb defined. Mojo::IOLoop will auto start. Results pass to $cb.


=head1 METHODS

=head2 new

Parent method of L<Mojo::Pg#new>

=head2 connect

DBI-style of new object instance. See L<DBI#connect>

=head3 query

Is same as L<Mojo::Pg::Database#query>.

Blocking query without attr B<pg_async>.

Non-blocking query with attr B<pg_async>.

=head1 AUTHOR

Михаил Че (Mikhail Che), C<< <mche[-at-]cpan.org> >>

=head1 BUGS / CONTRIBUTING

Please report any bugs or feature requests at L<https://github.com/mche/Mojo-Pg-Che/issues>. Pull requests also welcome.

=head1 COPYRIGHT

Copyright 2016 Mikhail Che.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

use Carp qw(croak);

has db_class => sub {
  require Mojo::Pg::Che::Database;
  'Mojo::Pg::Che::Database';
};

has tx_class => sub {
  require Mojo::Pg::Transaction;
  'Mojo::Pg::Transaction';
}

has options => sub {
  {AutoCommit => 1, AutoInactiveDestroy => 1, PrintError => 0, RaiseError => 1, ShowErrorStatement => 1, pg_enable_utf8 => 1,};
};
has qw(debug);

#~ has dbh_private_attr => sub { my $pkg = __PACKAGE__; 'private_'.($pkg =~ s/:+/_/gr); };

sub connect {
  my $self = shift->SUPER::new;
  map $self->$_(shift), qw(dsn username password);
  if (my $attrs = shift) {
    my $options = $self->options;
    @$options{ keys %$attrs } = values %$attrs;
  }
  $self->dsn('DBI:Pg:'.$self->dsn)
    unless $self->dsn =~ /^DBI:Pg:/;
  return $self;
}

sub query {
  my $self = shift;
  #~ my ($query, $attrs, @bind) = @_;
  my ($sth, $query) = ref $_[0] ? (shift, undef) : (undef, shift);
  
  my $attrs = shift;
  my $async = delete $attrs->{Async} || delete $attrs->{pg_async};
  
  my $cb = ref $_[-1] eq 'CODE' ? pop : undef;
  my $result;
  $cb ||= sub {
    my ($db, $err) = map shift, 1..2;
    croak "Error on non-blocking query: ",$err
      if $err;
    $result = shift;
    
  } if $async;
  
  my @bind = @_;
  
  #~ $sth ||= $self->prepare($query, $attrs, 3); ?????
  
  if ($sth) {$result = $self->db($sth->{Database})->query_sth($sth, @bind, $cb ? ($cb) : ());}
  else {$result = $self->db->query_string($query, $attrs, @bind, $cb ? ($cb) : (),);}
  
  Mojo::IOLoop->start if $async && not(Mojo::IOLoop->is_running);

  return $result;
  
}

sub db {
  my ($self, $dbh) = (shift, shift);

  # Fork-safety
  delete @$self{qw(pid queue)} unless ($self->{pid} //= $$) eq $$;
  
  $dbh ||= $self->_dequeue;

  return $self->db_class->new(dbh => $dbh, pg => $self);
}

sub prepare { shift->db->prepare(@_); }
sub prepare_cached { shift->db->prepare_cached(@_); }

sub _db_sth {shift->db(ref $_[0] && $_[0]->{Database})}

sub selectrow_array { shift->_db_sth(@_)->selectrow_array(@_) }
sub selectrow_arrayref { shift->_db_sth(@_)->selectrow_arrayref(@_) }
sub selectrow_hashref { shift->_db_sth(@_)->selectrow_hashref(@_) }
sub selectall_arrayref { shift->_db_sth(@_)->selectall_arrayref(@_) }
sub selectall_hashref { shift->_db_sth(@_)->selectall_hashref(@_) }
sub selectcol_arrayref { shift->_db_sth(@_)->selectcol_arrayref(@_) }
sub do { shift->_db_sth(@_)->do(@_) }

#~ sub begin_work {croak 'Use $pg->db->tx | $pg->db->begin';}
sub tx {shift->begin}
sub begin_work {shift->begin}
sub begin {
  my $self = shift;
  my $db = $self->db;
  #~ $db->dbh->begin_work;
  $db->{tx} = $self->tx_class->new(db => $self);
  weaken $db->{tx};
  return $db;
}

sub commit {croak 'Use $tx = $pg->tx; ...; $tx->commit;';}
sub rollback {croak 'Use $tx = $pg->tx; ...; $tx->rollback;';}

# Patch parent Mojo::Pg::_dequeue
sub _dequeue {
  my $self = shift;

  #~ while (my $dbh = shift @{$self->{queue} || []}) { return $dbh if $dbh->ping }
  
  my $queue = $self->{queue} ||= [];
  
  for my $i (0..$#$queue) {
    
    my $dbh = $queue->[$i];
    
    delete $queue->[$i]
      and next
      if $dbh->ping;
    
    return (splice(@$queue, $i, 1))[0]
      unless $dbh->{pg_async_status} > 0;
  }
  
  my $dbh = DBI->connect(map { $self->$_ } qw(dsn username password options));

  #~ if (my $path = $self->search_path) {
    #~ my $search_path = join ', ', map { $dbh->quote_identifier($_) } @$path;
    #~ $dbh->do("set search_path to $search_path");
  #~ }
  
  #~ ++$self->{migrated} and $self->migrations->migrate
    #~ if !$self->{migrated} && $self->auto_migrate;
  $self->emit(connection => $dbh);

  return $dbh;
}


1;

__END__


sub AUTOLOAD {
  (my $name = our $AUTOLOAD) =~ s/.*:://;
  no strict 'refs';  # allow symbolic references

  *$AUTOLOAD = sub { print "$name subroutine called\n" };    
  goto &$AUTOLOAD;   # jump to the new sub
}

my @AUTOLOAD_SELECT = qw(
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
  
  my $db = $self->db(ref $_[0] && $_[0]->{Database});
  
  return $db->$method(@_)
    if ($db->can($method) && scalar grep $_ eq $method, @AUTOLOAD_SELECT);
  
  die sprintf qq{Can't locate autoloaded object method "%s" (%s) via package "%s" at %s line %s.\n}, $method, $AUTOLOAD, ref $self, (caller)[1,2];
  
}
  
}

