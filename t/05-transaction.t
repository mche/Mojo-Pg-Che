use Mojo::Base -strict;

use Test::More;
use Mojo::Pg::Che;

plan skip_all => 'set env TEST_PG="DBI:Pg:dbname=<...>/<pg_user>/<passwd>" to enable this test' unless $ENV{TEST_PG};

my ($dsn, $user, $pw) = split m|[/]|, $ENV{TEST_PG};

my $pg = Mojo::Pg::Che->connect($dsn, $user, $pw,);

my $seq = 'test_seq_remove_it';

my $seq_tx = sub {
  my $tx = $pg->begin;
  my $rc = $tx->do("create sequence $seq;");
  is $rc, '0E0', 'do';
  return $tx;
};

my $seq = sub { $pg->query("select * from $seq;") };

$seq_tx->();

eval { $seq->() };
like $@, qr/execute failed/, 'right rollback';

my $tx = $seq_tx->();
$tx->commit;

warn $seq->();

done_testing();
