#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: API - create trial Trojan account (JSON in/out)
# License: Apache License 2.0 (see LICENSE file)
# Repository: https://github.com/risqinf/autoscript
# ========================================================
. /usr/local/sbin/lib/account.sh
db_init
domain=$(get_domain)

input=$(cat)
duration=$(echo "$input" | jq -r '.duration // "60m"' 2>/dev/null)
err_json() { echo "{\"status\":\"false\",\"code\":$1,\"message\":\"$2\"}"; exit 1; }
valid_duration "$duration" || err_json 400 "Duration must be like 30m, 1h, 1d"

user="trial$(gen_pass 6)"
secret=$(gen_uuid)
secs=$(duration_to_seconds "$duration")
exp_epoch=$(( $(date +%s) + secs ))

acc_xray_create "trojan" "$user" "$secret" 10 2 "$exp_epoch" >/dev/null 2>&1 || err_json 500 "Failed to create trial"
exp_disp=$(date -d "@${exp_epoch}" +"%d-%m-%Y %H:%M:%S")
link_tls="trojan://${secret}@${domain}:443?type=ws&security=tls&host=${domain}&path=/trojan&sni=${domain}#${user}"

jq -nc --arg u "$user" --arg s "$secret" --arg d "$domain" --arg exp "$exp_disp" --arg link "$link_tls" \
'{status:"true",code:201,message:"Trial Trojan account created successfully",
  data:{username:$u,key:$s,domain:$d,expired:$exp,limits:{ip:2,quota_gb:10},links:{ws_tls:$link}}}'
