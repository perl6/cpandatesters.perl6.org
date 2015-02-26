#!perl6

use v6;
use lib 'lib';

use DBIish;
use Template::Mojo;
use URI::Encode;
use IDNA::Punycode;

# database configuration
DBIish.install_driver('Pg');
my $dbh = DBIish.connect('Pg',
    :user<cpandatesters>, :password<cpandatesters>,
    :host<localhost>, :port<5432>, :dbname<cpandatesters>,
    :RaiseError
);

my &dist         := Template::Mojo.new(slurp 'views/dist.tt').code;
my &cell         := Template::Mojo.new(slurp 'views/cell.tt').code;
my &report-line  := Template::Mojo.new(slurp 'views/report-line.tt').code;
my &report-table := Template::Mojo.new(slurp 'views/report-table.tt').code;
my &stats        := Template::Mojo.new(slurp 'views/stats.tt').code;
my &main         := Template::Mojo.new(slurp 'views/main.tt').code;

my $todo = $dbh.prepare('SELECT DISTINCT distname,distauth
                         FROM distquality
                         WHERE "gen-dist"');
my $mark = $dbh.prepare('UPDATE distquality
                         SET "gen-dist"=FALSE
                         WHERE distname=?
                           AND distauth=?');
$todo.execute();
my @name-auth;
while $todo.fetchrow_hashref -> $/ {
    @name-auth.push: $<distname>, $<distauth>
}

for @name-auth -> $distname, $distauth {
    my $sth = $dbh.prepare('SELECT id,grade,distname,distauth,distver,compver,backend,osname,osver,arch
                            FROM reports
                            WHERE distname=? AND distauth=?
                            ORDER BY id DESC');
    $sth.execute($distname, $distauth);
    my %reports;
    my @osnames = <linux mswin32 macosx netbsd openbsd freebsd solaris>;
    my %stats;
    while $sth.fetchrow_hashref -> $/ {
        %stats{$<compver>}{$<osname>}{$<backend>}{$<grade>}++;
        @osnames.push: $<osname> unless $<osname> ~~ any @osnames;

        $<distauth> ||= '<unknown>';
        $<distver>    = '0' if $<distver> eq '*';
        $<breadcrumb> = "/dist/$distname";
        %reports{$<distver>}.push: report-line($/)
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

    my $reports  = '';
    my @distvers = %reports.keys.sort({ Version.new($^b) cmp Version.new($^a)});
    for @distvers -> $distver {
        $reports ~= '<h4>v' ~ $distver ~ '</h4>'
                  ~ report-table({ :report-lines(%reports{$distver}.join("\n")) })
    }

    my $content = dist({
                    :stats( stats([@osnames.sort], $%stats, &cell) ),
                    :report-tables($reports)
                });

    my $dist-letter = $distname.substr(0, 1).uc;
    $dist-letter    = '#' if $dist-letter !~~ 'A' .. 'Z';
    my $path        = "html/dist/$dist-letter";
    mkdir $path unless $path.IO.d;

    my $_distauth = $distauth || '<unknown>';
    $_distauth   ~~ s:i/^ [ 'github:' | 'git:' | 'cpan:' ] //;

    $path = "$path/" ~ encode_punycode($distname);
    mkdir $path unless $path.IO.d;
    "$path/{encode_punycode($_distauth)}.html".IO.spurt: main({
            :breadcrumb(['Distributions' => "/dists-&uri_encode($dist-letter).html", ~$distname]),
            :$content,
            :path("/dists-&uri_encode($dist-letter).html"),
        }
    );

    my $auth-letter = $_distauth.substr(0, 1).uc;
    $auth-letter    = '#' if $auth-letter !~~ 'A' .. 'Z';
    $path           = "html/auth/$auth-letter";
    mkdir $path unless $path.IO.d;

    $path       = "$path/" ~ encode_punycode($_distauth);
    mkdir $path unless $path.IO.d;
    "$path/{encode_punycode($distname)}.html".IO.spurt: main({
            :breadcrumb(['Authors' => "/auths-&uri_encode($auth-letter).html", ~$distname]),
            :$content,
            :path("/auths-&uri_encode($auth-letter).html"),
        }
    );

    $mark.execute($distname, $distauth);
}

$dbh.disconnect();
