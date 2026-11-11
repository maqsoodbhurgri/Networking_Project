#!/bin/bash
# Manual baseline: watch tcpdump, press Ctrl+C when you recognise the scan
RUNS=${1:-5}
OUT=results/baseline_manual.csv
[ -f "$OUT" ] || echo "run,manual_latency_s" > "$OUT"
for i in $(seq 1 "$RUNS"); do
  rm -f /tmp/attack_start
  echo "=== Run $i: watch the screen. Press Ctrl+C when you see the scan ==="
  ( sleep $((RANDOM % 21 + 10)); date +%s.%N > /tmp/attack_start
    docker exec attacker nmap -sS -Pn -T4 -p 1-2000 --max-retries 1 10.10.20.20 > /dev/null ) &
  ATT=$!
  docker exec -it router tcpdump -ni any 'tcp[tcpflags] & tcp-syn != 0 and tcp[tcpflags] & tcp-ack == 0 and not src host 10.10.20.1' -l
  NOW=$(date +%s.%N)
  if [ -f /tmp/attack_start ]; then
    LAT=$(echo "$NOW - $(cat /tmp/attack_start)" | bc -l)
  else
    LAT="FALSE_ALARM"
  fi
  wait $ATT
  echo "$i,$LAT" | tee -a "$OUT"
  echo "Next run starts in 20 s..."
  sleep 20
done
