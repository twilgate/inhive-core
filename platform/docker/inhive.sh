#!/bin/sh
# sysctl -w net.ipv4.ip_forward=1
# sysctl -w net.ipv6.ip_forward=1

# ip rule add fwmark 1 table 100 ; 
# ip route add local 0.0.0.0/0 dev lo table 100 

# # CREATE TABLE
# iptables -t mangle -N inhive

# # RETURN LOCAL AND LANS
# iptables -t mangle -A OUTPUT -j RETURN
# iptables -t nat -A inhive --dport 2334 -j RETURN

# iptables -t mangle -A inhive -d 10.0.0.0/8 -j RETURN
# iptables -t mangle -A inhive -d 127.0.0.0/8 -j RETURN
# iptables -t mangle -A inhive -d 169.254.0.0/16 -j RETURN
# iptables -t mangle -A inhive -d 172.16.0.0/12 -j RETURN
# iptables -t mangle -A inhive -d 192.168.50.0/16 -j RETURN
# iptables -t mangle -A inhive -d 192.168.9.0/16 -j RETURN
# iptables -t mangle -A inhive -d 224.0.0.0/4 -j RETURN
# iptables -t mangle -A inhive -d 240.0.0.0/4 -j RETURN

# iptables -t mangle -A inhive -p udp -j TPROXY --on-port 2334 --tproxy-mark 1
# iptables -t mangle -A inhive -p tcp -j TPROXY --on-port 2334 --tproxy-mark 1

# # HIJACK ICMP (untested)
# # iptables -t mangle -A inhive -p icmp -j DNAT --to-destination 127.0.0.1

# # REDIRECT
# iptables -t mangle -A PREROUTING -j inhive


if [ -f "/inhive/inhive.json" ]; then
    /inhive/InhiveCli run --config "$CONFIG" -d /inhive/inhive.json
else
    /inhive/InhiveCli run --config "$CONFIG"
fi


