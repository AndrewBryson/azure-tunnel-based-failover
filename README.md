# Purpose

This is a trial of networking encapsulation ([VXLAN](https://en.wikipedia.org/wiki/Virtual_Extensible_LAN), [GENEVE](https://en.wikipedia.org/wiki/Generic_Network_Virtualization_Encapsulation))  in Azure to solve the problem of achieving fast failover (~20ms) of a HA pair of servers running in an active/passive configuration.  The failover uses gratuitous ARP to move a VIP across the instances, therefore requiring control of MAC addresses (layer 2), a capability not available in Azure/public cloud networks.  This repository uses a simple HTTP client & server with a VIP to simulate a real workload.

A range of other failover options are available, see [Deploy highly available NVAs](https://docs.microsoft.com/en-us/azure/architecture/reference-architectures/dmz/nva-ha#ha-architectures-overview) specifically:
1. [Azure Load Balancer](https://docs.microsoft.com/en-us/azure/architecture/reference-architectures/dmz/nva-ha#load-balancer-design)
1. [Azure Route Server](https://docs.microsoft.com/en-us/azure/architecture/reference-architectures/dmz/nva-ha#azure-route-server)
1. [Gateway Load Balancer](https://docs.microsoft.com/en-us/azure/architecture/reference-architectures/dmz/nva-ha#gateway-load-balancer)
1. [Changing PIP-UDR](https://docs.microsoft.com/en-us/azure/architecture/reference-architectures/dmz/nva-ha#changing-pip-udr)

These options do not meet a fast failover requirement of <100ms.

## Solution Overview
![Overview diagram](/images/azure-tunnel-based-failover.png)

# Timings
These timings have been gathered crudely using aligned timestamps across VMs, nothing fancier than that!  Snippets of the terminal output have been shared for one attempt in each scenario, and other 3 timings given separately.

### Scenario 1 - primary to secondary failover

Failover time: near instant <100ms easily  
Start time: `2022-01-17T11:20:16,518584729`  
End (next request): `2022-01-17T11:20:16,613700879+00:00`  

Client
```
2022-01-17T11:20:16,386997761+00:00 + PRI
2022-01-17T11:20:16,500411321+00:00 + PRI
2022-01-17T11:20:16,613700879+00:00 + SEC
2022-01-17T11:20:16,727426945+00:00 + SEC
```

Note that client requests are every 100ms.

Secondary (passive becoming active)
```
$ ./vip-failover.sh
2022-01-17T11:20:16,518584729+00:00 + Starting arping
ARPING 192.168.0.200 from 192.168.0.200 vxlan0
Sent 3 probes (3 broadcast(s))
Received 0 response(s)
2022-01-17T11:20:19,537214485+00:00 + Done
```

### Scenario 2 - secondary to primary recovery
Failover time: near instant <100ms easily  
Start: `2022-01-17T11:27:44,937742057`  
End (next request): `2022-01-17T11:27:45,045511629`  

Client
```
2022-01-17T11:27:44,819385401+00:00 + SEC
2022-01-17T11:27:44,932504766+00:00 + SEC
2022-01-17T11:27:45,045511629+00:00 + PRI
2022-01-17T11:27:45,158505392+00:00 + PRI
```

Primary
```
$ ./vip-failover.sh
2022-01-17T11:27:44,937742057+00:00 + Starting arping
ARPING 192.168.0.200 from 192.168.0.200 vxlan0
Sent 3 probes (3 broadcast(s))
Received 0 response(s)
2022-01-17T11:27:47,962594047+00:00 + Done
```

# Performance Testing

## Latency
Native Azure (`10.0.1.20`) vs VXLAN interface (`192.168.0.200`)
```
$ ping -c 10 10.0.1.20
PING 10.0.1.20 (10.0.1.20) 56(84) bytes of data.
64 bytes from 10.0.1.20: icmp_seq=1 ttl=64 time=1.06 ms
... snip ...
64 bytes from 10.0.1.20: icmp_seq=10 ttl=64 time=1.26 ms

--- 10.0.1.20 ping statistics ---
10 packets transmitted, 10 received, 0% packet loss, time 9013ms
rtt min/avg/max/mdev = 1.058/1.309/1.975/0.275 ms

$ ping -c 10 192.168.0.200
PING 192.168.0.200 (192.168.0.200) 56(84) bytes of data.
64 bytes from 192.168.0.200: icmp_seq=1 ttl=64 time=1.11 ms
... snip ...
64 bytes from 192.168.0.200: icmp_seq=10 ttl=64 time=1.12 ms

--- 192.168.0.200 ping statistics ---
10 packets transmitted, 10 received, 0% packet loss, time 9041ms
rtt min/avg/max/mdev = 0.782/1.164/1.866/0.325 ms
```

## Bandwidth
- Use iPerf
- `sudo apt install iperf`
- Server: `iperf --server --bind <interface ip>`
- Client: `iperf --client <iperf server ip>`
- VMs are [D2s_v3](https://docs.microsoft.com/en-us/azure/virtual-machines/dv3-dsv3-series): Max NIC bandwidth = 1000Mbit

### Results - Native Azure
```
$ iperf --client 10.0.1.20
------------------------------------------------------------
Client connecting to 10.0.1.20, TCP port 5001
TCP window size:  230 KByte (default)
------------------------------------------------------------
[  3] local 10.0.1.4 port 33898 connected with 10.0.1.20 port 5001
[ ID] Interval       Transfer     Bandwidth
[  3]  0.0-10.0 sec  1.08 GBytes   927 Mbits/sec
```

```
$ iperf --server --bind 10.0.1.20
------------------------------------------------------------
Server listening on TCP port 5001
Binding to local address 10.0.1.20
TCP window size:  128 KByte (default)
------------------------------------------------------------
[  4] local 10.0.1.20 port 5001 connected with 10.0.1.4 port 33898
[ ID] Interval       Transfer     Bandwidth
[  4]  0.0-10.0 sec  1.08 GBytes   925 Mbits/sec
```

### Results - VXLAN
```
$ iperf --client 192.168.0.200
------------------------------------------------------------
Client connecting to 192.168.0.200, TCP port 5001
TCP window size:  298 KByte (default)
------------------------------------------------------------
[  3] local 192.168.0.4 port 34582 connected with 192.168.0.200 port 5001
[ ID] Interval       Transfer     Bandwidth
[  3]  0.0-10.0 sec  1.05 GBytes   898 Mbits/sec
```
```
$ iperf --server --bind 192.168.0.200
------------------------------------------------------------
Server listening on TCP port 5001
Binding to local address 192.168.0.200
TCP window size:  128 KByte (default)
------------------------------------------------------------
[  4] local 192.168.0.200 port 5001 connected with 192.168.0.4 port 34582
[ ID] Interval       Transfer     Bandwidth
[  4]  0.0-10.0 sec  1.05 GBytes   895 Mbits/sec
```

### VM Size Performance Summary
| VM type/Size | VXLAN bandwidth | Max NIC bandwidth |
|--------------|-----------|-----------|
| D2s_v3 | 898 Mbits/sec | 1000 Mbit |
| D4s_v3 | 1.78 Gbits/sec | 2000 Mbit |
| D8s_v3 | 3.69 Gbits/sec | 4000 Mbit |
| D16s_v3 | 7.36 Gbits/sec | 8000 Mbit |
| D32s_v3 - 1 iPerf thread | 9.46 Gbits/sec | 16000 Mbit |
| D32s_v3 - 2 iPerf threads | 14.7 Gbits/sec | 16000 Mbit |

- All NICs have accelerated networking enabled.  
- Bandwidth scaling looks linear with vCPU as expected, until 32 vCPUs...
- No tuning has taking place at all.
- OS is `Ubuntu 20_04-lts-gen2`

### 32 vCPUs and iPerf Client Threads
- 1 client thread - 9.17Gbits/sec:
```
$ iperf --client 192.168.0.200 --parallel 1 --time 60
------------------------------------------------------------
Client connecting to 192.168.0.200, TCP port 5001
TCP window size: 1020 KByte (default)
------------------------------------------------------------
[  3] local 192.168.0.4 port 53928 connected with 192.168.0.200 port 5001
[ ID] Interval       Transfer     Bandwidth
[  3]  0.0-60.0 sec  64.0 GBytes  9.17 Gbits/sec
```
- 2 client threads - 14.5Gbit/sec:
```
$ iperf --client 192.168.0.200 --parallel 2 --time 60
------------------------------------------------------------
Client connecting to 192.168.0.200, TCP port 5001
TCP window size: 1.10 MByte (default)
------------------------------------------------------------
[  3] local 192.168.0.4 port 54380 connected with 192.168.0.200 port 5001
[  4] local 192.168.0.4 port 54382 connected with 192.168.0.200 port 5001
[ ID] Interval       Transfer     Bandwidth
[  3]  0.0-60.0 sec  47.2 GBytes  6.76 Gbits/sec
[  4]  0.0-60.0 sec  54.2 GBytes  7.76 Gbits/sec
[SUM]  0.0-60.0 sec   101 GBytes  14.5 Gbits/sec
```

# Configuration

## Web app creation
1. On the primary and secondary VMs, review the script: [server-setup.sh](/scripts/server-setup.sh).  This installs the dependencies `node` and `exabgp` and configures the VIP with `ifconfig`.
1. Run the script.
1. Launch the web server, e.g.
    1. Primary server: `ID=PRI node ./web/server.js &`
    2. Secondary server: `ID=SEC node ./web/server.js &`

## Verify
Normal state of [http-ping.sh](/scripts/http-ping.sh) will see a response like:
```
...
2021-11-22T14:51:42,102116071+00:00 + PRI
2021-11-22T14:51:42,214647212+00:00 + PRI
...
```
Showing responses coming from the primary VM.

Now trigger a failover using the `vip-failover.sh` on the secondary VM and the `http-ping.sh` output will change:
```
...
2022-01-17T11:20:16,500411321+00:00 + PRI
2022-01-17T11:20:16,613700879+00:00 + SEC // failed over ???
...
```

# Links

## VXLAN
- https://gist.github.com/squat/1c2799c3565c383fe4b1499c101bfc49 - this got me setup and working
- https://vincent.bernat.ch/en/blog/2017-vxlan-linux - while IPv6 focused, it shows better usage of `bridge fdb` to support >2 nodes in the VXLAN through use of `bridge fdb append`
- https://ilearnedhowto.wordpress.com/2017/02/16/how-to-create-overlay-networks-using-linux-bridges-and-vxlans/ - not tried this
 
## GENEVE
- https://medium.com/@veronica2831986/how-to-setup-geneve-tunnels-with-linux-bridge-f4b7c8216115 - worked through this, but the end result didn't work.  Might be an ARP and MAC issue specific to Azure, MAC address needs added to geneve0?
- https://darjchen.medium.com/setting-up-geneve-tunnel-with-linux-tc-571f891618a9

## ARP
- https://serverfault.com/questions/175803/how-to-broadcast-arp-update-to-all-neighbors-in-linux
- `sudo apt install iputils-arping`