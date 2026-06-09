#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: High-level account service (DB + Xray config + system user)
# License: Apache License 2.0 (see LICENSE file)
# Repository: https://github.com/risqinf/autoscript
# ========================================================
[[ -n "${__AS_ACCOUNT_LOADED:-}" ]] && return 0
__AS_ACCOUNT_LOADED=1

LIBD="$(dirname "${BASH_SOURCE[0]}")"
. "$LIBD/common.sh"
. "$LIBD/db.sh"
. "$LIBD/xraycfg.sh"

# ---- XRAY ACCOUNTS (vless/vmess/trojan) ----
# Create. Args: proto user secret quota_gb limit_ip expired_epoch
# Echoes nothing; returns 0/!=0. On success the account is in DB + config.
acc_xray_create() {
  local proto="$1" user="$2" secret="$3" quota_gb="$4" limit_ip="$5" exp_epoch="$6"
  local quota_bytes=0
  (( quota_gb > 0 )) && quota_bytes=$(( quota_gb * 1073741824 ))

  if db_account_exists "$proto" "$user" || cfg_client_exists "$user"; then
    err "username '$user' already exists"; return 9
  fi
  if db_secret_in_use "$secret" || cfg_secret_exists "$secret"; then
    err "secret/uuid already in use"; return 9
  fi

  # Config first (validated + rollback); then DB.
  if ! cfg_add_client "$proto" "$user" "$secret"; then
    err "failed to update xray config"; return 1
  fi
  if ! db_insert_account "$proto" "$user" "$secret" "$quota_bytes" "$limit_ip" "$exp_epoch"; then
    # rollback config
    cfg_del_client "$proto" "$user"
    err "failed to write database"; return 1
  fi
  db_audit "create" "$proto" "$user" "quota=${quota_gb}GB ip=${limit_ip}"
  systemctl restart xray.service >/dev/null 2>&1
  return 0
}

# Soft-delete (status=deleted) + remove from config. Recoverable from DB.
acc_xray_delete() {
  local proto="$1" user="$2"
  db_account_exists "$proto" "$user" || { err "account not found"; return 4; }
  cfg_del_client "$proto" "$user" || { err "failed to update config"; return 1; }
  db_set_status "$proto" "$user" "deleted"
  db_audit "delete" "$proto" "$user" ""
  systemctl restart xray.service >/dev/null 2>&1
  return 0
}

# Suspend (status=suspended) + remove from config but keep DB row active-data.
acc_xray_suspend() {
  local proto="$1" user="$2" reason="${3:-limit}"
  db_account_exists "$proto" "$user" || return 4
  cfg_del_client "$proto" "$user"
  db_set_status "$proto" "$user" "suspended"
  db_audit "suspend" "$proto" "$user" "$reason"
  systemctl restart xray.service >/dev/null 2>&1
  return 0
}

# Renew. Args: proto user add_days  -> extends from max(now, current expiry)
acc_xray_renew() {
  local proto="$1" user="$2" days="$3"
  local cur now base new
  cur=$(db_get_field "$proto" "$user" "expired_at")
  [[ -z "$cur" ]] && { err "account not found"; return 4; }
  now=$(date +%s)
  base=$cur; (( cur < now )) && base=$now
  new=$(( base + days * 86400 ))
  db_set_expired "$proto" "$user" "$new"
  db_audit "renew" "$proto" "$user" "+${days}d"
  echo "$new"
  return 0
}

# ---- SSH ACCOUNTS ----
acc_ssh_create() {
  local user="$1" pass="$2" limit_ip="$3" days="$4"
  local exp_epoch exp_system
  exp_epoch=$(( $(date +%s) + days * 86400 ))
  exp_system=$(date -d "@${exp_epoch}" +%Y-%m-%d)

  if db_account_exists "ssh" "$user" || id "$user" &>/dev/null; then
    err "username '$user' already exists"; return 9
  fi
  useradd -e "$exp_system" -M -N -s /sbin/nologin "$user" || { err "useradd failed"; return 1; }
  echo "${user}:${pass}" | chpasswd || { userdel --force "$user" >/dev/null 2>&1; err "chpasswd failed"; return 1; }
  db_insert_account "ssh" "$user" "$pass" 0 "$limit_ip" "$exp_epoch"
  db_audit "create" "ssh" "$user" "ip=${limit_ip} days=${days}"
  return 0
}

acc_ssh_delete() {
  local user="$1"
  db_account_exists "ssh" "$user" || { err "account not found"; return 4; }
  id "$user" &>/dev/null && userdel --force "$user" >/dev/null 2>&1
  db_set_status "ssh" "$user" "deleted"
  db_audit "delete" "ssh" "$user" ""
  systemctl restart dropbear >/dev/null 2>&1
  return 0
}

acc_ssh_renew() {
  local user="$1" days="$2"
  local cur now base new
  cur=$(db_get_field "ssh" "$user" "expired_at")
  [[ -z "$cur" ]] && { err "account not found"; return 4; }
  now=$(date +%s)
  base=$cur; (( cur < now )) && base=$now
  new=$(( base + days * 86400 ))
  db_set_expired "ssh" "$user" "$new"
  id "$user" &>/dev/null && chage -E "$(date -d "@${new}" +%Y-%m-%d)" "$user" 2>/dev/null
  db_audit "renew" "ssh" "$user" "+${days}d"
  echo "$new"
  return 0
}
