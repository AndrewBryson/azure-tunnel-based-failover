#!/bin/bash

VIP=192.168.0.200

URL=http://$VIP:3000

while :; do 
    echo \
    $(date --iso-8601=ns) + $(curl --connect-timeout 1 --silent --no-keepalive -H 'Connection: close' $URL);
    sleep 0.1s;
done