#!/bin/bash
echo -e "\033[32m---> [4/4] 配置防火墙 \033[0m"

# 放行 5555 端口 (Sing-box 入站)
iptables -I INPUT -p tcp --dport 5555 -j ACCEPT
iptables -I INPUT -p udp --dport 5555 -j ACCEPT

# 如果有 UFW，也放行一下
if command -v ufw > /dev/null; then
    ufw allow 5555/tcp > /dev/null 2>&1
    ufw allow 5555/udp > /dev/null 2>&1
fi

echo "防火墙端口 5555 已放行。"
