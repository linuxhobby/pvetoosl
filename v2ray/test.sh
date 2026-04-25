#!/bin/bash

# ====================================================
# 将军自持版 V5.0 - 参照 233boy 逻辑重构 (最终版)
# 适配系统：Debian 12, Debian 13
# 特性：官方核心、本地逻辑、高精度链接拼接、零第三方依赖
# ====================================================

CONFIG_DIR="/etc/v2ray"
CONFIG_FILE="$CONFIG_DIR/config.json"

# --- 核心部署：直接对接官方源 ---
install_v2ray() {
    if ! command -v v2ray &> /dev/null; then
        echo "正在从 V2fly 官方源部署核心组件..."
        # 确保目录存在
        mkdir -p $CONFIG_DIR
        # 安装基础依赖
        apt update && apt install -y curl jq gawk grep coreutils python3
        # 调用官方安装脚本
        bash <(curl -L https://raw.githubusercontent.com/v2fly/fuc-v2ray/master/install-release.sh)
    fi
}

# --- 写入本地生成的纯净配置 ---
write_config() {
    local PROTO=$1
    local UUID=$2
    local PATH_STR=$3

    cat > $CONFIG_FILE <<EOF
{
  "log": { "loglevel": "warning" },
  "inbounds": [{
    "port": 12345,
    "listen": "127.0.0.1",
    "protocol": "$PROTO",
    "settings": {
      "clients": [ { "id": "$UUID", "level": 0 } ],
      "decryption": "none"
    },
    "streamSettings": {
      "network": "ws",
      "wsSettings": { "path": "$PATH_STR" }
    }
  }],
  "outbounds": [
    { "protocol": "freedom", "settings": {} }
  ]
}
EOF
    systemctl restart v2ray
}

# --- 链接拼接逻辑 (完全本地化计算) ---
generate_links() {
    if [ ! -f "$CONFIG_FILE" ]; then 
        echo "尚未检测到配置，请先安装协议。"
        return 
    fi
    
    local ADDR=$(hostname -f)
    echo "-----------------------------------------------"
    read -p "当前识别域名为 [$ADDR]，若需修改请输入，否则直接回车: " INPUT_ADDR
    [ ! -z "$INPUT_ADDR" ] && ADDR=$INPUT_ADDR
    
    local PROTO=$(jq -r '.inbounds[0].protocol' $CONFIG_FILE)
    local ID=$(jq -r '.inbounds[0].settings.clients[0].id' $CONFIG_FILE)
    local PR=$(jq -r '.inbounds[0].streamSettings.wsSettings.path' $CONFIG_FILE)
    
    # 使用 Python3 进行高精度 URL 编码
    local P_ENC=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$PR', safe=''))")

    echo "==============================================="
    if [ "$PROTO" == "vless" ]; then
        echo "VLESS 分享链接:"
        echo "vless://${ID}@${ADDR}:443?encryption=none&security=tls&type=ws&host=${ADDR}&path=${P_ENC}#General_V5"
    else
        local VM_J="{\"v\":\"2\",\"ps\":\"General_V5\",\"add\":\"${ADDR}\",\"port\":\"443\",\"id\":\"${ID}\",\"aid\":\"0\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"${ADDR}\",\"path\":\"${PR}\",\"tls\":\"tls\"}"
        echo "VMess 分享链接:"
        echo "vmess://$(echo -n "$VM_J" | base64 -w 0)"
    fi
    echo "==============================================="
}

# --- 菜单循环逻辑 ---
while true; do
    echo ""
    echo "==============================================="
    echo "      V2Ray 战略指挥面板 V5.0 (Debian 12/13)   "
    echo "==============================================="
    echo " 1) 部署 VLESS-WS-TLS (官方核心)"
    echo " 2) 部署 VMess-WS-TLS (官方核心)"
    echo " 3) 查看当前配置与分享链接"
    echo " 4) 彻底退出脚本"
    echo "-----------------------------------------------"
    read -p "请将军选择指令 [1-4]: " opt

    case $opt in
        1)
            install_v2ray
            UUID=$(cat /proc/sys/kernel/random/uuid)
            WPATH="/ray$(cat /proc/sys/kernel/random/uuid | cut -c1-4)"
            write_config "vless" "$UUID" "$WPATH"
            generate_links
            read -p "按回车继续..."
            ;;
        2)
            install_v2ray
            UUID=$(cat /proc/sys/kernel/random/uuid)
            WPATH="/ray$(cat /proc/sys/kernel/random/uuid | cut -c1-4)"
            write_config "vmess" "$UUID" "$WPATH"
            generate_links
            read -p "按回车继续..."
            ;;
        3)
            generate_links
            read -p "按回车继续..."
            ;;
        4)
            echo "退出面板..."
            exit 0
            ;;
        *)
            echo "指令无效，请重新输入"
            sleep 1
            ;;
    esac
done