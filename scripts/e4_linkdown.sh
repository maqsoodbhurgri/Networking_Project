#!/bin/bash
# E4b: link-down fault. Disconnect web from the DMZ network, time to ServiceDown
RUNS=${1:-3}
OUT=results/e4_linkdown.csv
[ -f "$OUT" ] || echo "run,fault_epoch,alert_latency_s" > "$OUT"
firing() { curl -s http://localhost:9090/api/v1/alerts | grep -q '"alertname":"ServiceDown"'; }
for i in $(seq 1 "$RUNS"); do
  for t in $(seq 1 90); do firing || break; sleep 1; done
  sleep 15
  START=$(date +%s.%N)
  docker network disconnect networking_project_dmz web
  FOUND=""
  for t in $(seq 1 120); do
    sleep 0.5
    if firing; then FOUND=$(date +%s.%N); break; fi
  done
  if [ -n "$FOUND" ]; then LAT=$(echo "$FOUND - $START" | bc -l); else LAT="NA"; fi
  echo "$i,$START,$LAT" | tee -a "$OUT"
  docker network connect --ip 10.10.20.20 networking_project_dmz web
  docker restart web > /dev/null
  sleep 10
  docker exec -d web iperf3 -s
done
