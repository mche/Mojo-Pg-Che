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
    my $pg = Mojo::Pg::Che->new->dsn("DBI:Pg:dbname=test;")->username("pg-user")->password('pg-passwd')->options(\%attrs);
    ...

=head1 AUTHOR

Михаил Че (Mikhail Che), C<< <mche[-at-]cpan.org> >>

=head1 BUGS / CONTRIBUTING

Please report any bugs or feature requests at L<https://github.com/mche/Mojo-Pg-Che/issues>. Pull requests also welcome.

=head1 COPYRIGHT

Copyright 2016 Mikhail Che.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


sub connect {
  my $self = shift->SUPER::new;
  map $self->$_(shift), qw(dsn username password);
  if (my $attrs = shift) {
    my $options = $self->options;
    @$options{ keys %$attrs } = values %$attrs;
  }
  return $self;
}

1; # End of Mojo::Pg::Che
