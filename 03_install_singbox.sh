#!/bin/bash
echo -e "\033[32m---> [3/4] 安装 Sing-box (官方 APT 方式) 并配置分流 \033[0m"

# --- 1. 使用官方 APT 源安装 Sing-box (修复 404 问题) ---
# 添加 GPG 密钥
mkdir -p /etc/apt/keyrings
curl -fsSL https://sing-box.app/gpg.key -o /etc/apt/keyrings/sagernet.asc
chmod a+r /etc/apt/keyrings/sagernet.asc

# 添加官方软件源
echo "deb [arch=`dpkg --print-architecture` signed-by=/etc/apt/keyrings/sagernet.asc] https://deb.sagernet.org/ * *" | tee /etc/apt/sources.list.d/sagernet.list > /dev/null

# 更新并安装
apt-get update
apt-get install -y sing-box

# 确保配置目录存在
mkdir -p /etc/sing-box

# --- 2. 生成配置文件 (Gemini 分流 + Mixed 端口 5555) ---
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

# --- 3. 重启生效 ---
systemctl enable sing-box
systemctl restart sing-box

# --- 4. 验证安装 ---
if systemctl is-active --quiet sing-box; then
    echo "✅ Sing-box 启动成功！Gemini -> WARP 分流已生效。"
else
    echo "❌ Sing-box 启动失败，请运行 systemctl status sing-box 查看原因。"
fi
