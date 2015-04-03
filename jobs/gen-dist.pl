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
my &main         := Template::Mojo.new(slurp 'views/main.tt').code;

sub infix:<&&~>($l, $r) { $l ?? $l ~ $r !! $r }

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
    my @osnames = <linux win32 macosx netbsd openbsd freebsd solaris>;
    my %stats;
    while $sth.fetchrow_hashref -> $/ {
        %stats{$<compver>}{$<osname>}{$<backend>}{$<grade>}++;
        @osnames.push: $<osname> unless $<osname> ~~ any @osnames;

        $<distauth> ||= '<unknown>';
        $<distver>    = '0' if $<distver> eq '*';
        $<breadcrumb> = "/dist/$distname";
        %reports{$<distver>}.push: report-line($/)
    }

    my %dev-stats;
    for @osnames -> $osname {
        for %stats.keys -> $compver {
            my $dev-version = $compver ~~ /^(\d+ '.' \d+)('.' .+)$/ && ~$0;
            for <moar jvm parrot> -> $backend {
                my $all = [+] %stats{$compver}{$osname}{$backend}.values;
                for <PASS FAIL NA NOTESTS> -> $grade {
                    if $dev-version {
                        %dev-stats{$dev-version}{$osname}{$backend}{$grade} += %stats{$compver}{$osname}{$backend}{$grade} // 0;
                    }
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

    for @osnames -> $osname {
        for %dev-stats.keys -> $compver {
            for <moar jvm parrot> -> $backend {
                my $all = [+] %dev-stats{$compver}{$osname}{$backend}.values;
                for <PASS FAIL NA NOTESTS> -> $grade {
                    if %dev-stats{$compver}{$osname}{$backend}{$grade} {
                        %dev-stats{$compver}{$osname}{$backend}{$grade} /= $all / 100;
                        if 0 < %dev-stats{$compver}{$osname}{$backend}{$grade} < 2 {
                            %dev-stats{$compver}{$osname}{$backend}{$grade}.=ceiling
                        }
                        else {
                            %dev-stats{$compver}{$osname}{$backend}{$grade}.=floor;
                        }
                    }
                    else {
                        %dev-stats{$compver}{$osname}{$backend}{$grade} = 0
                    }
                }
                my $deviation = 100 - [+] %dev-stats{$compver}{$osname}{$backend}.values;
                if -10 < $deviation < 10 {
                    my $grade = %dev-stats{$compver}{$osname}{$backend}.sort(*.value).reverse[0].key;
                    %dev-stats{$compver}{$osname}{$backend}{$grade} += $deviation;
                }
            }
        }
    }

    @osnames.=sort;
    my $stats = '';

    my $last-dev-version = '';
    for %stats.keys.sort({ Version.new($^b) cmp Version.new($^a)}) -> $compver {
        my $dev-version = $compver ~~ /^(\d+ '.' \d+)('.' .+)$/ && ~$0;
        if !$dev-version { # release
            $stats &&~= '</tbody>';
            $stats   ~= '<tbody><tr>
                             <td><h4 style="margin: 0">' ~ $compver ~ '</h4></td>
                             <td>' ~ @osnames.map({ cell(%stats{$compver}{$_}) }).join('</td><td>') ~ '</td>
                         </tr>';
            $last-dev-version = '';
        }
        else { # dev release
            if $dev-version ne $last-dev-version {
                my $id    = $dev-version.subst(/\W/, '_');
                $stats &&~= '</tbody>';
                $stats   ~= '<tbody><tr class="pointer clickableRow" data-toggle="#' ~ $id ~ '">
                                 <td><h4 class="text-muted" style="margin: 0"><span class="fa fa-ellipsis-v"></span> ' ~ $dev-version ~ '.*</h4></td>
                                 <td>' ~ @osnames.map({ cell(%dev-stats{$dev-version}{$_}) }).join('</td><td>') ~ '</td>
                             </tr></tbody><tbody id="' ~ $id ~ '" class="collapse out">';
                $last-dev-version = $dev-version;
            }
            $stats ~= '<tr>
                           <td>' ~ $compver ~ '</td>
                           <td>' ~ @osnames.map({ cell(%stats{$compver}{$_}) }).join('</td><td>') ~ '</td>
                       </tr>';
        }
    }
    $stats &&~= '</tbody>';
    my $width = (85 / @osnames.elems).Int;
    $stats    = '<thead>
                    <tr>
                        <th width="15%">Compiler version</th>
                        ' ~ @osnames.map({'<th width="' ~ $width ~ '%">' ~ $_ ~ '</th>'}).join ~ '
                    </tr>
                </thead>'
              ~ $stats;

    my $reports  = '';
    my @distvers = %reports.keys.sort({ Version.new($^b) cmp Version.new($^a)});
    for @distvers -> $distver {
        $reports ~= '<h4>v' ~ $distver ~ '</h4>'
                  ~ report-table({ :report-lines(%reports{$distver}.join("\n")) })
    }

    my $content = dist({ :$stats, :report-tables($reports) });

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
