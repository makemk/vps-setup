#!/bin/bash
echo -e "\033[32m---> [3/4] 安装 Sing-box (直装版 + 打印原始 SOCKS5 链接) \033[0m"

# 1. 架构判断
ARCH=$(uname -m)
case $ARCH in
    x86_64) B_ARCH="amd64" ;;
    aarch64) B_ARCH="arm64" ;;
    *) echo "不支持的架构: $ARCH"; exit 1 ;;
esac

# 2. 下载 Sing-box (稳定版)
VERSION="1.10.7"
URL="https://github.com/SagerNet/sing-box/releases/download/v${VERSION}/sing-box-${VERSION}-linux-${B_ARCH}.tar.gz"
echo "正在下载 Sing-box v${VERSION}..."
wget -q -O sing-box.tar.gz "$URL" || { echo "下载失败"; exit 1; }

# 3. 安装
tar -zxvf sing-box.tar.gz > /dev/null
cp sing-box-${VERSION}-linux-${B_ARCH}/sing-box /usr/local/bin/sing-box
chmod +x /usr/local/bin/sing-box
rm -rf sing-box.tar.gz sing-box-${VERSION}-linux-${B_ARCH}

# 4. 注册服务
cat > /etc/systemd/system/sing-box.service <<EOF
[Unit]
Description=sing-box service
After=network.target nss-lookup.target
[Service]
ExecStart=/usr/local/bin/sing-box run -c /etc/sing-box/config.json
Restart=on-failure
[Install]
WantedBy=multi-user.target
EOF

# 5. 生成配置 (Mixed 端口 5555 -> WARP 40000)
mkdir -p /etc/sing-box
cat > /etc/sing-box/config.json <<EOF
{
  "log": {"level": "info", "timestamp": true},
  "inbounds": [{"type": "mixed","tag": "mixed-in","listen": "::","listen_port": 5555}],
  "outbounds": [
    {"type": "direct","tag": "direct"},
    {"type": "socks","tag": "warp-socks","server": "127.0.0.1","server_port": 40000}
  ],
  "route": {
    "rules": [{"geosite": ["gemini", "google", "openai"], "outbound": "warp-socks"}],
    "final": "direct",
    "auto_detect_interface": true
  }
}
EOF

# 6. 启动服务
systemctl daemon-reload
systemctl enable sing-box
systemctl restart sing-box

# --- 🔥 核心功能：打印原始链接供测试 🔥 ---

if systemctl is-active --quiet sing-box; then
    # 获取公网 IP
    PUBLIC_IP=$(curl -s --max-time 5 https://api.ipify.org)
    [ -z "$PUBLIC_IP" ] && PUBLIC_IP=$(curl -s --max-time 5 https://ifconfig.me)

    # 构造原始 SOCKS5 链接
    RAW_LINK="socks5://${PUBLIC_IP}:5555#Gemini_VPS"

    echo -e "\n\033[33m=========================================================\033[0m"
    echo -e "\033[33m   🔗 Sing-box 原始节点链接 \033[0m"
    echo -e "\033[33m=========================================================\033[0m"
    
    echo -e "\n\033[32m[1] 原始 SOCKS5 链接 (复制这个):\033[0m"
    echo -e "\033[4;34m${RAW_LINK}\033[0m"

    echo -e "\n\033[32m[2] 如何测试是否连通？\033[0m"
    echo -e "请在您本地电脑的终端 (cmd/powershell/terminal) 运行下面这行命令："
    echo -e "\033[36mcurl -v -x socks5://${PUBLIC_IP}:5555 https://www.google.com\033[0m"
    
    echo -e "\n\033[32m[3] 如果能看到 '200 OK' 或 HTML 代码，说明节点是通的！\033[0m"
    echo -e "确认通了之后，再去把上面的链接拿去转换，或者手动填入 Clash。"
    echo -e "\033[33m=========================================================\033[0m\n"

else
    echo "❌ 启动失败，请运行 systemctl status sing-box 查看原因。"
fi
