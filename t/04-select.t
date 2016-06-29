use Mojo::Base -strict;

use Test::More;

plan skip_all => 'set TEST_ONLINE to enable this test' unless $ENV{TEST_CHE};

use Mojo::Pg::Che;
#~ use Scalar::Util 'refaddr';

my $class = 'Mojo::Pg::Che';

# 1
my $pg = $class->connect("DBI:Pg:dbname=test;", "guest", undef, {pg_enable_utf8 => 1,})->on_connect(['set datestyle to "DMY, ISO";']);

my $result;
$result = $pg->selectrow_hashref('select now() as now',);
like($result->{now}, qr/\d{4}-\d{2}-\d{2}/, 'now top select');

{
  my $db = $pg->db;
  my $result = $db->selectrow_hashref('select now() as now',);
  like($result->{now}, qr/\d{4}-\d{2}-\d{2}/, 'now db select');
  
};

$result = $pg->selectrow_hashref('select now() as now, pg_sleep(?)', {Async=>1}, (1));
like $result->{now}, qr/\d{4}-\d{2}-\d{2}/, 'now top select';

{
  my @result;
  for (142..144) {
    push @result, $pg->selectrow_array('select ?::int, 100', undef, ($_));
  }
  is scalar @result, 6, 'selectrow_array';
};

{
  my @result;
  my $sth = $pg->prepare('select ?::int, pg_sleep(1)');
  for (142..144) {
    push @result, $pg->selectrow_arrayref($sth, {Async=>1}, ($_));
  }
  is scalar @result, 3, 'selectrow_arrayref';
  is scalar @{$result[2]}, 2, 'selectrow_arrayref';
};

{
  my @result;
  my $sth = $pg->prepare('select ?::int, now()');
  for (142..144) {
    push @result, $pg->selectall_arrayref($sth, {Slice=>[1]}, ($_));
  }
  is scalar @result, 3, 'selectall_arrayref';
  is scalar @{$result[2]}, 1, 'selectall_arrayref Slice';
  like $result[0][0], qr/\d{4}-\d{2}-\d{2}/, 'selectall_arrayref slice column value';
};

done_testing();
