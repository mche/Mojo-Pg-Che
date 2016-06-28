use Mojo::Base -strict;

use Test::More;
use Mojo::Pg::Che;
use Scalar::Util 'refaddr';

my $class = 'Mojo::Pg::Che';
my $results_class = 'Mojo::Pg::Results';

# 1
my $pg = $class->connect("DBI:Pg:dbname=test;", "guest", undef, {pg_enable_utf8 => 1,})->on_connect(['set datestyle to "DMY, ISO";']);

my $result;
$result = $pg->query('select now() as now',);

isa_ok($result, $results_class);
like  ($result->hash->{now}, qr/\d{4}-\d{2}-\d{2}/, 'now query ok');

for (13..30) {
  $result = $pg->query('select ?::date as d', undef, ("$_/06/2016"));
  like  ($result->hash->{d}, qr/2016-06-$_/, 'date query ok');
}

#~ {
  #~ my $db = $pg->db;
  #~ my $sth = $db->dbh->prepare('select ?::date as d');

  #~ for (13..30) {
    #~ $result = $pg->query($sth, ("$_/06/2016"));
    #~ like  ($result->hash->{d}, qr/2016-06-$_/, 'date sth ok');
  #~ }
#~ };

$pg->debug(1);

#~ $result = $pg->query('select pg_sleep(3), now() as now', {async=>1,});
#~ like  ($result->hash->{now}, qr/\d{4}-\d{2}-\d{2}/, 'now nb-query ok');

$result = undef;

$pg->db->query('select pg_sleep(3), now() as now',
  sub {
    warn 'Non-block done';
    my ($db, $err, $results) = @_;
    die $err if $err; $result = $results;
  }
);
like  ($result->hash->{now}, qr/\d{4}-\d{2}-\d{2}/, 'now nb-query ok');



done_testing();
