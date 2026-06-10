#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: Shared common helpers (colors, validation, IO)
# License: Apache License 2.0 (see LICENSE file)
# Repository: https://github.com/risqinf/autoscript
# ========================================================
# Source this file:  . /usr/local/sbin/lib/common.sh
# Guard against double-sourcing.
[[ -n "${__AS_COMMON_LOADED:-}" ]] && return 0
__AS_COMMON_LOADED=1

# --- Paths ---
export AS_ETC="/etc/xray"
export AS_DB="${AS_ETC}/xray.db"
export AS_CONFIG="${AS_ETC}/config.json"
export AS_DOMAIN_FILE="${AS_ETC}/domain"
export AS_BOTKEY="${AS_ETC}/bot.key"
export AS_CHATID="${AS_ETC}/client.id"
export AS_LIBDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Colors ---
export NC='\033[0m'
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export CYAN='\033[0;36m'
export WHITE='\033[1;37m'

line() { echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; }
ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
err()   { echo -e "${RED}[ERROR]${NC} $1"; }

# --- Consistent UI primitives (used by every menu/script) ---
# Centered title bar in a uniform box. Arg: title text.
ui_header() {
  local t="$1" w=58
  local pad=$(( (w - ${#t}) / 2 ))
  (( pad < 0 )) && pad=0
  echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
  printf "${CYAN}║${WHITE}%*s%s%*s${CYAN}║${NC}\n" "$pad" "" "$t" "$(( w - pad - ${#t} ))" ""
  echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
}
ui_sep()  { echo -e "${CYAN}────────────────────────────────────────────────────────────${NC}"; }
ui_foot() { echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"; }
# Standard "back to menu" prompt used everywhere.
ui_back() { echo ""; read -n 1 -s -r -p " Press any key to return..."; }

# --- Domain / IP ---
get_domain() { cat "$AS_DOMAIN_FILE" 2>/dev/null || echo "not set"; }
get_ip() {
  if [[ -s /root/.ip ]]; then cat /root/.ip
  else hostname -I | awk '{print $1}'
  fi
}

# --- Validation (strict allowlists) ---
valid_username() { [[ "$1" =~ ^[a-zA-Z0-9_]{3,32}$ ]]; }
valid_prefix()   { [[ "$1" =~ ^[a-zA-Z0-9_]{1,16}$ ]]; }
valid_number()   { [[ "$1" =~ ^[0-9]+$ ]]; }
valid_days()     { [[ "$1" =~ ^[0-9]+$ ]] && (( $1 >= 1 && $1 <= 3650 )); }
valid_duration() { [[ "$1" =~ ^[0-9]+[mhd]$ ]]; }
valid_uuid()     { [[ "$1" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]]; }
valid_password() {
  # Non-empty, no whitespace/control/colon (safe for chpasswd and configs)
  [[ -n "$1" ]] || return 1
  [[ "$1" == *[$'\n\r\t :']* ]] && return 1
  return 0
}
valid_domain()   { [[ "$1" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; }

gen_uuid() { cat /proc/sys/kernel/random/uuid; }
gen_pass() { tr -dc 'A-Za-z0-9' </dev/urandom | head -c "${1:-10}"; }

# Resolve the nologin shell path and ensure it is registered in /etc/shells.
# On Rocky Linux 9 the binary is /usr/sbin/nologin (with /sbin -> /usr/sbin).
# PAM's pam_shells rejects logins whose shell is not listed in /etc/shells,
# which surfaces to SSH/WS clients as "incorrect username or password".
ensure_nologin_shell() {
  local sh=""
  if [[ -x /usr/sbin/nologin ]]; then sh=/usr/sbin/nologin
  elif [[ -x /sbin/nologin ]]; then sh=/sbin/nologin
  fi
  [[ -z "$sh" ]] && { echo ""; return 1; }
  touch /etc/shells 2>/dev/null
  # Register both common paths so either resolves.
  grep -qxF "$sh" /etc/shells 2>/dev/null || echo "$sh" >> /etc/shells
  if [[ "$sh" == /usr/sbin/nologin ]] && [[ -e /sbin/nologin ]]; then
    grep -qxF "/sbin/nologin" /etc/shells 2>/dev/null || echo "/sbin/nologin" >> /etc/shells
  fi
  echo "$sh"
  return 0
}

# --- Duration -> seconds ---
duration_to_seconds() {
  local d="$1" v="${1%?}" u="${1: -1}"
  case "$u" in
    m) echo $(( v * 60 ));;
    h) echo $(( v * 3600 ));;
    d) echo $(( v * 86400 ));;
    *) echo 0;;
  esac
}

# --- Telegram ---
tg_send() {
  local text="$1"
  local token chat
  token=$(cat "$AS_BOTKEY" 2>/dev/null)
  chat=$(cat "$AS_CHATID" 2>/dev/null)
  [[ -z "$token" || -z "$chat" ]] && return 1
  # Accept both real newlines and literal %0A markers in the message body.
  text=${text//%0A/$'\n'}
  curl -s -X POST "https://api.telegram.org/bot${token}/sendMessage" \
    -d chat_id="${chat}" -d parse_mode="HTML" \
    -d disable_web_page_preview="true" \
    --data-urlencode "text=${text}" >/dev/null 2>&1
}

# --- Require root ---
require_root() {
  if [[ $EUID -ne 0 ]]; then err "This must be run as root."; exit 1; fi
}
