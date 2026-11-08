#!/bin/bash
# E2: port scan detection latency, Method A vs Method B
# Usage: ./scripts/e2_scan.sh <number_of_runs>
RUNS=${1:-3}
OUT=results/e2_scan.csv
[ -f "$OUT" ] || echo "run,start_epoch,suricata_latency_s,prometheus_latency_s" > "$OUT"

for i in $(seq 1 "$RUNS"); do
  sleep 25   # let the alert state and thresholds reset
  LOGLINES=$(wc -l < logs/suricata/eve.json)
  START=$(date +%s.%N)

  docker exec attacker nmap -sS -Pn -T4 -p 1-2000 --max-retries 1 10.10.20.20 > /dev/null

  # Method B: first Suricata port-scan alert after START
  B=$(tail -n +$((LOGLINES+1)) logs/suricata/eve.json | grep '"signature_id":1000001' | head -1 \
      | grep -o '"timestamp":"[^"]*"' | cut -d'"' -f4)
  if [ -n "$B" ]; then
    B_EPOCH=$(date -d "$B" +%s.%N)
    B_LAT=$(echo "$B_EPOCH - $START" | bc -l)
  else
    B_LAT="NA"
  fi

  # Method A: first time the alert was firing after START (Prometheus range query)
  sleep 20; END=$(date +%s)
  A_TS=$(curl -s "http://localhost:9090/api/v1/query_range?query=ALERTS%7Balertname%3D%22SuspiciousPacketRate%22%2Calertstate%3D%22firing%22%7D&start=${START%.*}&end=$END&step=1" \
      | grep -o '\[[0-9.]*,"1"\]' | head -1 | grep -o '[0-9.]*' | head -1)
  if [ -n "$A_TS" ]; then
    A_LAT=$(echo "$A_TS - $START" | bc -l)
  else
    A_LAT="NA"
  fi

  echo "$i,$START,$B_LAT,$A_LAT" | tee -a "$OUT"
done
