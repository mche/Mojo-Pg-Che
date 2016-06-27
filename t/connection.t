use Mojo::Base -strict;

use Test::More;
use Mojo::Pg::Che;

my $class = 'Mojo::Pg::Che';
my $db_class = 'Mojo::Pg::Che::Database';
my $dbi_db_class = 'DBI::db';

# 1
my $pg1 = $class->connect("DBI:Pg:dbname=test;", "guest", undef, {pg_enable_utf8 => 1,});
# 2
my $pg2 = $class->new->dsn("DBI:Pg:dbname=test;")->username("guest")->password(undef);

isa_ok($pg1, $class);
isa_ok($pg2, $class);

isa_ok($pg1->db, $db_class);
isa_ok($pg2->db, $db_class);

isa_ok($pg1->db->dbh, $dbi_db_class);
isa_ok($pg2->db->dbh, $dbi_db_class);

cmp_ok($got, '==', $expected,);

isa_ok($pg1->db->pg, $class);
isa_ok($pg2->db, $db_class);


# Invalid connection string
#~ eval { Mojo::Pg->new('http://localhost:3000/test') };
#~ like $@, qr/Invalid PostgreSQL connection string/, 'right error';

done_testing();
