if [[ "$PROTOCOL" == "vless" ]]; then
    SHARE_LINK="vless://$UUID@$DOMAIN:443?encryption=none&security=tls&type=ws&host=$DOMAIN&path=$SAFE_PATH#$DOMAIN"
else
    # VMess 生成 JSON -> Base64 -> 加上 #备注
    VMESS_JSON=$(cat <<EOF
{
  "v": "2", "ps": "$DOMAIN", "add": "$DOMAIN", "port": "443", "id": "$UUID",
  "aid": "0", "net": "ws", "type": "none", "host": "$DOMAIN", "path": "$WSPATH", "tls": "tls"
}
EOF
    )
    # 在 Base64 编码后强制追加 #域名 备注
    BASE64_CODE=$(echo -n "$VMESS_JSON" | base64 -w 0)
    SHARE_LINK="vmess://${BASE64_CODE}#${DOMAIN}"
fi