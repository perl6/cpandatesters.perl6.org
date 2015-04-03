#!perl6

use v6;
use lib 'lib';

use DBIish;
use Template::Mojo;
use IDNA::Punycode;

# database configuration
DBIish.install_driver('Pg');
my $dbh = DBIish.connect('Pg',
    :user<cpandatesters>, :password<cpandatesters>,
    :host<localhost>, :port<5432>, :dbname<cpandatesters>,
    :RaiseError
);

my &report-details := Template::Mojo.new(slurp 'views/report-details.tt').code;
my &main           := Template::Mojo.new(slurp 'views/main.tt').code;

my $mark = $dbh.prepare('UPDATE reports
                         SET "gen-report" = FALSE
                         WHERE id = ?');
my $todo = $dbh.prepare('SELECT *
                         FROM reports
                         WHERE "gen-report"');
$todo.execute();
while $todo.fetchrow_hashref -> $r {
    my $report-data = from-json $r<raw>;

    my $distname = $r<distname>;

    my $dist-letter = $distname.substr(0, 1).uc;
    $dist-letter    = '#' if $dist-letter !~~ 'A' .. 'Z';
    my $path        = "/dist/$dist-letter";

    my $_distauth = $r<distauth> || '<unknown>';
    $_distauth   ~~ s:i/^ [ 'github:' | 'git:' | 'cpan:' ] //;

    $path = "$path/" ~ encode_punycode($distname);

    "html/reports/$r<id>.html".IO.spurt: main({
        :breadcrumb(["$path/{encode_punycode($_distauth)}.html" R=> $report-data<name>, "Report $r<id>"]),
        :content( report-details($r, $report-data) ),
        :path(''),
    });
    $mark.execute($r<id>);
}

$dbh.disconnect();
