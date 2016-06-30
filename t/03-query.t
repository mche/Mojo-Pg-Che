use Mojo::Base -strict;

use Test::More;

plan skip_all => 'set TEST_CHE to enable this test' unless $ENV{TEST_CHE};

use Mojo::Pg::Che;
#~ use Scalar::Util 'refaddr';

my $class = 'Mojo::Pg::Che';
my $results_class = 'Mojo::Pg::Che::Results';

# 1
my $pg = $class->connect("DBI:Pg:dbname=test;", "guest", undef, {pg_enable_utf8 => 1,});

$pg->on(connection=>sub {shift; shift->do('set datestyle to "DMY, ISO";');});

my $result;
$result = $pg->query('select now() as now',);

isa_ok($result, $results_class);
like($result->hash->{now}, qr/\d{4}-\d{2}-\d{2}/, 'now query ok');

for (13..17) {
  $result = $pg->query('select ?::date as d', undef, ("$_/06/2016"));
  like($result->hash->{d}, qr/2016-06-$_/, 'date query ok');
}


{
  #~ my $db = $pg->db;
  my $sth = $pg->prepare('select ?::date as d');

  for (13..17) {
    $result = $pg->query($sth, undef, ("$_/06/2016"));
    like($result->hash->{d}, qr/2016-06-$_/, 'date sth ok');
  }
};



{
  my @results;
  my $cb = sub {
    #~ warn 'Non-block done';
    my ($db, $err, $results) = @_;
    die $err if $err;
    push @results, $results;
  };
  
  #~ my $sth = $pg->prepare();# DBD::Pg::st execute failed: Cannot execute until previous async query has finished

  for (13..17) {
    $pg->query('select ?::date as d, pg_sleep(?::int)', {cached=>1,}, ("$_/06/2016", 1), $cb);
  }
  Mojo::IOLoop->start unless Mojo::IOLoop->is_running;
  for (@results) {
    like($_->hash->{d}, qr/2016-06-\d+/, 'date sth ok');
  }
};


$result = undef;

my $cb = sub {
  #~ warn 'Non-block done';
  my ($db, $err, $results) = @_;
  die $err if $err;
  $result = $results;
};

$result = $pg->db->query('select pg_sleep(?::int), now() as now' => 2, $cb);
Mojo::IOLoop->start unless Mojo::IOLoop->is_running;
like $result->hash->{now}, qr/\d{4}-\d{2}-\d{2}/, 'now non-block-query ok';

my $die = 'OUH, BUHHH!';
my $rc = $pg->query('select ?::date as d, pg_sleep(?::int)', {Async=>1,}, ("01/06/2016", 2), sub {die $die});
isa_ok $rc, 'Mojo::Reactor::Poll';
like $rc->{cb_error}, qr/$die/;

done_testing();
