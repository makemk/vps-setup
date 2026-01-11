#!/bin/bash
echo -e "\033[32m---> [3/4] 安装 Sing-box (Base64 修复版) \033[0m"

# 1. 架构判断
ARCH=$(uname -m)
case $ARCH in
    x86_64) B_ARCH="amd64" ;;
    aarch64) B_ARCH="arm64" ;;
    *) echo "不支持的架构: $ARCH"; exit 1 ;;
esac

# 2. 下载
VERSION="1.10.7"
URL="https://github.com/SagerNet/sing-box/releases/download/v${VERSION}/sing-box-${VERSION}-linux-${B_ARCH}.tar.gz"
echo "正在下载 Sing-box v${VERSION}..."
wget -q -O sing-box.tar.gz "$URL" || { echo "下载失败"; exit 1; }

# 3. 安装
tar -zxvf sing-box.tar.gz > /dev/null
cp sing-box-${VERSION}-linux-${B_ARCH}/sing-box /usr/local/bin/sing-box
chmod +x /usr/local/bin/sing-box
rm -rf sing-box.tar.gz sing-box-${VERSION}-linux-${B_ARCH}

# 4. 服务文件
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

# 5. 配置文件 (Gemini 分流)
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

# 6. 启动
systemctl daemon-reload
systemctl enable sing-box
systemctl restart sing-box

# --- 🔥 核心修复：Base64 订阅生成逻辑 🔥 ---

if systemctl is-active --quiet sing-box; then
    echo -e "\n✅ 部署成功！正在生成订阅..."
    
    # 1. 获取公网 IP
    PUBLIC_IP=$(curl -s --max-time 5 https://api.ipify.org)
    [ -z "$PUBLIC_IP" ] && PUBLIC_IP=$(curl -s --max-time 5 https://ifconfig.me)

    # 2. 构造原始 SOCKS5 链接
    # 格式: socks5://IP:5555#名字
    NODE_NAME="Gemini_VPS"
    RAW_LINK="socks5://${PUBLIC_IP}:5555#${NODE_NAME}"
    
    # 3. 进行 Base64 编码 (解决特殊字符导致 API 识别失败的问题)
    # -w 0 防止换行
    B64_LINK=$(echo -n "$RAW_LINK" | base64 -w 0)

    # 4. 对 Base64 字符串再进行 URL 编码 (处理 + / = 符号)
    # 使用 python3 确保万无一失，如果没 python 用 sed 兜底
    if command -v python3 >/dev/null 2>&1; then
        ENCODED_B64=$(echo -n "$B64_LINK" | python3 -c "import sys, urllib.parse; print(urllib.parse.quote(sys.stdin.read()))")
    else
        ENCODED_B64=$(echo -n "$B64_LINK" | sed 's/+/%2B/g;s/\//%2F/g;s/=/%3D/g')
    fi

    # 5. 构造转换链接
    CLASH_SUB_URL="https://sublink.eooce.com/sub?target=clash&url=${ENCODED_B64}&insert=false&emoji=true&list=false&tfo=false&scv=false&fdn=false&sort=false"

    echo -e "\n\033[33m=========================================================\033[0m"
    echo -e "\033[33m   🚀 您的 Clash 配置 (修复版) \033[0m"
    echo -e "\033[33m=========================================================\033[0m"
    echo -e "\n\033[32m[方案 A] 自动订阅链接 (推荐):\033[0m"
    echo -e "请复制下方链接 -> Clash -> 配置 -> 从 URL 下载"
    echo -e "\033[4;34m${CLASH_SUB_URL}\033[0m"
    
    echo -e "\n---------------------------------------------------------"
    echo -e "\033[32m[方案 B] 手动配置 (如果方案A失败，请复制下方内容到 config.yaml):\033[0m"
    echo -e "proxies:"
    echo -e "  - name: ${NODE_NAME}"
    echo -e "    type: socks5"
    echo -e "    server: ${PUBLIC_IP}"
    echo -e "    port: 5555"
    echo -e "    skip-cert-verify: true"
    echo -e "    udp: true"
    echo -e "\033[33m=========================================================\033[0m\n"

else
    echo "❌ 启动失败，请检查日志。"
fi
