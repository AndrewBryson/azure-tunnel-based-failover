#!/bin/bash

VIP=192.168.0.200

sudo ip link add name vip type dummy
sudo ifconfig vip $VIP netmask 255.255.255.0 up

echo "$(date --iso-8601=ns) + Starting arping"
sudo arping -U -c 3 -I vxlan0 -s $VIP $VIP
echo "$(date --iso-8601=ns) + Done"
