#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: Renew VLESS account
# License: Apache License 2.0 (see LICENSE file)
# Repository: https://github.com/risqinf/autoscript
# ========================================================
. /usr/local/sbin/lib/account.sh

require_root
db_init

clear
line
echo -e "${WHITE}  RENEW VLESS ACCOUNT${NC}"
line
printf "%-20s %-22s\n" "USERNAME" "EXPIRED"
echo "------------------------------------------------------------"
db_query "SELECT username, datetime(expired_at,'unixepoch','localtime')
          FROM accounts WHERE protocol='vless' AND status!='deleted'
          ORDER BY username;" \
  | while IFS='|' read -r u e; do printf "%-20s %-22s\n" "$u" "$e"; done
line

read -rp "Username to renew: " user
read -rp "Add days: " days
if ! valid_username "$user"; then err "Invalid username."; read -n1 -s -r -p "Press any key..."; menu; exit 1; fi
if ! valid_days "$days"; then err "Days must be 1-3650."; read -n1 -s -r -p "Press any key..."; menu; exit 1; fi
if ! db_account_exists "vless" "$user"; then err "User not found."; read -n1 -s -r -p "Press any key..."; menu; exit 1; fi

new_epoch=$(acc_xray_renew "vless" "$user" "$days")
if [[ -n "$new_epoch" ]]; then
  new_disp=$(date -d "@${new_epoch}" +"%d-%m-%Y %H:%M:%S")
  tg_send "<b>[ VLESS RENEWED ]</b>%0AUsername: <code>${user}</code>%0ANew expiry: <code>${new_disp}</code>"
  ok "Renewed '$user' by ${days} days. New expiry: ${new_disp}"
else
  err "Renew failed."
fi
line
read -n 1 -s -r -p "Press any key to menu..."
menu
