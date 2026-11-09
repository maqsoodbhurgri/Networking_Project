#!/bin/bash
cd ~/Networking_Project
docker compose up -d router
sleep 3
IFACE=$(docker exec router sh -c "ip -o -4 addr show | grep '10.10.30.1/' | awk '{print \$2}'" | cut -d@ -f1)
echo "UNTRUSTED_IF=$IFACE" > .env
sed -i -E "s/device=\"eth[0-9]+\"/device=\"$IFACE\"/g" monitoring/prometheus/rules/lab.yml
docker compose up -d --force-recreate suricata prometheus
docker compose up -d
docker exec -d web iperf3 -s
echo "Untrusted interface: $IFACE"
