#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: AutoScript VPN & Tunneling Management System
# Developed for Rocky Linux 9
# ========================================================
# ========================================================
# Author: risqinf
# Script: recovery-trojan
# Function: Restore deleted TROJAN accounts (API version)
# ========================================================

domain=$(cat /etc/xray/domain 2>/dev/null)
read input

username=$(echo "$input" | jq -r '.username' 2>/dev/null)

# === Validasi username ===
if [[ -z "$username" || "$username" == "null" ]]; then
    echo '{"status":false,"code":400,"message":"Username field is required"}'
    exit 1
fi

if ! [[ "$username" =~ ^[a-zA-Z0-9_]{1,32}$ ]]; then
    echo '{"status":false,"code":400,"message":"Invalid username format"}'
    exit 1
fi

recovery_file="/etc/xray/recovery/trojan/${username}.txt"

# === Cek apakah file recovery ada ===
if [[ ! -f "$recovery_file" ]]; then
    echo '{"status":false,"code":404,"message":"No recovery data found for this username"}'
    exit 1
fi

# === Ambil data dari file recovery ===
uuid=$(grep "^uuid:" "$recovery_file" | cut -d' ' -f2-)
limit_ip=$(grep "^limit_ip:" "$recovery_file" | cut -d' ' -f2-)
quota=$(grep "^quota:" "$recovery_file" | cut -d' ' -f2-)
expired=$(grep "^expired:" "$recovery_file" | cut -d' ' -f2-)

# === Pastikan data lengkap ===
if [[ -z "$uuid" || -z "$expired" ]]; then
    echo '{"status":false,"code":500,"message":"Corrupted recovery file — missing UUID or expiration date"}'
    exit 1
fi

# === Cek apakah username sudah ada ===
if grep -q "\"email\": \"$username\"" /etc/xray/config.json; then
    echo '{"status":false,"code":409,"message":"Username already exists in active config"}'
    exit 1
fi

# === Buat direktori yang diperlukan ===
mkdir -p /etc/xray/limit/quota/trojan
mkdir -p /etc/xray/limit/ip/trojan
mkdir -p /etc/xray/database/trojan
mkdir -p /etc/xray/usage/quota/trojan

# === Pindahkan file recovery ke database aktif ===
mv "$recovery_file" "/etc/xray/database/trojan/${username}.txt"

# === Atur quota dan limit IP ===
if [[ "$quota" =~ ^[0-9]+$ && "$quota" -gt 0 ]]; then
    echo $((quota * 1024 * 1024 * 1024)) > "/etc/xray/limit/quota/trojan/${username}"
fi

if [[ "$limit_ip" =~ ^[0-9]+$ && "$limit_ip" -gt 0 ]]; then
    echo "$limit_ip" > "/etc/xray/limit/ip/trojan/${username}"
fi

# === Tambahkan user ke config.json ===
sed -i '/#trojan$/a\#@ '"$username $expired"'\
},{"password": "'"$uuid"'","email": "'"$username"'"' /etc/xray/config.json

# === Restart service Xray ===
systemctl restart xray.service

# === Format quota & IP limit ===
[[ -z "$limit_ip" || "$limit_ip" == "0" ]] && iplimit_display="Unlimited" || iplimit_display="$limit_ip"
[[ -z "$quota" || "$quota" == "0" ]] && quota_display="Unlimited" || quota_display="${quota} GB"

# === Generate link ===
trojan_ws_tls="trojan://${uuid}@${domain}:443?type=ws&security=tls&host=${domain}&path=/trojan&sni=${domain}#${username}"
trojan_ws_http="trojan://${uuid}@${domain}:80?type=ws&security=none&host=${domain}&path=/trojan#${username}"

# === Output JSON sukses ===
echo "{
  \"status\": true,
  \"code\": 200,
  \"message\": \"TROJAN account restored successfully\",
  \"data\": {
    \"username\": \"$username\",
    \"uuid\": \"$uuid\",
    \"domain\": \"$domain\",
    \"expired\": \"$expired\",
    \"limit_ip\": \"$limit_ip\",
    \"quota\": \"$quota\",
    \"links\": {
      \"trojan_ws_tls\": \"$trojan_ws_tls\",
      \"trojan_ws_http\": \"$trojan_ws_http\"
    }
  }
}"