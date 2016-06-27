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

    my $pg = Mojo::Pg::Che->connect("DBI:Pg:dbname=test;", "pg-user", 'pg-passwd', \%attrs);
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
    my $result = $pg->query('select ...', {pg_async => 1, ...},);
    # Mojo::Pg style
    my $now = $pg->db->query('select now() as now')->hash->{now};
    # Blocking sth
    my $sth = $pg->prepare('select ...');
    # Non-blocking sth
    my $sth = $pg->prepare('select ...', {pg_async => 1, ...},);
    # Query sth
    my $result = $pg->query($sth, undef, @bind);
    
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


has db_class => 'Mojo::Pg::Che::Database';

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
  my ($query, $attrs, @bind) = @_;
  
  my $db = $self->db;
  
  # sth
  return $db->query_sth($query, $attrs, @bind)
    if ref $query;
  
  return $db->query_string($query, $attrs, @bind);
  
}

sub db {
  my $self = shift;

  # Fork-safety
  delete @$self{qw(pid queue)} unless ($self->{pid} //= $$) eq $$;

  return $self->db_class->new(dbh => $self->_dequeue, pg => $self);
}

1; # End of Mojo::Pg::Che
