html/auth/A/Arne Skjærholt/Net::ZMQ.html  gen-dist.pl
html/dist/A/ADT/Timo Paulssen.html        gen-dist.pl
html/reports/1.html                       gen-report.pl
html/auths-A.html                         gen-dists.pl
html/dists-A.html                         gen-dists.pl

TODO

MISSING
html/recent.html                          gen-recent.pl

$ time perl6-m jobs/calc-stats.pl
real	1m1.527s
user	0m24.192s
sys	0m0.272s

$ time perl6 jobs/gen-dists.pl
real	1m58.124s
user	1m43.224s
sys	0m0.104s

$ time perl6-m jobs/gen-dist.pl
real	7m27.538s
user	7m25.200s
sys	0m0.688s

$ time perl6 jobs/gen-report.pl 
real	0m58.286s
user	0m47.796s
sys	0m0.208s
