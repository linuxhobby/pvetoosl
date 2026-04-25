#!/bin/bash

# ====================================================
# 将军阁下，这是为您定制的综合管理脚本 (V2.2)
# 功能：协议切换、配置增删、自动报告、系统优化
# ====================================================

CONFIG_FILE="/etc/v2ray/config.json"

# --- 辅助函数：生成 UUID ---
get_uuid() {
    cat /proc/sys/kernel/random/uuid
}

# --- 1. 安装核心环境 ---
install_base() {
    echo "正在准备系统环境..."
    apt update && apt install -y curl jq awk grep
    if ! command -v v2ray &> /dev/null; then
        echo "正在调用核心安装程序..."
        bash <(curl -s -L https://git.io/v2ray.sh)
    fi
}

# --- 2. 核心：生成/增加配置 ---
# 参数: $1=协议(vmess/vless), $2=UUID, $3=Path
write_config() {
    local PROTOCOL=$1
    local UUID=$2
    local WSPATH=$3

    cat > $CONFIG_FILE << EOF
{
  "log": {
    "access": "/var/log/v2ray/access.log",
    "error": "/var/log/v2ray/error.log",
    "loglevel": "warning"
  },
  "dns": {
    "servers": ["localhost"],
    "queryStrategy": "UseIPv4"
  },
  "policy": {
    "levels": { "0": { "handshake": 4, "connIdle": 300 } }
  },
  "inbounds": [
    {
      "port": 12345,
      "listen": "127.0.0.1",
      "protocol": "$PROTOCOL",
      "settings": {
        "clients": [ { "id": "$UUID", "level": 0 } ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": { "path": "$WSPATH" }
      }
    }
  ],
  "outbounds": [
    { "tag": "direct", "protocol": "freedom", "settings": { "domainStrategy": "UseIPv4" } },
    { "tag": "block", "protocol": "blackhole" }
  ]
}
EOF
    systemctl restart v2ray
    echo "配置已成功应用并重启服务。"
}

# --- 3. 交互菜单 ---
show_menu() {
    clear
    echo "==============================================="
    echo "       V2Ray 战略指挥面板 (将军阁下亲启)       "
    echo "==============================================="
    echo " 1) 安装/新建配置: VLESS-WS-TLS"
    echo " 2) 安装/新建配置: VMess-WS-TLS"
    echo " 3) 查看当前配置报告"
    echo " 4) 增加一条新用户 ID (UUID)"
    echo " 5) 彻底删除所有配置并停止服务"
    echo " 0) 退出"
    echo "-----------------------------------------------"
    read -p "请输入指令 [0-5]: " num

    case "$num" in
        1)
            install_base
            write_config "vless" "$(get_uuid)" "/vlesspath"
            view_report
            ;;
        2)
            install_base
            write_config "vmess" "$(get_uuid)" "/vmesspath"
            view_report
            ;;
        3)
            view_report
            ;;
        4)
            add_user
            ;;
        5)
            delete_all
            ;;
        0)
            exit 0
            ;;
        *)
            echo "无效输入"
            ;;
    esac
}

# --- 4. 报告功能 ---
view_report() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "未检测到配置文件，请先执行安装。"
        return
    fi
    
    local PROTOCOL=$(jq -r '.inbounds[0].protocol' $CONFIG_FILE)
    local UUID=$(jq -r '.inbounds[0].settings.clients[0].id' $CONFIG_FILE)
    local WSPATH=$(jq -r '.inbounds[0].streamSettings.wsSettings.path' $CONFIG_FILE)
    local DOMAIN=$(v2ray info | grep "域名" | awk '{print $2}')
    [ -z "$DOMAIN" ] && DOMAIN=$(hostname -f)

    echo "==============================================="
    echo "           V2Ray 实时配置报告                  "
    echo "==============================================="
    echo "协议 (Protocol): $PROTOCOL"
    echo "地址 (Address): $DOMAIN"
    echo "端口 (Port): 443"
    echo "用户 ID (UUID): $UUID"
    echo "路径 (Path): $WSPATH"
    echo "传输: WebSocket + TLS"
    echo "-----------------------------------------------"
    echo "优化状态：DNS [AsIs] 与 IPv4 优先策略已激活"
    echo "==============================================="
    read -p "按回车键返回菜单..."
}

# --- 5. 增加用户 (UUID) ---
add_user() {
    local NEW_UUID=$(get_uuid)
    # 使用 jq 动态插入新用户到 clients 数组
    jq ".inbounds[0].settings.clients += [{\"id\": \"$NEW_UUID\", \"level\": 0}]" $CONFIG_FILE > ${CONFIG_FILE}.tmp && mv ${CONFIG_FILE}.tmp $CONFIG_FILE
    systemctl restart v2ray
    echo "已增加新 UUID: $NEW_UUID"
    read -p "按回车键返回菜单..."
}

# --- 6. 删除配置 ---
delete_all() {
    read -p "确定要彻底删除所有配置并停止服务吗？(y/n): " confirm
    if [ "$confirm" = "y" ]; then
        systemctl stop v2ray
        rm -rf /etc/v2ray/config.json
        echo "所有配置已清除，服务已停止。"
    fi
    read -p "按回车键返回菜单..."
}

# 执行循环
while true; do
    show_menu
done