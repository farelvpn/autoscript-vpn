#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: Restore backup (SQLite DB + config + system files)
# License: Apache License 2.0 (see LICENSE file)
# Repository: https://github.com/risqinf/autoscript
# ========================================================
. /usr/local/sbin/lib/common.sh

require_root
backup_dir="/root"

pass_file="${AS_ETC}/backup.pass"
if [[ -s "$pass_file" ]]; then
  PASSWORD=$(cat "$pass_file")
else
  read -rsp "Enter backup encryption password: " PASSWORD; echo
  [[ -z "$PASSWORD" ]] && { err "Password cannot be empty."; exit 1; }
fi

clear
line
echo -e "${WHITE}  RESTORE BACKUP${NC}"
line

# Find newest local backup, else prompt for a path.
backup_file=$(ls -t "$backup_dir"/backup-*.zip 2>/dev/null | head -1)
if [[ -z "$backup_file" ]]; then
  read -rp "Path to backup .zip: " backup_file
fi
[[ -f "$backup_file" ]] || { err "Backup file not found."; exit 1; }

if ! unzip -t -P "$PASSWORD" "$backup_file" &>/dev/null; then
  err "Invalid archive or wrong password."; exit 1
fi

work="/root/.restore_work"
rm -rf "$work"; mkdir -p "$work"
unzip -o -P "$PASSWORD" "$backup_file" -d "$work" >/dev/null 2>&1

info "Restoring data..."
mkdir -p "$AS_ETC"; chmod 700 "$AS_ETC"
[[ -f "$work/etc/xray.db" ]]     && { cp -f "$work/etc/xray.db" "$AS_DB"; chmod 600 "$AS_DB"; ok "database restored"; }
[[ -f "$work/etc/config.json" ]] && { cp -f "$work/etc/config.json" "$AS_CONFIG"; ok "config restored"; }
[[ -f "$work/etc/domain" ]]      && cp -f "$work/etc/domain" "$AS_DOMAIN_FILE"
[[ -f "$work/etc/bot.key" ]]     && { cp -f "$work/etc/bot.key" "$AS_BOTKEY"; chmod 600 "$AS_BOTKEY"; }
[[ -f "$work/etc/client.id" ]]   && { cp -f "$work/etc/client.id" "$AS_CHATID"; chmod 600 "$AS_CHATID"; }
[[ -f "$work/passwd" ]]  && cp -f "$work/passwd" /etc/
[[ -f "$work/shadow" ]]  && cp -f "$work/shadow" /etc/
[[ -f "$work/group" ]]   && cp -f "$work/group" /etc/
[[ -f "$work/gshadow" ]] && cp -f "$work/gshadow" /etc/

rm -rf "$work"

info "Restarting services..."
systemctl restart xray 2>/dev/null
systemctl restart sshd 2>/dev/null
systemctl restart dropbear 2>/dev/null

line
ok "Restore complete."
line
