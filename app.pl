#!perl6

use v6;
use lib 'lib';

use Bailador;
use DBIish;

Bailador::import;

DBIish.install_driver('mysql');
my $dbh = DBIish.connect('mysql',
    :user<foo>, :password<bar>,
    :host<localhost>, :port<3306>, :database<cpandatesters>
);
my $host = '127.0.0.1';

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
    # TODO create a table `dists` and precalc its PASS ratio in a cronjob
    my $sth = $dbh.prepare("SELECT DISTINCT `distname`, `distauth`
                            FROM `cpandatesters`.`reports`
                            ORDER BY `distname`");
    $sth.execute;
    my $dist-lines = '';
    while $sth.fetchrow_hashref -> $/ {
        $dist-lines ~= dist-line($/)
    }
    main({
            :breadcrumb(['Distributions']),
            :content( dists({ :$dist-lines }) )
        },
        &request
    )
}

get /^ '/dist/' (.+) / => sub ($distname) {
    my $sth = $dbh.prepare("SELECT `id`,`grade`,`distname`,`distauth`,`distver`,`compver`,`backend`,`osname`,`osver`,`arch`
                            FROM `cpandatesters`.`reports`
                            WHERE `distname`=?
                            ORDER BY `id` DESC");
    $sth.execute($distname);
    my %reports;
    my @osnames = <linux mswin32 darwin netbsd openbsd freebsd solaris>;
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
                for <PASS FAIL NA> -> $grade {
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
                    :stats( stats([@osnames.sort], $%stats, &template) ),
                    :report-tables($reports)
                }),
            )
        },
        &request
    )
}

get '/recent' => sub {
    my $sth = $dbh.prepare("SELECT `id`,`grade`,`distname`,`distauth`,`distver`,`compver`,`backend`,`osname`,`osver`,`arch`
                            FROM `cpandatesters`.`reports`
                            ORDER BY `id` DESC
                            LIMIT 100");
    $sth.execute;
    my @reports;
    my @osnames = <linux mswin32 darwin netbsd openbsd freebsd solaris>;
    my %stats;
    while $sth.fetchrow_hashref -> $/ {
        %stats{$<compver>}{$<osname>}{$<backend>}{$<grade>}++;
        @osnames.push: $<osname> unless $<osname> ~~ any @osnames;

        $<distver>    = '0' if $<distver> eq '*';
        $<breadcrumb> = '/recent';
        @reports.push: recent-line($/)
    }
    for @osnames -> $osname {
        for %stats.keys -> $compver is copy {
            for <moar jvm parrot> -> $backend {
                my $all = [+] %stats{$compver}{$osname}{$backend}.values;
                for <PASS FAIL NA> -> $grade {
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
                    :stats( stats([@osnames.sort], $%stats, &template) ),
                    :report-tables(
                        '<h4>Top 100 reports</h4>' ~
                        recent-table({ :report-lines(@reports.join("\n")) })
                    )
                }),
            ),
        },
        &request
    )
}

get / '/report/' (.+) '/' (\d+) / => sub ($path, $id) {
    my $sth = $dbh.prepare("SELECT *
                            FROM `cpandatesters`.`reports`
                            WHERE `id`=?");
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
        main({ :$breadcrumb, :content( report-details($r, from-json $r<raw>) ) }, &request)
    }
    else {
        status 404;
        return "File not found";
    }
}

get /^ '/' ([ css | js | fonts ] '/' .+) / => sub ($file is copy) {
    content_type 'text/css';
    $file.=Str;
    $file ~~ s/ '?'.* //;
    return $file.IO.slurp(:enc<ascii>) if $file.IO.f;
}

post '/report' => sub {
    my $report = from-json request.body;
    my $sth    = $dbh.prepare("INSERT INTO `cpandatesters`.`reports`
                               (`grade`,`distname`,`distauth`,`distver`,`compver`,`backend`,`osname`,`osver`,`arch`,`raw`)
                               VALUES (?,?,?,?,?,?,?,?,?,?)");
    $sth.execute(
        $report<build-passed> && $report<test-passed> ?? 'PASS' !! 'FAIL',
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

given HTTP::Easy::PSGI.new(:$host, :port(80)) {
    .app(&dispatch-psgi);
    say "Entering the development dance floor: http://$host:80";
    .run;
}

$dbh.disconnect();
