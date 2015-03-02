#!perl6

use v6;
use lib 'lib';

use DBIish;
use Template::Mojo;

my $lock = 'gen-recent.lock'.IO;
exit if $lock.e;

'gen-recent.lock'.IO.open(:w).close; # that's like `touch gen-report.lock`

# database configuration
DBIish.install_driver('Pg');
my $dbh = DBIish.connect('Pg',
    :user<cpandatesters>, :password<cpandatesters>,
    :host<localhost>, :port<5432>, :dbname<cpandatesters>,
    :RaiseError
);

my $newest-report-id = -1;

my $needs-update-query = $dbh.prepare('SELECT id FROM reports ORDER BY id DESC LIMIT 1');
$needs-update-query.execute;
$newest-report-id = $needs-update-query.fetch[0].Int;

my $last-count = 'last-recents-report'.IO;

if $last-count.e {
    if $last-count.slurp.Int == $newest-report-id {
        $lock.unlink;
        exit 0;
    }
}

my &main           := Template::Mojo.new(slurp 'views/main.tt').code;
my &dist           := Template::Mojo.new(slurp 'views/dist.tt').code;
my &cell           := Template::Mojo.new(slurp 'views/cell.tt').code;
my &stats          := Template::Mojo.new(slurp 'views/stats.tt').code;
my &recent-line    := Template::Mojo.new(slurp 'views/recent-line.tt').code;
my &recent-table   := Template::Mojo.new(slurp 'views/recent-table.tt').code;

my $sth = $dbh.prepare('SELECT id,grade,distname,distauth,distver,compver,backend,osname,osver,arch
                        FROM reports
                        ORDER BY id DESC
                        LIMIT 1000');
my $actual-report-count = $sth.execute;


my $osnamequery = $dbh.prepare('SELECT DISTINCT osname FROM reports');
$osnamequery.execute;
my @osnames = $osnamequery.fetchall-array>>[0];

my @reports;
my %stats;
while $sth.fetchrow_hashref -> $/ {
    %stats{$<compver>}{$<osname>}{$<backend>}{$<grade>}++;

    $<distver>    = '0' if $<distver> eq '*';
    $<breadcrumb> = '/recent';
    @reports.push: recent-line($/);
}

for @osnames -> $osname {
    for %stats.keys -> $compver is copy {
        for <moar jvm parrot> -> $backend {
            my $all = [+] %stats{$compver}{$osname}{$backend}.values;
            for <PASS FAIL NA NOTESTS> -> $grade {
                if %stats{$compver}{$osname}{$backend}{$grade} {
                    %stats{$compver}{$osname}{$backend}{$grade} /= $all / 100;
                    if 0 < %stats{$compver}{$osname}{$backend}{$grade} < 2 {
                        %stats{$compver}{$osname}{$backend}{$grade}.=ceiling
                    }
                    else {
                        %stats{$compver}{$osname}{$backend}{$grade}.=floor;
                    }
                }
                else {
                    %stats{$compver}{$osname}{$backend}{$grade} = 0
                }
            }
            my $deviation = 100 - [+] %stats{$compver}{$osname}{$backend}.values;
            if -10 < $deviation < 10 {
                my $grade = %stats{$compver}{$osname}{$backend}.sort(*.value).reverse[0].key;
                %stats{$compver}{$osname}{$backend}{$grade} += $deviation;
            }
        }
    }
}


'html/recent.html'.IO.spurt(
    main({
            :breadcrumb(['Most recent reports']),
            :content(
                '<h4>Code quality across operating system, compiler version and backend</h4>' ~
                dist({
                    :stats( stats([@osnames.sort], $%stats, &cell) ),
                    :report-tables(
                        "<h4>Latest $actual-report-count reports</h4>" ~
                        recent-table({ :report-lines(@reports.join("\n")) })
                    )
                }),
            ),
            :path(''),
        }
    )
);

$dbh.disconnect();
$last-count.spurt($newest-report-id);
$lock.unlink();

CATCH {
    $lock.unlink();
}
