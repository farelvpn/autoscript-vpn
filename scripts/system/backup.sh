#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: Encrypted backup (SQLite DB + config) sent to Telegram
# License: Apache License 2.0 (see LICENSE file)
# Repository: https://github.com/risqinf/autoscript
# ========================================================
. /usr/local/sbin/lib/common.sh

require_root
domain=$(get_domain)
ipsaya=$(curl -s http://checkip.amazonaws.com 2>/dev/null)
ts=$(date +"%d-%m-%Y")
tm=$(date +"%H-%M-%S")
code=$(openssl rand -hex 4)
zip_file="/root/backup-${ts}-${tm}-${code}.zip"
work="/root/.backup_work"

# Backup encryption password from secure store (fallback: generate + persist).
pass_file="${AS_ETC}/backup.pass"
if [[ -s "$pass_file" ]]; then
  PASSWORD=$(cat "$pass_file")
else
  PASSWORD=$(openssl rand -base64 18)
  printf '%s' "$PASSWORD" > "$pass_file"; chmod 600 "$pass_file"
fi

botToken=$(cat "$AS_BOTKEY" 2>/dev/null)
chatId=$(cat "$AS_CHATID" 2>/dev/null)
if [[ -z "$botToken" || -z "$chatId" ]]; then
  err "Telegram bot.key/client.id not configured."; exit 1
fi

info "Preparing backup..."
rm -rf "$work"; mkdir -p "$work/etc"

# Checkpoint WAL so xray.db is consistent, then copy DB + sidecars.
sqlite3 "$AS_DB" "PRAGMA wal_checkpoint(TRUNCATE);" >/dev/null 2>&1
cp -f "$AS_DB" "$work/etc/" 2>/dev/null
cp -f "$AS_CONFIG" "$work/etc/" 2>/dev/null
cp -f "$AS_DOMAIN_FILE" "$work/etc/" 2>/dev/null
cp -f "$AS_BOTKEY" "$AS_CHATID" "$work/etc/" 2>/dev/null
cp -f /etc/passwd /etc/shadow /etc/group /etc/gshadow "$work/" 2>/dev/null

dnf install zip -y >/dev/null 2>&1
( cd "$work" && zip -rqP "$PASSWORD" "$zip_file" . )
rm -rf "$work"

if [[ ! -f "$zip_file" ]]; then err "Failed to create backup archive."; exit 1; fi

caption="[OK] Backup
File   : $(basename "$zip_file")
Domain : ${domain}
IP     : ${ipsaya}
Date   : ${ts} ${tm}
Code   : ${code}
Pass   : ${PASSWORD}"

info "Sending backup to Telegram..."
resp=$(curl -s -F "chat_id=${chatId}" -F "caption=${caption}" \
            -F "document=@${zip_file}" \
            "https://api.telegram.org/bot${botToken}/sendDocument")

if echo "$resp" | grep -q '"ok":true'; then
  ok "Backup sent to Telegram."
else
  warn "Backup created but Telegram send failed."
fi

rm -f "$zip_file"
ok "Backup complete."
