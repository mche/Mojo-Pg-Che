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

    my $pg = Mojo::Pg::Che->connect("DBI:Pg:dbname=foo;", "pg-user", 'pg-passwd', \%attrs);
    # or
    my $pg = Mojo::Pg::Che->new
      ->dsn("DBI:Pg:dbname=test;")
      ->username("pg-user")
      ->password('pg-passwd')
      ->options(\%attrs);
    
    my $result = $pg->query('select ...', {<...sth attrs...>}, @bind);
    # Bloking query
    my $result = $pg->query('select ...', undef, @bind);
    # Non-blocking query
    my $result = $pg->query('select ...', {async => 1, ...}, @bind);
    # Cached sth of query
    my $result = $pg->query('select ...', {cache => 1, ...}, @bind);
    
    # Mojo::Pg style
    my $now = $pg->db->query('select now() as now')->hash->{now};
    # prepared sth
    my $sth = $pg->db->dbh->prepare('select ...');
    # Non-blocking query sth
    my $result = $pg->query($sth, undef, @bind, sub {my ($db, $err, $result) = @_; ...});
    Mojo::IOLoop->start unless Mojo::IOLoop->is_running;
    
    # Result non-blocking query sth
    my $result = $pg->query($sth, {async => 1,}, @bind,);
    
    
    # DBI style (attr pg_async for non-blocking)
    my $now = $pg->selectrow_hashref('select pg_sleep(?), now() as now', {pg_async => 1,}, (3))->{now};

=head1 METHODS

=head2 new

Parent method of L<Mojo::Pg#new>

=head2 connect

DBI-style of new object instance. See L<DBI#connect>

=head3 query

Is a shortcut of L<Mojo::Pg::Database#query>.

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

has on_connect => sub {[]};

has qw(debug);

#~ has dbh_private_attr => sub { my $pkg = __PACKAGE__; 'private_'.($pkg =~ s/:+/_/gr); };

sub connect {
  my $self = shift->SUPER::new;
  map $self->$_(shift), qw(dsn username password);
  if (my $attrs = shift) {
    my $options = $self->options;
    @$options{ keys %$attrs } = values %$attrs;
  }
  return $self;
}

sub query {
  my $self = shift;
  #~ my ($query, $attrs, @bind) = @_;
  my ($sth, $query) = ref $_[0] ? (shift, undef) : (undef, shift);
  
  my $attrs = shift;
  my $async = delete $attrs->{async};
  
  my $cb = ref $_[-1] eq 'CODE' ? pop : undef;
  my $result;
  $cb ||= sub {
    my ($db, $err) = map shift, 1..2;
    croak "Error on non-blocking query: ",$err
      if $err;
    $result = shift;
    
  } if $async;
  
  my @bind = @_;
  
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
sub selectrow_hashref { shift->query(@_)->fetchrow_hashref }

# Patch parent Mojo::Pg::_dequeue
sub _dequeue {
  my $self = shift;

  #~ while (my $dbh = shift @{$self->{queue} || []}) { return $dbh if $dbh->ping }
  
  my $queue = $self->{queue} ||= [];
  
  for my $i (0..$#$queue) {
    
    my $dbh = $queue->[$i];
    
    return (splice(@$queue, $i, 1))[0]
      if ! $dbh->{pg_async_status} && $dbh->ping;
  }
  
  my $dbh = DBI->connect(map { $self->$_ } qw(dsn username password options));

  #~ if (my $path = $self->search_path) {
    #~ my $search_path = join ', ', map { $dbh->quote_identifier($_) } @$path;
    #~ $dbh->do("set search_path to $search_path");
  #~ }
  
  if ( $self->on_connect && @{$self->on_connect} ) {
  
    $dbh->do($_)
      for @{$self->on_connect};
    
  }
  
  ++$self->{migrated} and $self->migrations->migrate
    if !$self->{migrated} && $self->auto_migrate;
  $self->emit(connection => $dbh);

  return $dbh;
}

1; # End of Mojo::Pg::Che

__END__


sub AUTOLOAD {
  (my $name = our $AUTOLOAD) =~ s/.*:://;
  no strict 'refs';  # allow symbolic references

  *$AUTOLOAD = sub { print "$name subroutine called\n" };    
  goto &$AUTOLOAD;   # jump to the new sub
}


our @DBH_METHODS = qw(selectrow_hashref);
our $AUTOLOAD;
sub  AUTOLOAD {
  my ($method) = $AUTOLOAD =~ /([^:]+)$/;
  my $self = shift;
  
  if ($method =~ /^select/) {
    my $sth = ref $_[0] && shift;
    my $dbh = $sth->{Database}
      if $sth;
    
    my $db = $self->db($dbh);
    
    $db->dbh->can($method)
      or croak "Method [$method] not implemented";
    
    return $db->$method($sth ? ($sth) : (), @_);
  }
  
  die sprintf qq{Can't locate autoloaded object method "%s" (%s) via package "%s" at %s line %s.\n}, $method, $AUTOLOAD, ref $self, (caller)[1,2];
  
}

