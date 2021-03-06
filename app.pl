#!perl6

use v6;
use lib 'lib';

use Bailador;
use DBIish;

Bailador::import;

# database configuration
DBIish.install_driver('Pg');
my $dbh = DBIish.connect('Pg',
    :user<cpandatesters>, :password<cpandatesters>,
    :host<localhost>, :port<5432>, :database<cpandatesters>
);

# web service config
my $host = '85.25.222.109';
my $port = 3000;

# Allow client side caching of file in css/, js/ and fonts/
my $md5fh = pipe("md5sum css/* js/* fonts/*", :r);
my %etags = $md5fh.lines.grep(*.Bool).map({ [R=>] .split("  ") });
$md5fh.close;

my &cell           := Template::Mojo.new(slurp 'views/cell.tt').code;
my &dist           := Template::Mojo.new(slurp 'views/dist.tt').code;
my &dist-line      := Template::Mojo.new(slurp 'views/dist-line.tt').code;
my &dists          := Template::Mojo.new(slurp 'views/dists.tt').code;
my &main           := Template::Mojo.new(slurp 'views/main.tt').code;
my &recent-line    := Template::Mojo.new(slurp 'views/recent-line.tt').code;
my &recent-table   := Template::Mojo.new(slurp 'views/recent-table.tt').code;
my &report-details := Template::Mojo.new(slurp 'views/report-details.tt').code;
my &report-line    := Template::Mojo.new(slurp 'views/report-line.tt').code;
my &report-table   := Template::Mojo.new(slurp 'views/report-table.tt').code;
my &stats          := Template::Mojo.new(slurp 'views/stats.tt').code;

get '/' | '/dists' => sub {
    my $sth = $dbh.prepare('SELECT *
                            FROM distquality');
    $sth.execute;
    my %dist-quality;
    while $sth.fetchrow_hashref -> $/ {
        %dist-quality{$<distname>}{$<backend>}{$_} = $/{$_} for <pass na fail>
    }

    $sth = $dbh.prepare('SELECT DISTINCT distname, distauth
                         FROM reports
                         ORDER BY distname');
    $sth.execute;
    my $dist-lines = '';
    while $sth.fetchrow_hashref -> $/ {
        $dist-lines ~= dist-line($/, %dist-quality{$<distname>})
    }
    main({
            :breadcrumb(['Distributions']),
            :content( dists({ :$dist-lines }) )
        }
    )
}

get /^ '/dist/' (.+) / => sub ($distname) {
    my $sth = $dbh.prepare('SELECT id,grade,distname,distauth,distver,compver,backend,osname,osver,arch
                            FROM reports
                            WHERE distname=?
                            ORDER BY id DESC');
    $sth.execute($distname);
    my %reports;
    my @osnames = <linux mswin32 macosx netbsd openbsd freebsd solaris>;
    my %stats;
    while $sth.fetchrow_hashref -> $/ {
        %stats{$<compver>}{$<osname>}{$<backend>}{$<grade>}++;
        @osnames.push: $<osname> unless $<osname> ~~ any @osnames;

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

    main({
            :breadcrumb(['Distributions' => '/dists', ~$distname]),
            :content( dist({
                    :stats( stats([@osnames.sort], $%stats, &cell) ),
                    :report-tables($reports)
                }),
            )
        }
    )
}

get '/recent' => sub {
    my $sth = $dbh.prepare('SELECT id,grade,distname,distauth,distver,compver,backend,osname,osver,arch
                            FROM reports
                            ORDER BY id DESC');
    $sth.execute;
    my @reports;
    my @osnames = <linux mswin32 macosx netbsd openbsd freebsd solaris>;
    my %stats;
    my int $i = 0;
    while $sth.fetchrow_hashref -> $/ {
        %stats{$<compver>}{$<osname>}{$<backend>}{$<grade>}++;
        @osnames.push: $<osname> unless $<osname> ~~ any @osnames;

        $<distver>    = '0' if $<distver> eq '*';
        $<breadcrumb> = '/recent';
        @reports.push: recent-line($/) unless ($i = $i + 1) > 1000;
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

    main({
            :breadcrumb(['Most recent reports']),
            :content(
                '<h4>Code quality across operating system, compiler version and backend</h4>' ~
                dist({
                    :stats( stats([@osnames.sort], $%stats, &cell) ),
                    :report-tables(
                        '<h4>Latest 1000 reports</h4>' ~
                        recent-table({ :report-lines(@reports.join("\n")) })
                    )
                }),
            ),
        }
    )
}

get / '/report/' (.+) '/' (\d+) / => sub ($path, $id) {
    my $sth = $dbh.prepare('SELECT *
                            FROM reports
                            WHERE id=?');
    $sth.execute($id);
    if $sth.fetchrow_hashref -> $r {
        my @path = $path.Str.split('/');
        my $breadcrumb = ["Report $id"];
        given @path[0] {
            when 'dist' {
                $breadcrumb.unshift: 'Distributions' => '/dists', @path[1] => "/dist/@path[1]"
            }
            when 'recent' {
                $breadcrumb.unshift: 'Most recent reports' => '/recent'
            }
        }
        main({ :$breadcrumb, :content( report-details($r, from-json $r<raw>) ) })
    }
    else {
        status 404;
        return "File not found";
    }
}

my @static-files = %etags.keys;
get /^ \/ (@static-files) [ '?'.* ]? / => sub ($file is copy) {
    $file.=Str;

    if %etags{$file} -> $etag {
        header('Etag', $etag);

        if request.env<HTTP_IF_NONE_MATCH> && request.env<HTTP_IF_NONE_MATCH> eq $etag {
            status 304;
            header('Cache-Control', 'private');
            header('Pragma', '');
            return ''
        }
        else {
            header('Cache-Control', 'private');
            header('Pragma', '');
        }
    }

    content_type 'text/css';

    return $file.IO.slurp(:enc<ascii>) if $file.IO.f;
}

post '/report' => sub {
    my $report = from-json request.body;
    my $sth    = $dbh.prepare('INSERT INTO reports
                               (grade,distname,distauth,distver,compver,backend,osname,osver,arch,"raw")
                               VALUES (?,?,?,?,?,?,?,?,?,?)');
    my $grade  = !$report<build-passed>.defined ?? 'NA'
              !! !$report<build-passed>         ?? 'FAIL'
              !! !$report<test-passed>.defined  ?? 'NOTESTS'
              !! !$report<test-passed>          ?? 'FAIL'
                                                !! 'PASS';
    $sth.execute(
        $grade,
        $report<name>,
        $report<metainfo><authority> || $report<metainfo><author> || $report<metainfo><auth>,
        $report<version>,
        $report<perl><compiler><version>,
        $report<vm><name>,
        $report<distro><name>,
        $report<distro><release> ne 'unknown' ?? $report<distro><release> !! $report<distro><version>,
        $report<kernel><arch> ne 'unknown' ?? $report<kernel><arch> !! $report<kernel><bits>,
        request.body,
    );
}


my $app = Bailador::App.current;

sub dispatch($env) {
    $app.context.env = $env;

    my ($r, $match) = $app.find_route($env);

    if $r {
        status 200;
        if $match {
            $app.response.content = $r.value.(|$match.list);
        } else {
            $app.response.content = $r.value.();
        }
    }

    return $app.response;
}

sub dispatch-psgi($env) {
    return dispatch($env).psgi;
}

given HTTP::Easy::PSGI.new(:$host, :$port) {
    .app(&dispatch-psgi);
    say "Entering the development dance floor: http://$host:$port";
    .run;
}

$dbh.disconnect();
