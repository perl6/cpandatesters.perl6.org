#!perl6

use v6;
use lib 'lib';

use DBIish;
use Template::Mojo;
use URI::Encode;

# database configuration
DBIish.install_driver('Pg');
my $dbh = DBIish.connect('Pg',
    :user<cpandatesters>, :password<cpandatesters>,
    :host<localhost>, :port<5432>, :dbname<cpandatesters>,
    :RaiseError
);

my &dist           := Template::Mojo.new(slurp 'views/dist.tt').code;
my &dist-line      := Template::Mojo.new(slurp 'views/dist-line.tt').code;
my &dist-letters   := Template::Mojo.new(slurp 'views/dist-letters.tt').code;
my &dists          := Template::Mojo.new(slurp 'views/dists.tt').code;
my &main           := Template::Mojo.new(slurp 'views/main.tt').code;

my $mark = $dbh.prepare('UPDATE distquality
                         SET "gen-dists" = FALSE
                         WHERE id = ?');
my $todo = $dbh.prepare('SELECT *
                         FROM distquality');
my %dist-quality;
my @gen-dists;
$todo.execute;
while $todo.fetchrow_hashref -> $/ {
    %dist-quality{$<distauth> || '<unknown>'}{$<distname>}{$<backend>}{$_} = $/{$_} for <pass na fail>;
    @gen-dists.push: $<id>;
}

my $sth = $dbh.prepare('SELECT DISTINCT distname, distauth
                        FROM distquality
                        ORDER BY distname');
$sth.execute;
my %dist-lines = ('A' .. 'Z', '#') »=>» '';
my %auth-lines = ('A' .. 'Z', '#') »=>» '';
while $sth.fetchrow_hashref -> $/ {
    $<distauth>   ||= '<unknown>';

    my $dist-letter = $<distname>.Str.substr(0, 1).uc;
    $dist-letter    = '#' if $dist-letter !~~ 'A' .. 'Z';

    my $auth-letter = $<distauth>.Str.substr(0, 1).uc;
    $auth-letter    = '#' if $auth-letter !~~ 'A' .. 'Z';

    my $distname    = encode_for_filesystem($<distname>);
    my $distauth    = encode_for_filesystem($<distauth>);

    %dist-lines{$dist-letter} ~= dist-line($/, %dist-quality{$<distauth>}{$<distname>}, "dist/$dist-letter/$distname/$distauth.html");
    %auth-lines{$auth-letter} ~= dist-line($/, %dist-quality{$<distauth>}{$<distname>}, "auth/$auth-letter/$distauth/$distname.html");
}

for %dist-lines.kv -> $letter, $dist-lines {
    my $dist-letters = dist-letters($letter, 'dists', %dist-lines.keys);
    "html/dists-$letter.html".IO.spurt: main({
        :breadcrumb(['Distributions']),
        :content( $dist-letters ~ dists({ :$dist-lines }) ~ $dist-letters ),
        :path("/dists-$letter.html"),
    })
}

for %auth-lines.kv -> $letter, $dist-lines {
    my $dist-letters = dist-letters($letter, 'auths', %dist-lines.keys);
    "html/auths-$letter.html".IO.spurt: main({
        :breadcrumb(['Authors']),
        :content( $dist-letters ~ dists({ :$dist-lines }) ~ $dist-letters ),
        :path("/auths-$letter.html"),
    })
}

# XXX can we do `WHERE id IN (?)` and pass a list to .execute?
#~ $mark.execute($_) for @gen-dists;

sub encode_for_filesystem($str) {
    $str.subst(/(^.)? <[\/\\+]>/, '+' ~ *.ord, :g)
}

$dbh.disconnect();
