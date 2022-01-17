#!/bin/bash

PRI_IP=10.0.1.10
SEC_IP=10.0.1.20

sudo sysctl net.ipv4.ip_forward=1

# PRIMARY CONFIG
sudo ip link add vxlan0 type vxlan id 10 dev eth1 dstport 0
sudo bridge fdb append 00:00:00:00:00:00 dev vxlan0 dst $PRI_IP
sudo bridge fdb append 00:00:00:00:00:00 dev vxlan0 dst $SEC_IP

sudo ip addr add 192.168.0.4/24 dev vxlan0
sudo ip link set up dev vxlan0

ifconfig -a
