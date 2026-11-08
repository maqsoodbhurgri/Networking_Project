#!/bin/bash
# Usage: ./scripts/summary.sh results/e2_scan.csv
for col in 3 4; do
awk -F, -v c=$col 'NR>1{t++; if($c!="NA"){n++;s+=$c;ss+=$c*$c}} END{if(n>0){m=s/n; sd=(n>1)?sqrt((ss-n*m*m)/(n-1)):0; printf "col %d: mean %.2f s, sd %.2f s, detected %d/%d\n", c, m, sd, n, t} else printf "col %d: detected 0/%d\n", c, t}' "$1"
done
