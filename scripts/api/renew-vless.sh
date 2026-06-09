#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: API - renew VLESS account (JSON in/out)
# License: Apache License 2.0 (see LICENSE file)
# Repository: https://github.com/risqinf/autoscript
# ========================================================
. /usr/local/sbin/lib/account.sh
db_init
PROTO="vless"

input=$(cat)
user=$(echo "$input" | jq -r '.username // empty' 2>/dev/null)
days=$(echo "$input" | jq -r '.days // empty' 2>/dev/null)
err_json() { echo "{\"status\":\"false\",\"code\":$1,\"message\":\"$2\"}"; exit 1; }

valid_username "$user" || err_json 400 "Invalid username"
valid_days "$days"     || err_json 400 "Days must be 1-3650"
db_account_exists "$PROTO" "$user" || err_json 404 "User '$user' not found"

new_epoch=$(acc_xray_renew "$PROTO" "$user" "$days")
[[ -n "$new_epoch" ]] || err_json 500 "Renew failed"
new_disp=$(date -d "@${new_epoch}" +"%d-%m-%Y %H:%M:%S")

jq -nc --arg u "$user" --arg p "$PROTO" --argjson d "$days" --arg exp "$new_disp" \
'{status:"true",code:200,message:("\($p) account \($u) renewed successfully"),
  data:{username:$u,protocol:$p,days_added:$d,new_expiry:$exp}}'
