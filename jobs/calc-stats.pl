#!perl6

use v6;
use lib 'lib';

use DBIish;

# database configuration
DBIish.install_driver('Pg');
my $dbh = DBIish.connect('Pg',
    :user<cpandatesters>, :password<cpandatesters>,
    :host<localhost>, :port<5432>, :database<cpandatesters>
);

my @distnames;
# TODO create a table `dists` and precalc its PASS ratio in a cronjob
my $sth = $dbh.prepare('SELECT DISTINCT distname
                        FROM reports
                        ORDER BY distname');
$sth.execute;
while $sth.fetchrow_hashref -> $/ {
    @distnames.push: $<distname>
}

for @distnames -> $distname {
    my $sth = $dbh.prepare('SELECT id,grade,distname,distver,backend
                            FROM reports
                            WHERE distname=?
                            ORDER BY id DESC');
    $sth.execute($distname);
    my %reports;
    my %stats;
    my %compver-count;
    while $sth.fetchrow_hashref -> $/ {
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

    $sth = $dbh.prepare('INSERT INTO distquality
                         (distname,backend,pass,na,fail)
                         VALUES (?,?,?,?,?)');
    for <moar jvm parrot> {
        unless try $sth.execute($distname, $_, %stats{$_}<PASS>, %stats{$_}<NA>, %stats{$_}<FAIL>) {
            my $sth = $dbh.prepare('UPDATE distquality
                                 SET backend=?,pass=?,na=?,fail=?
                                 WHERE distname=?
                                   AND backend=?
                                 RETURNING id');
            $sth.execute($_, %stats{$_}<PASS>, %stats{$_}<NA>, %stats{$_}<FAIL>, $distname, $_)
        }
    }
}

$dbh.disconnect();
