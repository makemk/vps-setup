# 🚀 VPS Environment Auto-Setup (Gemini/ChatGPT Unlock)

这是一个用于快速部署 VPS 环境的自动化脚本集合。
专为解决 **Google Gemini / OpenAI 访问受限** 问题设计，采用 **WARP SOCKS5 分流** 方案，不影响 VPS 原生网络速度。

## ✨ 主要功能 (Features)

该脚本会自动按顺序执行以下模块：

1.  **系统初始化**: 更新软件源，安装常用工具 (curl, wget, nano)，开启 **BBR v1** 加速。
2.  **WARP 代理**: 安装 Cloudflare WARP (Wireproxy 模式)，在本地 `127.0.0.1:40000` 开启 SOCKS5 代理。
3.  **Sing-box**: 安装官方 Sing-box，并自动配置路由规则 —— **Gemini/Google/OpenAI 走 WARP，其他流量直连**。
4.  **防火墙配置**: 自动放行必要的业务端口 (如 5555)。

## 🛠️ 一键安装命令 (Installation)

**请使用 Root 用户在 VPS 终端执行以下命令：**

```bash
bash <(curl -fsSL [https://raw.githubusercontent.com/makemk/vps-setup/main/install.sh]
