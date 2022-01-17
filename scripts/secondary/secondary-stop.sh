#!/bin/bash

sudo ip link delete vxlan0
sudo ifconfig down vxlan0

ifconfig -a
