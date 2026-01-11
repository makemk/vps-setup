#!/bin/bash
echo -e "\033[32m---> [3/4] 安装 Sing-box (直装版 + 自动生成 Clash 订阅) \033[0m"

# 1. 自动判断架构
ARCH=$(uname -m)
case $ARCH in
    x86_64) B_ARCH="amd64" ;;
    aarch64) B_ARCH="arm64" ;;
    *) echo "不支持的架构: $ARCH"; exit 1 ;;
esac

# 2. 从 GitHub Release 下载稳定版
VERSION="1.10.7"
URL="https://github.com/SagerNet/sing-box/releases/download/v${VERSION}/sing-box-${VERSION}-linux-${B_ARCH}.tar.gz"

echo "正在从 GitHub 下载 Sing-box v${VERSION}..."
wget -O sing-box.tar.gz "$URL"

# 3. 解压并安装
tar -zxvf sing-box.tar.gz
cp sing-box-${VERSION}-linux-${B_ARCH}/sing-box /usr/local/bin/sing-box
chmod +x /usr/local/bin/sing-box
rm -rf sing-box.tar.gz sing-box-${VERSION}-linux-${B_ARCH}

# 4. 写入系统服务
cat > /etc/systemd/system/sing-box.service <<EOF
[Unit]
Description=sing-box service
Documentation=https://sing-box.sagernet.org
After=network.target nss-lookup.target

[Service]
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
ExecStart=/usr/local/bin/sing-box run -c /etc/sing-box/config.json
Restart=on-failure
RestartSec=10s
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOF

# 5. 生成配置文件 (Gemini 分流)
mkdir -p /etc/sing-box
cat > /etc/sing-box/config.json <<EOF
{
  "log": {
    "level": "info",
    "timestamp": true
  },
  "inbounds": [
    {
      "type": "mixed",
      "tag": "mixed-in",
      "listen": "::",
      "listen_port": 5555
    }
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    },
    {
      "type": "socks",
      "tag": "warp-socks",
      "server": "127.0.0.1",
      "server_port": 40000
    }
  ],
  "route": {
    "rules": [
      {
        "geosite": ["gemini", "google", "openai"], 
        "outbound": "warp-socks"
      }
    ],
    "final": "direct",
    "auto_detect_interface": true
  }
}
EOF

# 6. 启动服务
systemctl daemon-reload
systemctl enable sing-box
systemctl restart sing-box

# --- 🔥 新增功能：自动生成订阅链接 🔥 ---

if systemctl is-active --quiet sing-box; then
    echo -e "\n✅ Sing-box 部署成功！正在计算订阅链接..."
    
    # 获取公网 IP
    PUBLIC_IP=$(curl -s --max-time 5 https://api.ipify.org)
    [ -z "$PUBLIC_IP" ] && PUBLIC_IP=$(curl -s --max-time 5 https://ifconfig.me)

    # 构造节点名称和 SOCKS5 原生链接
    NODE_NAME="Gemini_VPS"
    # 格式: socks5://IP:5555#名字
    RAW_LINK="socks5://${PUBLIC_IP}:5555#${NODE_NAME}"
    
    # 进行简单的 URL 编码 (为了传给 API)
    # 将 : / # 替换为 %xx
    ENCODED_LINK=$(echo "$RAW_LINK" | sed 's/:/%3A/g; s/\//%2F/g; s/#/%23/g')

    # 构造 eooce 转换链接 (target=clash)
    # 注意: 这里利用了 subconverter 支持 raw link 的特性
    CLASH_SUB_URL="https://sublink.eooce.com/sub?target=clash&url=${ENCODED_LINK}&insert=false&config=https%3A%2F%2Fraw.githubusercontent.com%2FACL4SSR%2FACL4SSR%2Fmaster%2FClash%2Fconfig%2FACL4SSR_Online_Full.ini&emoji=true&list=false&tfo=false&scv=false&fdn=false&sort=false"

    echo -e "\n\033[33m=========================================================\033[0m"
    echo -e "\033[33m   🚀 您的专属 Clash 订阅链接 (Generated for Xingcheng) \033[0m"
    echo -e "\033[33m=========================================================\033[0m"
    echo -e "\n\033[32m[方式 1] Clash 订阅链接 (直接复制到 Clash -> 导入 URL):\033[0m"
    echo -e "\033[4;34m${CLASH_SUB_URL}\033[0m"
    echo -e "\n---------------------------------------------------------"
    echo -e "\033[32m[方式 2] 原始 SOCKS5 节点 (Clash Verge -> 导入粘贴板):\033[0m"
    echo -e "${RAW_LINK}"
    echo -e "\033[33m=========================================================\033[0m\n"

else
    echo "❌ 启动失败，请检查日志。"
fi
