#!/bin/bash

# =========================================================
# ⚠️ 请修改下面这行，换成您自己的 GitHub 用户名和仓库名 ⚠️
# 例如: REPO_URL="https://raw.githubusercontent.com/XingchengWang/vps-setup/main"
#REPO_URL="https://raw.githubusercontent.com/您的用户名/您的仓库名/main"
REPO_URL="https://raw.githubusercontent.com/makemk/vps-setup/main"
# =========================================================

# 颜色定义
GREEN="\033[32m"
RESET="\033[0m"

echo -e "${GREEN}>>> 开始一键部署流程...${RESET}"

# 定义要执行的文件列表
FILES=(
    "01_base_bbr.sh"
    "02_install_warp.sh"
    "03_install_singbox.sh"
    "04_firewall.sh"
)

# 确保基础工具存在
apt-get update -y >/dev/null 2>&1
apt-get install -y curl wget >/dev/null 2>&1

# 循环下载并执行
for file in "${FILES[@]}"; do
    echo -e "${GREEN}>>> 正在下载并执行模块: $file ...${RESET}"
    
    # 下载脚本
    wget -q -O "$file" "$REPO_URL/$file"
    
    # 检查下载是否成功
    if [ ! -s "$file" ]; then
        echo "❌ 错误: 无法下载 $file，请检查 GitHub 仓库地址是否正确。"
        exit 1
    fi

    # 赋予权限并执行
    chmod +x "$file"
    ./"$file"
    
    # 执行完删除脚本，保持系统干净 (可选)
    rm -f "$file"
    
    echo -e "${GREEN}>>> $file 执行完毕。${RESET}\n"
    sleep 2
done

echo -e "${GREEN}🎉 所有部署任务已完成！${RESET}"
