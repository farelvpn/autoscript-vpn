#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: API - create trial SSH account (JSON in/out)
# License: Apache License 2.0 (see LICENSE file)
# Repository: https://github.com/risqinf/autoscript
# ========================================================
. /usr/local/sbin/lib/account.sh
db_init
domain=$(get_domain); ip=$(get_ip)

input=$(cat)
duration=$(echo "$input" | jq -r '.duration // "60m"' 2>/dev/null)
limit_ip=$(echo "$input" | jq -r '.limit_ip // 1' 2>/dev/null)
err_json() { echo "{\"status\":\"false\",\"code\":$1,\"message\":\"$2\"}"; exit 1; }
valid_duration "$duration" || err_json 400 "Duration must be like 30m, 1h, 1d"
valid_number "$limit_ip"   || err_json 400 "Limit IP must be a number"

user="trial$(gen_pass 6)"
pass=$(gen_pass 10)
secs=$(duration_to_seconds "$duration")
exp_epoch=$(( $(date +%s) + secs ))
exp_system=$(date -d "@${exp_epoch}" +%Y-%m-%d)

if db_account_exists "ssh" "$user" || id "$user" &>/dev/null; then err_json 409 "Username collision, retry"; fi
useradd -e "$exp_system" -M -N -s /sbin/nologin "$user" || err_json 500 "useradd failed"
echo "${user}:${pass}" | chpasswd || { userdel --force "$user" >/dev/null 2>&1; err_json 500 "chpasswd failed"; }
db_insert_account "ssh" "$user" "$pass" 0 "$limit_ip" "$exp_epoch"
db_audit "create" "ssh" "$user" "trial api ${duration}"
exp_disp=$(date -d "@${exp_epoch}" +"%d-%m-%Y %H:%M:%S")

jq -nc --arg u "$user" --arg p "$pass" --arg d "$domain" --arg ip "$ip" \
      --argjson li "$limit_ip" --arg exp "$exp_disp" \
'{status:"true",code:201,message:"SSH trial account created successfully",
  data:{username:$u,password:$p,domain:$d,ip:$ip,limit_ip:$li,expired:$exp,
        config:($d+":1-65535@"+$u+":"+$p)}}'
