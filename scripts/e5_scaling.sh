#!/bin/bash
# E5: raise offered load, sample per-container CPU and memory, record Suricata drops
OUT=results/e5_scaling.csv
echo "load_mbps,container,cpu_pct,mem_mb" > "$OUT"
DROPS=results/e5_suricata_drops.csv
echo "load_mbps,capture_kernel_packets,capture_kernel_drops" > "$DROPS"

docker exec web pgrep iperf3 > /dev/null || docker exec -d web iperf3 -s
sleep 2

for L in 50 100 200 300 400 500; do
  echo "== load $L Mbps"
  docker exec -d attacker iperf3 -c 10.10.20.20 -t 25 -b ${L}M > /dev/null
  sleep 8
  for s in 1 2 3; do
    docker stats --no-stream --format '{{.Name}},{{.CPUPerc}},{{.MemUsage}}' \
      suricata prometheus node_exporter loki promtail grafana blackbox alertmanager router \
      | awk -F, -v l=$L '{split($3,m," "); mem=m[1]; gsub("%","",$2); u=mem; gsub(/[0-9.]/,"",u); v=mem; gsub(/[A-Za-z]/,"",v); if(u=="GiB")v=v*1024; if(u=="KiB")v=v/1024; print l","$1","$2","v}' >> "$OUT"
    sleep 3
  done
  sleep 10
  K=$(docker exec suricata sh -c "suricatasc -c 'dump-counters'" 2>/dev/null | tr -d ' \n' | grep -o '"capture":{[^}]*}')
  P=$(echo "$K" | grep -o '"kernel_packets":[0-9]*' | cut -d: -f2)
  D=$(echo "$K" | grep -o '"kernel_drops":[0-9]*' | cut -d: -f2)
  echo "$L,${P:-NA},${D:-NA}" >> "$DROPS"
  sleep 5
done
