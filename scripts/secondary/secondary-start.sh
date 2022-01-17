#!/bin/bash

sudo ip link add vxlan0 type vxlan id 10 dev eth1 dstport 0
sudo bridge fdb append 00:00:00:00:00:00 dev vxlan0 dst 10.0.1.4
sudo bridge fdb append 00:00:00:00:00:00 dev vxlan0 dst 10.0.1.10

sudo ip addr add 192.168.0.20/24 dev vxlan0
sudo ip link set up dev vxlan0

ifconfig -a
