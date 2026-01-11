#!/bin/bash
echo -e "\033[32m---> [3/4] 安装 Sing-box (直装版 + 本地生成 Clash 配置) \033[0m"

# 1. 架构判断
ARCH=$(uname -m)
case $ARCH in
    x86_64) B_ARCH="amd64" ;;
    aarch64) B_ARCH="arm64" ;;
    *) echo "不支持的架构: $ARCH"; exit 1 ;;
esac

# 2. 下载 Sing-box
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

# 5. 生成 Sing-box 配置 (VPS 端)
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

# --- 🔥 核心功能：直接生成 Clash YAML 🔥 ---

if systemctl is-active --quiet sing-box; then
    # 获取公网 IP
    PUBLIC_IP=$(curl -s --max-time 5 https://api.ipify.org)
    [ -z "$PUBLIC_IP" ] && PUBLIC_IP=$(curl -s --max-time 5 https://ifconfig.me)

    echo -e "\n\033[33m=========================================================\033[0m"
    echo -e "\033[33m   🚀 部署成功！请手动复制下方配置 (100% 可用) \033[0m"
    echo -e "\033[33m=========================================================\033[0m"
    
    echo -e "\n\033[32m👇 方法：复制下方虚线中间的内容 -> 新建文件 gemini.yaml -> 拖入 Clash 👇\033[0m"
    echo -e "\033[36m------------------- 复制开始 (COPY START) -------------------\033[0m"
    
    # 直接打印标准 YAML 格式
    cat <<EOF
port: 7890
socks-port: 7891
allow-lan: false
mode: rule
log-level: info
external-controller: 127.0.0.1:9090

proxies:
  - name: "Gemini_Unlock"
    type: socks5
    server: ${PUBLIC_IP}
    port: 5555
    # 如果您的 VPS 有用户名密码，请在 Sing-box inbounds 里配置并在下面添加
    # username: "xxx"
    # password: "xxx"
    skip-cert-verify: true
    udp: true

proxy-groups:
  - name: "OpenAI/Gemini"
    type: select
    proxies:
      - "Gemini_Unlock"

rules:
  - DOMAIN-SUFFIX,google.com,OpenAI/Gemini
  - DOMAIN-SUFFIX,openai.com,OpenAI/Gemini
  - DOMAIN-SUFFIX,gemini.google.com,OpenAI/Gemini
  - DOMAIN-SUFFIX,bard.google.com,OpenAI/Gemini
  - DOMAIN-KEYWORD,openai,OpenAI/Gemini
  - DOMAIN-KEYWORD,google,OpenAI/Gemini
  - MATCH,DIRECT
EOF

    echo -e "\033[36m------------------- 复制结束 (COPY END) ---------------------\033[0m"
    echo -e "\n💡 \033[1;37m如果是 Clash Verge / Clash Nyanpasu:\033[0m"
    echo -e "   直接复制上面内容，在客户端选 '新建配置' -> '从剪贴板导入' 即可！"
else
    echo "❌ 启动失败，请检查日志。"
fi
