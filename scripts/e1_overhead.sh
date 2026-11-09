#!/bin/bash
# E1: monitoring OFF vs ON, alternating rounds, CPU-pinned client/server
ROUNDS=${1:-10}
OUT=results/e1_overhead.csv
MON="suricata node_exporter blackbox prometheus alertmanager grafana loki promtail"
echo "mode,round,tcp_mbps,udp_jitter_ms,udp_loss_pct,ping_avg_ms" > "$OUT"

docker update --cpuset-cpus 0 client1 > /dev/null
docker update --cpuset-cpus 2 web > /dev/null
docker exec web pgrep iperf3 > /dev/null || docker exec -d web iperf3 -s
sleep 2

one() {
  TCP=$(docker exec client1 iperf3 -c 10.10.20.20 -t 5 -b 1G -f m 2>/dev/null | awk '/receiver/{print $7}')
  UDP=$(docker exec client1 iperf3 -c 10.10.20.20 -u -b 1G -t 5 -f m 2>/dev/null | awk '/receiver/{print $9","$12}' | tr -d '()%')
  PNG=$(docker exec client1 ping -c 20 -i 0.2 -q 10.10.20.20 | awk -F/ '/rtt/{print $5}')
  echo "$1,$2,$TCP,${UDP:-NA,NA},$PNG" | tee -a "$OUT"
}

for r in $(seq 1 "$ROUNDS"); do
  if [ $((r % 2)) -eq 1 ]; then ORDER="off on"; else ORDER="on off"; fi
  for m in $ORDER; do
    if [ "$m" = off ]; then docker compose stop $MON > /dev/null; sleep 5
    else docker compose start $MON > /dev/null; sleep 25; fi
    one "$m" "$r"
  done
done
docker compose start $MON > /dev/null
