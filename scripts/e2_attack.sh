#!/bin/bash
# Usage: ./scripts/e2_attack.sh <scan|synflood|icmp|ssh> <runs>
TYPE=${1:-scan}
RUNS=${2:-10}
TARGET=10.10.20.20
OUT=results/e2_${TYPE}.csv

case $TYPE in
  scan)     SID=1000001; CMD="nmap -sS -Pn -T4 -p 1-2000 --max-retries 1 $TARGET" ;;
  synflood) SID=1000002; CMD="timeout 5 hping3 -S --flood -p 80 $TARGET" ;;
  icmp)     SID=1000003; CMD="timeout 5 hping3 --icmp --flood $TARGET" ;;
  ssh)      SID=1000004; CMD="sh -c 'printf \"a\nb\nc\nd\ne\nf\ng\nh\n\" > /tmp/pw; hydra -l root -P /tmp/pw -t 4 ssh://$TARGET'" ;;
  *) echo "unknown type"; exit 1 ;;
esac

[ -f "$OUT" ] || echo "run,start_epoch,suricata_latency_s,prometheus_latency_s" > "$OUT"

for i in $(seq 1 "$RUNS"); do
  sleep 25
  LOGLINES=$(wc -l < logs/suricata/eve.json)
  START=$(date +%s.%N)

  eval "docker exec attacker $CMD" > /dev/null 2>&1

  B=$(tail -n +$((LOGLINES+1)) logs/suricata/eve.json | grep "\"signature_id\":$SID" | head -1 \
      | grep -o '"timestamp":"[^"]*"' | cut -d'"' -f4)
  if [ -n "$B" ]; then
    B_LAT=$(echo "$(date -d "$B" +%s.%N) - $START" | bc -l)
  else
    B_LAT="NA"
  fi

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
