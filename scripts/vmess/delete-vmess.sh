#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: Delete VMESS account (soft-delete, recoverable)
# License: Apache License 2.0 (see LICENSE file)
# Repository: https://github.com/risqinf/autoscript
# ========================================================
. /usr/local/sbin/lib/account.sh

require_root
db_init
domain=$(get_domain)

clear
line
echo -e "${WHITE}  DELETE VMESS ACCOUNT${NC}"
line
printf "%-20s %-22s %-10s\n" "USERNAME" "EXPIRED" "STATUS"
echo "------------------------------------------------------------"
db_query "SELECT username, datetime(expired_at,'unixepoch','localtime'), status
          FROM accounts WHERE protocol='vmess' AND status!='deleted'
          ORDER BY username;" \
  | while IFS='|' read -r u e s; do printf "%-20s %-22s %-10s\n" "$u" "$e" "$s"; done
line

read -rp "Enter username to delete: " user
if ! valid_username "$user"; then err "Invalid username format."; read -n1 -s -r -p "Press any key..."; menu; exit 1; fi
if ! db_account_exists "vmess" "$user"; then
  err "User '$user' not found."; read -n1 -s -r -p "Press any key..."; menu; exit 1
fi

read -rp "Delete '$user'? (y/N): " c
[[ "$c" =~ ^[Yy]$ ]] || { warn "Cancelled."; read -n1 -s -r -p "Press any key..."; menu; exit 0; }

if acc_xray_delete "vmess" "$user"; then
  tg_send "<b>[ VMESS DELETED ]</b>%0AUsername: <code>${user}</code>%0AStatus: deleted (recoverable)"
  ok "User '$user' deleted (recoverable via Recovery menu)."
else
  err "Failed to delete '$user'."
fi
line
read -n 1 -s -r -p "Press any key to menu..."
menu
