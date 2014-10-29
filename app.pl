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


get '/' | '/dists' => sub {
    # TODO create a table `dists` and precalc its PASS ratio in a cronjob
    my $sth = $dbh.prepare("SELECT DISTINCT `distname`, `distauth`
                            FROM `cpandatesters`.`reports`
                            ORDER BY `distname`");
    $sth.execute;
    my $dist-lines = '';
    while $sth.fetchrow_hashref -> $/ {
        $dist-lines ~= template 'dist-line.tt', $/
    }
    template 'main.tt', {
        :breadcrumb(['Distributions']),
        :content( template 'dists.tt', { :$dist-lines })
    }
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
        %reports{$<distver>}.push: template 'report-line.tt', $/
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
                  ~ template 'report-table.tt', { :report-lines(%reports{$distver}.join("\n")) }
    }

    template 'main.tt', {
        :breadcrumb(['Distributions' => '/dists', ~$distname]),
        :content( template 'dist.tt', {
            :stats( template 'stats.tt', [@osnames.sort], $%stats, &template ),
            :report-tables($reports)
        }),
    }
}

get / '/report/' (.+) '/' (\d+) / => sub ($path, $id) {
    my $sth = $dbh.prepare("SELECT *
                            FROM `cpandatesters`.`reports`
                            WHERE `id`=?");
    $sth.execute($id);
    if $sth.fetchrow_hashref -> $r {
        my @path = $path.Str.split('/');
        my $breadcrumb = ["Report $id"];
        if @path[0] eq 'dist' {
            $breadcrumb.unshift: 'Distributions' => '/dists', @path[1] => "/dist/@path[1]"
        }
        template 'main.tt', {
            :$breadcrumb,
            :content( template 'report-details.tt', $r, from-json $r<raw>)
        }
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
        $report<metainfo><authority> // $report<metainfo><author> // $report<metainfo><auth>,
        $report<version>,
        $report<perl><compiler><version>,
        $report<vm><name>,
        $report<distro><name>,
        $report<distro><release> // $report<distro><version>,
        $report<kernel><arch>,
        request.body,
    );
}

baile;

$dbh.disconnect();
