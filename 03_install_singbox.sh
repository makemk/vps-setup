#!/bin/bash
echo -e "\033[32m---> [3/4] 安装 Sing-box (含 HTTP 订阅生成服务) \033[0m"

# --- 1. 架构判断 & 下载 Sing-box ---
ARCH=$(uname -m)
case $ARCH in
    x86_64) B_ARCH="amd64" ;;
    aarch64) B_ARCH="arm64" ;;
    *) echo "不支持的架构: $ARCH"; exit 1 ;;
esac

VERSION="1.10.7"
URL="https://github.com/SagerNet/sing-box/releases/download/v${VERSION}/sing-box-${VERSION}-linux-${B_ARCH}.tar.gz"

echo "正在下载 Sing-box v${VERSION}..."
wget -q -O sing-box.tar.gz "$URL" || { echo "下载失败"; exit 1; }

tar -zxvf sing-box.tar.gz > /dev/null
cp sing-box-${VERSION}-linux-${B_ARCH}/sing-box /usr/local/bin/sing-box
chmod +x /usr/local/bin/sing-box
rm -rf sing-box.tar.gz sing-box-${VERSION}-linux-${B_ARCH}

# --- 2. 配置 Sing-box 服务 ---
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

# --- 3. 配置 Sing-box 路由 (Gemini 分流) ---
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

# --- 4. 启动 Sing-box ---
systemctl daemon-reload
systemctl enable sing-box
systemctl restart sing-box

# =========================================================
# 🔥 核心功能：搭建 HTTP 订阅服务器 🔥
# =========================================================

if systemctl is-active --quiet sing-box; then
    echo -e "\n✅ Sing-box 启动成功！正在构建 Web 订阅..."

    # 1. 获取 IP
    PUBLIC_IP=$(curl -s --max-time 5 https://api.ipify.org)
    [ -z "$PUBLIC_IP" ] && PUBLIC_IP=$(curl -s --max-time 5 https://ifconfig.me)

    # 2. 生成随机文件名 (模仿您给的例子 1yqRrFJ...)
    # 生成 16 位随机字符，防止被别人扫描到
    SUB_PATH=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 16)
    WEB_ROOT="/var/www/sub"
    mkdir -p "$WEB_ROOT"

    # 3. 生成节点内容 (Base64 编码)
    # 格式: socks5://IP:5555#Gemini_VPS
    RAW_LINK="socks5://${PUBLIC_IP}:5555#Gemini_Unlock"
    # 写入文件
    echo -n "$RAW_LINK" | base64 -w 0 > "$WEB_ROOT/$SUB_PATH"

    # 4. 创建 HTTP 服务 (使用 Python3)
    # 监听 8080 端口，只服务 /var/www/sub 目录
    cat > /etc/systemd/system/http-sub.service <<EOF
[Unit]
Description=Simple HTTP Subscription Server
After=network.target

[Service]
ExecStart=/usr/bin/python3 -m http.server 8080 --directory $WEB_ROOT
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

    # 5. 启动 HTTP 服务
    systemctl enable http-sub
    systemctl restart http-sub

    # 6. 临时放行 8080 端口 (确保能访问)
    iptables -I INPUT -p tcp --dport 8080 -j ACCEPT
    
    # --- 输出最终链接 ---
    SUB_URL="http://${PUBLIC_IP}:8080/${SUB_PATH}"

    echo -e "\n\033[33m=========================================================\033[0m"
    echo -e "\033[33m   🎉 您的专属订阅链接 (Web Direct Link) \033[0m"
    echo -e "\033[33m=========================================================\033[0m"
    
    echo -e "\n\033[32m[可以直接浏览器访问，或填入转换器]:\033[0m"
    echo -e "\033[4;34m${SUB_URL}\033[0m"
    
    echo -e "\n\033[36m提示：这是一个标准的 Base64 订阅文件。\033[0m"
    echo -e "\033[36m您可以将此链接放入 'Clash 订阅转换' 网站，即可生成订阅！\033[0m"
    echo -e "\033[33m=========================================================\033[0m\n"

else
    echo "❌ Sing-box 启动失败，无法生成订阅。"
fi
