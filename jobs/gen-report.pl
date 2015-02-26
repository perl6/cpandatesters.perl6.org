#!perl6

use v6;
use lib 'lib';

use DBIish;
use Template::Mojo;

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
                         WHERE "gen-report"
                         LIMIT 100');
$todo.execute();
while $todo.fetchrow_hashref -> $r {
    "html/reports/$r<id>.html".IO.spurt: main({
        :breadcrumb(["Report $r<id>"]),
        :content( report-details($r, from-json $r<raw>) ),
        :path(''),
    });
    $mark.execute($r<id>);
}

$dbh.disconnect();
