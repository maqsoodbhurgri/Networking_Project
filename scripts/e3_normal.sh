#!/bin/bash
# E3: normal traffic (untrusted + LAN users), count false alerts
DURATION=${1:-1800}
LOGLINES=$(wc -l < logs/suricata/eve.json)
START=$(date +%s)
END=$((START+DURATION))

while [ $(date +%s) -lt $END ]; do
  # outside users (go through eth1, so both detectors see them)
  docker exec attacker curl -s -o /dev/null http://10.10.20.20
  docker exec attacker curl -s -o /dev/null http://10.10.20.20/index.nginx-debian.html
  docker exec attacker ping -c 2 -q 10.10.20.20 > /dev/null
  [ $((RANDOM % 10)) -eq 0 ] && docker exec attacker nmap -Pn -p 22 10.10.20.20 > /dev/null
  # internal users
  docker exec client1 curl -s -o /dev/null http://10.10.20.20
  docker exec client2 curl -s -o /dev/null http://10.10.20.20
  sleep $((RANDOM % 3 + 1))
done

sleep 20
SUR=$(tail -n +$((LOGLINES+1)) logs/suricata/eve.json | grep -c '"event_type":"alert"')
PROM=$(curl -s "http://localhost:9090/api/v1/query?query=count(max_over_time(ALERTS%7Balertstate%3D%22firing%22%7D%5B${DURATION}s%5D))" | grep -o '"value":\[[^]]*\]' | grep -o '"[0-9]*"' | tail -1 | tr -d '"')
echo "E3 over ${DURATION}s: suricata_false_alerts=$SUR prometheus_false_alerts=${PROM:-0}" | tee -a results/e3_false_positives.txt
