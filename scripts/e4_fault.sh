#!/bin/bash
# E4: freeze the web container, measure time until ServiceDown fires
RUNS=${1:-3}
OUT=results/e4_fault.csv
[ -f "$OUT" ] || echo "run,fault_epoch,alert_latency_s" > "$OUT"

firing() { curl -s http://localhost:9090/api/v1/alerts | grep -q '"alertname":"ServiceDown"'; }

for i in $(seq 1 "$RUNS"); do
  # wait until no ServiceDown alert is active
  for t in $(seq 1 60); do firing || break; sleep 1; done
  sleep 15
  START=$(date +%s.%N)
  docker pause web > /dev/null
  FOUND=""
  for t in $(seq 1 120); do
    sleep 0.5
    if firing; then FOUND=$(date +%s.%N); break; fi
  done
  if [ -n "$FOUND" ]; then LAT=$(echo "$FOUND - $START" | bc -l); else LAT="NA"; fi
  echo "$i,$START,$LAT" | tee -a "$OUT"
  docker unpause web > /dev/null
done
