#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: API - create Trojan account (JSON in/out)
# License: Apache License 2.0 (see LICENSE file)
# Repository: https://github.com/risqinf/autoscript
# ========================================================
. /usr/local/sbin/lib/account.sh
db_init
domain=$(get_domain)

input=$(cat)
user=$(echo "$input" | jq -r '.username // empty' 2>/dev/null)
secret=$(echo "$input" | jq -r '.uuid // .password // empty' 2>/dev/null)
quota=$(echo "$input" | jq -r '.quota // 0' 2>/dev/null)
iplimit=$(echo "$input" | jq -r '.iplimit // .limit_ip // 0' 2>/dev/null)
duration=$(echo "$input" | jq -r '.duration // empty' 2>/dev/null)

err_json() { echo "{\"status\":\"false\",\"code\":$1,\"message\":\"$2\"}"; exit 1; }

valid_username "$user"     || err_json 400 "Invalid username"
[[ -z "$secret" ]] && secret=$(gen_uuid)
[[ "$secret" == *[$'\n\r\t ']* ]] && err_json 400 "Secret must not contain whitespace"
valid_number "$quota"      || err_json 400 "Quota must be a number"
valid_number "$iplimit"    || err_json 400 "IP limit must be a number"
valid_duration "$duration" || err_json 400 "Duration must be like 30m, 2h, 1d"

secs=$(duration_to_seconds "$duration")
exp_epoch=$(( $(date +%s) + secs ))

acc_xray_create "trojan" "$user" "$secret" "$quota" "$iplimit" "$exp_epoch" >/dev/null 2>&1
rc=$?
case $rc in
  0) ;;
  9) err_json 409 "Username or key already in use" ;;
  *) err_json 500 "Failed to create Trojan account" ;;
esac

exp_disp=$(date -d "@${exp_epoch}" +"%d-%m-%Y %H:%M:%S")
link_tls="trojan://${secret}@${domain}:443?type=ws&security=tls&host=${domain}&path=/trojan&sni=${domain}#${user}"

jq -nc --arg u "$user" --arg s "$secret" --arg d "$domain" --arg exp "$exp_disp" \
      --argjson q "$quota" --argjson li "$iplimit" --arg link "$link_tls" \
'{status:"true",code:201,message:"Trojan account created successfully",
  data:{username:$u,key:$s,domain:$d,expired:$exp,
        limits:{ip:$li,quota_gb:$q},
        ports:{ws_tls:443,ws_http:80},
        links:{ws_tls:$link}}}'
