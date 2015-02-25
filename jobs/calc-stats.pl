#!perl6

use v6;
use lib 'lib';

use DBIish;

# database configuration
DBIish.install_driver('Pg');
my $dbh = DBIish.connect('Pg',
    :user<cpandatesters>, :password<cpandatesters>,
    :host<localhost>, :port<5432>, :dbname<cpandatesters>,
    :RaiseError,
);

my $mark_report    = $dbh.prepare('UPDATE reports
                                   SET "calc-stats" = FALSE
                                   WHERE id = ?');
my $dists_todo     = $dbh.prepare('SELECT DISTINCT distname, distauth
                                   FROM reports
                                   WHERE "calc-stats"
                                   LIMIT 100');
my $insert_quality = $dbh.prepare('INSERT INTO distquality
                                   (distname,distauth,backend,pass,na,fail)
                                   VALUES (?,?,?,?,?,?)');
my $update_quality = $dbh.prepare('UPDATE distquality
                                   SET backend=?,pass=?,na=?,fail=?
                                   WHERE distname=?
                                     AND distauth=?
                                     AND backend=?
                                   RETURNING id');
my $select_reports = $dbh.prepare('SELECT id,grade,distname,distver,backend
                                   FROM reports
                                   WHERE distname=? AND distauth=?
                                   ORDER BY id DESC');

my @distnames;
$dists_todo.execute;
while $dists_todo.fetchrow_hashref -> $/ {
    @distnames.push: $<distname>, $<distauth>
}

for @distnames -> $distname, $distauth {
    my %reports;
    my %stats;
    my %compver-count;
    my @report-ids;
    $select_reports.execute($distname, $distauth);
    while $select_reports.fetchrow_hashref -> $/ {
        @report-ids.push: $<id>;
        %compver-count{$<distver>}++;
        $<distver> = '0'  if $<distver> eq '*';
        $<grade>   = 'NA' if $<grade>   eq 'NOTESTS';
        %reports{$<distver>}{$<backend>}{$<grade>}++;
    }

    my $report-count = 0;
    for %reports.keys.sort({ Version.new($^b) cmp Version.new($^a) }) -> $distver {
        for <moar jvm parrot> -> $backend {
            for <PASS FAIL NA> -> $grade {
                %stats{$backend}{$grade} += %reports{$distver}{$backend}{$grade} || 0;
            }
            $report-count += [+] %reports{$distver}{$backend}.values;
        }
        last if $report-count > 20;
    }

    for <moar jvm parrot> -> $backend {
        my $all = [+] %stats{$backend}.values;
        for <PASS FAIL NA> -> $grade {
            if %stats{$backend}{$grade} {
                %stats{$backend}{$grade} /= $all / 100;
                if 0 < %stats{$backend}{$grade} < 2 {
                    %stats{$backend}{$grade}.=ceiling
                }
                else {
                    %stats{$backend}{$grade}.=floor
                }
            }
            else {
                %stats{$backend}{$grade} = 0
            }
        }
        my $deviation = 100 - [+] %stats{$backend}.values;
        if -10 < $deviation < 10 {
            my $grade = %stats{$backend}.sort(*.value).reverse[0].key;
            %stats{$backend}{$grade} += $deviation;
        }
    }

    for <moar jvm parrot> {
        unless try $insert_quality.execute($distname, $distauth, $_, %stats{$_}<PASS>, %stats{$_}<NA>, %stats{$_}<FAIL>) {
            $update_quality.execute($_, %stats{$_}<PASS>, %stats{$_}<NA>, %stats{$_}<FAIL>, $distname, $distauth, $_)
        }
    }

    # XXX can we do `WHERE id IN (?)` and pass a list to .execute?
    $mark_report.execute($_) for @report-ids;
}

$dbh.disconnect();
