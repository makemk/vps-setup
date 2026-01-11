#!/bin/bash
echo -e "\033[32m---> [2/4] 安装 WARP SOCKS5 代理 \033[0m"

# 1. 自动安装 WARP (Wireproxy 模式)
# 自动输入 "40000" 作为端口，"w" 选项代表 Wireproxy
# 修改前 (旧的):
# echo "40000" | bash <(curl -fsSL https://gitlab.com/fscarmen/warp/-/raw/main/menu.sh) w

# 修改后 (新的): 注意加了 -e 和 1\n
echo -e "1\n40000" | bash <(curl -fsSL https://gitlab.com/fscarmen/warp/-/raw/main/menu.sh) w

# 2. 简单的健康检查
sleep 3
if netstat -nlp | grep -q 40000; then
    echo "WARP 代理已成功运行在 127.0.0.1:40000"
else
    echo "⚠️ 警告: 端口 40000 未检测到，请检查脚本输出。"
fi
