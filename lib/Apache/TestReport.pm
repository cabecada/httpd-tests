package Apache::TestReport;

use strict;
use warnings FATAL => 'all';

use Apache::Test ();
use Apache::TestConfig ();

use File::Spec::Functions qw(catfile);

sub new {
    my $class = shift;
    bless { @_ }, $class;
}

# generate t/REPORT script (or a different filename) which will drive
# Apache::TestReport
sub generate_script {
    my ($class, $file) = @_;

    $file ||= catfile 't', 'REPORT';

    my $header = Apache::TestConfig->perlscript_header;

    my $content = join "\n",
      $header, "use $class;", "$class->new(\@ARGV)->run;";

    Apache::Test::config()->write_perlscript($file, $content);
}

sub replace {
    my($self, $template) = @_;

    $template =~ s{\@(\w+)\@} {
        my $method = lc $1;
        eval { $self->$method() } || $self->{$1} || '';
    }eg;

    $template;
}

sub run {
    my $self = shift;

    print $self->replace($self->template);
}

sub config { Apache::TestConfig::as_string() }

sub report_to { 'test-dev@httpd.apache.org' }

sub postit_note {
    my $self = shift;

    my($to, $where) = split '@', $self->report_to;

    return <<EOF;
Note: Complete the rest of the details and post this bug report to
$to <at> $where. To subscribe to the list send an empty
email to $to-subscribe\@$where.
EOF
}

sub executable { $0 }

sub date { scalar gmtime() . " GMT" }

sub template {
    local $/ = undef;
    <DATA>;
}

1;
__DATA__

-------------8<---------- Start Bug Report ------------8<----------
1. Problem Description:

  [DESCRIBE THE PROBLEM HERE]

2. Used Components and their Configuration:

@CONFIG@

3. This is the core dump trace: (if you get a core dump):

  [CORE TRACE COMES HERE]

This report was generated by @EXECUTABLE@ on @DATE@.

-------------8<---------- End Bug Report --------------8<----------

@POSTIT_NOTE@