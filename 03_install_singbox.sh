#!/bin/bash
echo -e "\033[32m---> [3/4] 安装 Sing-box (二进制直装版 - 修复404) \033[0m"

# 1. 自动判断架构
ARCH=$(uname -m)
case $ARCH in
    x86_64) B_ARCH="amd64" ;;
    aarch64) B_ARCH="arm64" ;;
    *) echo "不支持的架构: $ARCH"; exit 1 ;;
esac

# 2. 从 GitHub Release 下载稳定版 (绝对不404)
VERSION="1.10.7"
URL="https://github.com/SagerNet/sing-box/releases/download/v${VERSION}/sing-box-${VERSION}-linux-${B_ARCH}.tar.gz"

echo "正在从 GitHub 下载 Sing-box v${VERSION}..."
wget -O sing-box.tar.gz "$URL"

# 3. 解压并安装
tar -zxvf sing-box.tar.gz
# 提取二进制文件
cp sing-box-${VERSION}-linux-${B_ARCH}/sing-box /usr/local/bin/sing-box
chmod +x /usr/local/bin/sing-box
rm -rf sing-box.tar.gz sing-box-${VERSION}-linux-${B_ARCH}

# 4. 写入系统服务 (Systemd)
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

# 6. 启动
systemctl daemon-reload
systemctl enable sing-box
systemctl restart sing-box

if systemctl is-active --quiet sing-box; then
    echo "✅ Sing-box 部署成功！"
else
    echo "❌ 启动失败，请检查日志。"
fi
