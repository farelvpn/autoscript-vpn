#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: Create SSH account (SQLite-backed)
# License: Apache License 2.0 (see LICENSE file)
# Repository: https://github.com/risqinf/autoscript
# ========================================================
. /usr/local/sbin/lib/account.sh

require_root
db_init
domain=$(get_domain)
ip=$(get_ip)

clear
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
echo -e "\e[0;41;36m                    CREATE SSH ACCOUNT                      \e[0m"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"

while true; do
  read -rp "Username       : " user
  if ! valid_username "$user"; then err "Username 3-32 chars: letters, numbers, underscore."; continue; fi
  if db_account_exists "ssh" "$user" || id "$user" &>/dev/null; then err "Username '$user' already exists."; continue; fi
  break
done

while true; do
  read -rp "Password       : " pass
  valid_password "$pass" && break
  err "Password must be non-empty, no spaces/tabs/newlines/colons."
done

while true; do read -rp "Limit IP       : " limit_ip; valid_number "$limit_ip" && break; err "Number only."; done
while true; do read -rp "Expired (days) : " days; valid_days "$days" && break; err "Days must be 1-3650."; done

if ! acc_ssh_create "$user" "$pass" "$limit_ip" "$days"; then
  err "Failed to create SSH account."; exit 1
fi

exp_epoch=$(db_get_field "ssh" "$user" "expired_at")
exp_disp=$(date -d "@${exp_epoch}" +"%Y-%m-%d %H:%M:%S")
[[ "$limit_ip" == "0" ]] && ip_disp="Unlimited" || ip_disp="$limit_ip"

TEKS="<b>━━━━━━━━━━━━━━━━━━━━━━━━━━━</b>
<b>       ⊹ SSH ACCOUNT ⊹</b>
<b>━━━━━━━━━━━━━━━━━━━━━━━━━━━</b>
<b>Username  :</b> <code>${user}</code>
<b>Password  :</b> <code>${pass}</code>
<b>Host/IP   :</b> <code>${domain}</code> / <code>${ip}</code>
<b>Limit IP  :</b> <code>${ip_disp}</code>
<b>Expired   :</b> <code>${exp_disp}</code>
<b>━━━━━━━━━━━━━━━━━━━━━━━━━━━</b>
<b>Port OpenSSH :</b> <code>22, 109</code>
<b>Port WS HTTP :</b> <code>80, 8888</code>
<b>Port WS TLS  :</b> <code>443</code>
<b>Port BadVPN  :</b> <code>7300</code>
<b>Port OpenVPN :</b> <code>1194 (TCP), 2200 (UDP)</code>
<b>━━━━━━━━━━━━━━━━━━━━━━━━━━━</b>
<b>Config HTTP Custom :</b>
<code>${domain}:1-65535@${user}:${pass}</code>
<b>━━━━━━━━━━━━━━━━━━━━━━━━━━━</b>
<b>Payload :</b>
<code>GET / HTTP/1.1[crlf]Host: ${domain}[crlf]Upgrade: websocket[crlf][crlf]</code>
<b>━━━━━━━━━━━━━━━━━━━━━━━━━━━</b>
<b>OVPN TCP :</b> <code>https://${domain}/risqinf/openvpn/tcp.ovpn</code>
<b>OVPN UDP :</b> <code>https://${domain}/risqinf/openvpn/udp.ovpn</code>
<b>━━━━━━━━━━━━━━━━━━━━━━━━━━━</b>"
tg_send "$TEKS"

clear
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
echo -e "\e[0;42;30m                  SSH ACCOUNT CREATED                       \e[0m"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
echo -e " Username     : ${user}"
echo -e " Password     : ${pass}"
echo -e " Host/IP      : ${domain} / ${ip}"
echo -e " Limit IP     : ${ip_disp}"
echo -e " Expired      : ${exp_disp}"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
echo -e " Port OpenSSH : 22, 109"
echo -e " Port WS HTTP : 80, 8888"
echo -e " Port WS TLS  : 443"
echo -e " Port BadVPN  : 7300"
echo -e " Port OpenVPN : 1194 (TCP) / 2200 (UDP)"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
echo -e " Config HTTP Custom :"
echo -e " ${domain}:1-65535@${user}:${pass}"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
echo -e " Payload :"
echo -e " GET / HTTP/1.1[crlf]Host: ${domain}[crlf]Upgrade: websocket[crlf][crlf]"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
read -n 1 -s -r -p " Press any key to back to menu..."
menu
