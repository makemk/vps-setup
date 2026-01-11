#!/bin/bash
echo -e "\033[32m---> [1/4] 系统初始化与 BBR v1 配置 \033[0m"

# 1. 更新源与安装工具
apt-get update -y
apt-get install -y nano curl wget ca-certificates

# 2. 开启 BBR v1 (最稳)
sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf

# 3. 开启 IP 转发 (Sing-box 必备)
sed -i '/net.ipv4.ip_forward/d' /etc/sysctl.conf
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
echo "net.ipv6.conf.all.forwarding=1" >> /etc/sysctl.conf

# 4. 生效
sysctl -p > /dev/null 2>&1
echo "系统环境准备完毕，BBR 已开启。"
