use Mojo::Base -strict;

use Test::More;
use Mojo::Pg::Che;

plan skip_all => 'set env TEST_PG="DBI:Pg:dbname=<...>/<pg_user>/<passwd>" to enable this test' unless $ENV{TEST_PG};

my ($dsn, $user, $pw) = split m|[/]|, $ENV{TEST_PG};

my $pg = Mojo::Pg::Che->connect($dsn, $user, $pw,);

my $seq_name = 'Mojo_Pg_Che_test_seq_remove_it';

my $r = $pg->do("drop sequence IF EXISTS $seq_name;");
is $r, '0E0', 'do create';

my $seq_tx = sub {
  my ($commit) = @_;
  my $tx = $pg->begin;
  my $rc = $tx->do("create sequence $seq_name;");
  $tx->commit
    if $commit;
  is $rc, '0E0', 'do create';
  #~ return $tx;
};

my $seq = sub { $pg->query("select * from $seq_name;") };



$seq_tx->();

my $res = eval { $seq->() };
like $@, qr/execute failed/, 'right rollback';

$seq_tx->(1);
#$tx->commit;

$res = eval { $seq->() };
is  $res->hash->{last_value}, 1, 'right commit';

my ($rc, $sth) = $pg->do("drop sequence $seq_name;");#, {Async=>1}
#~ Mojo::IOLoop->start unless Mojo::IOLoop->is_running;
#~ warn $sth;
#~ warn $$rc->()->hash;
#~ is $rc, 1, 'do async drop';


$res = eval { $seq->() };
like $@, qr/execute failed/, 'right autocommit';

done_testing();
