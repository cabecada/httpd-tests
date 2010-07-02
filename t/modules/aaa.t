use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil qw(t_write_file);
use File::Spec;

Apache::TestRequest::user_agent(keep_alive => 1);

my %headers = (
                basic  => [ 'WWW-Authenticate' ],
                digest => [ 'WWW-Authenticate', 'Authentication-Info' ],
              );

my @types;

my $tests = 0;
foreach my $t (qw/basic digest/) {
    push @types, $t if have_module("mod_auth_$t");
    $tests += 5 + 2*(@{$headers{$t}});
}

plan tests => $tests,
                  need need_lwp,
                  need_module('mod_authn_core'),
                  need_module('mod_authz_core'),
                  need_module('mod_authn_file'),
                  need_module('mod_authz_host'),
                  need_min_apache_version('2.3.7');


# write out the authentication files
my $digest_file = File::Spec->catfile(Apache::Test::vars('serverroot'), 'realm2');
t_write_file($digest_file, << 'EOF' );
# udigest/pdigest
udigest:realm2:bccffb0d42943019acfbebf2039b8a3a
EOF

my $basic_file = File::Spec->catfile(Apache::Test::vars('serverroot'), 'basic1');
t_write_file($basic_file, << 'EOF' );
# ubasic:pbasic
ubasic:$apr1$opONH1Fj$dX0sZdZ0rRWEk0Wj8y.Qv1
EOF

sub check_headers
{
    my $type = shift;
    my $response = shift;
    my $code = shift;

    foreach my $h (@{$headers{$type}}) {
        ok($response->header($h),
           undef,
           "$type: $code response should have no $h header");
    }
}



foreach my $type (@types) {
    my $url   = "/authz/$type/index.html";

    {
      my $response = GET $url;

      ok($response->code,
         401,
         "$type: no user to authenticate and no env to authorize");
    }

    {
      # bad pass
      my $response = GET $url,
                       username => "u$type", password => 'foo';

      ok($response->code,
         401,
         "$type: u$type:foo not found");
    }

    {
      # authenticated
      my $response = GET $url,
                       username => "u$type", password => "p$type";

      ok($response->code,
         200,
         "$type: u$type:p$type found");
    }

    {
      # authorized by env
      my $response = GET $url, 'X-Allowed' => 'yes';

      ok($response->code,
         200,
         "$type: authz by envvar");

      check_headers($type, $response, 200);
    }

    {
      # authorized by env / with error
      my $response = GET "$url.foo", 'X-Allowed' => 'yes';

      ok($response->code,
         404,
         "$type: not found");

      check_headers($type, $response, 404);
    }
}