use Mojo::Base -strict;

use Test::More;
use Mojo::Pg::Che;

plan skip_all => 'set env TEST_PG="<dsn>/<pg_user>/<passwd>" to enable this test' unless $ENV{TEST_PG};

my ($dsn, $user, $pw) = split m|[/]|, $ENV{TEST_PG};

my $pg = Mojo::Pg::Che->connect($dsn, $user, $pw,);

my $tx = $pg->begin;

$tx->do('create sequence test_che_seq;');


# Invalid connection string
#~ eval { Mojo::Pg->new('http://localhost:3000/test') };
#~ like $@, qr/Invalid PostgreSQL connection string/, 'right error';

done_testing();