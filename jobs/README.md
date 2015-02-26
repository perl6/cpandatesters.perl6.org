html/auth/A/Arne Skjærholt/Net::ZMQ.html  gen-dist.pl
html/dist/A/ADT/Timo Paulssen.html        gen-dist.pl
html/reports/1.html                       gen-report.pl
html/auths-A.html                         gen-dists.pl
html/dists-A.html                         gen-dists.pl

TODO
- strip /github:|cpan:/ when categorizing author names

MISSING
html/recent.html                          gen-recent.pl


$ time perl6-m jobs/calc-stats.pl
real	1m1.527s
user	0m24.192s
sys	0m0.272s

$ time perl6-m jobs/gen-dists.pl
real	1m9.450s
user	1m9.160s
sys	0m0.092s

$ time perl6-m jobs/gen-dist.pl
real	7m27.538s
user	7m25.200s
sys	0m0.688s
