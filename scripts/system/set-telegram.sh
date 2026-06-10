#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: Configure Telegram bot token + admin chat id (for notifications/backup)
# License: Apache License 2.0 (see LICENSE file)
# Repository: https://github.com/risqinf/autoscript
# ========================================================
. /usr/local/sbin/lib/common.sh
require_root

show_state() {
  local tok chat
  if [[ -s "$AS_BOTKEY" ]]; then
    tok=$(cat "$AS_BOTKEY"); tok="${tok:0:8}...(${#tok} chars)"
  else tok="${RED}not set${NC}"; fi
  if [[ -s "$AS_CHATID" ]]; then chat=$(cat "$AS_CHATID"); else chat="${RED}not set${NC}"; fi
  echo -e " ${WHITE}Bot Token${NC} : ${tok}"
  echo -e " ${WHITE}Chat ID${NC}   : ${chat}"
}

tg_menu() {
  clear
  ui_header "TELEGRAM SETUP"
  echo -e " Used for account/backup notifications sent directly to the admin."
  ui_sep
  show_state
  ui_sep
  echo -e " 1)  Set Bot Token"
  echo -e " 2)  Set Admin Chat ID"
  echo -e " 3)  Send Test Message"
  echo -e " 4)  Remove Telegram Config"
  ui_foot
  echo -e " 0)  Back"
  ui_foot
  read -rp " Select option : " opt
  case "$opt" in
    1)
      echo ""
      read -rp " Paste Bot Token (from @BotFather): " tok
      tok="${tok//[[:space:]]/}"
      if [[ "$tok" =~ ^[0-9]+:[A-Za-z0-9_-]+$ ]]; then
        printf '%s' "$tok" > "$AS_BOTKEY"; chmod 600 "$AS_BOTKEY"
        ok "Bot token saved."
      else
        err "Invalid token format (expected like 123456:ABC-DEF...)."
      fi
      sleep 1; tg_menu ;;
    2)
      echo ""
      echo -e " ${CYAN}Tip:${NC} message your bot, then open"
      echo -e " https://api.telegram.org/bot<token>/getUpdates to find your chat id."
      read -rp " Enter Admin Chat ID (numeric): " chat
      chat="${chat//[[:space:]]/}"
      if [[ "$chat" =~ ^-?[0-9]+$ ]]; then
        printf '%s' "$chat" > "$AS_CHATID"; chmod 600 "$AS_CHATID"
        ok "Chat ID saved."
      else
        err "Invalid chat id (must be numeric, may start with -)."
      fi
      sleep 1; tg_menu ;;
    3)
      if tg_is_configured; then
        if tg_send "<b>[Autoscript]</b> Test message OK from <code>$(get_domain)</code>."; then
          ok "Test message sent. Check your Telegram."
        else
          err "Send failed. Verify token/chat id and server internet access."
        fi
      else
        warn "Configure both Bot Token and Chat ID first."
      fi
      ui_back; tg_menu ;;
    4)
      rm -f "$AS_BOTKEY" "$AS_CHATID"
      ok "Telegram config removed."
      sleep 1; tg_menu ;;
    0|x|X) menu-system ;;
    *) err "Invalid option."; sleep 1; tg_menu ;;
  esac
}

tg_menu
