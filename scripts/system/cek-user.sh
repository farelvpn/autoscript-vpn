#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: AutoScript VPN & Tunneling Management System
# Developed for Rocky Linux 9
# ========================================================
# ========================================================
# Unified Account Checker
# ========================================================
clear
domain=$(cat /etc/xray/domain 2>/dev/null || echo "not set")
if [[ -s /root/.ip ]]; then
  ip=$(cat /root/.ip)
else
  ip=$(hostname -I | awk '{print $1}')
fi

echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"
echo -e "\e[0;41;36m                 UNIFIED ACCOUNT CHECKER                    \e[0m"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"
read -p "Input Username : " user
echo "------------------------------------------------------------"

# Validasi format username (cegah path traversal)
if ! [[ "$user" =~ ^[a-zA-Z0-9_]{1,32}$ ]]; then
    echo -e "\e[31mInvalid username format.\e[0m"
    read -n 1 -s -r -p "Press any key to return to menu..."
    menu
    exit 1
fi

found=0

# Check SSH
if [[ -f /etc/xray/database/ssh/$user.txt ]]; then
    found=1
    password=$(grep -w "password:" /etc/xray/database/ssh/$user.txt | cut -d' ' -f2)
    exp_display=$(grep -w "expired:" /etc/xray/database/ssh/$user.txt | cut -d' ' -f2-)
    limit_ip=$(grep -w "limit_ip:" /etc/xray/database/ssh/$user.txt | cut -d' ' -f2)
    [[ -z "$limit_ip" || "$limit_ip" == "0" ]] && limit_ip="Unlimited"

    echo -e "
———————————————————
 [<= SSH ACCOUNT =>] 
———————————————————
Domain   : $domain / $ip 
Username : $user 
Password : $password 
Limit IP : $limit_ip 
———————————————————
Port OpenSSH : 109
Port WS HTTP : 80, 8888
Port WS TLS  : 443
Port BadVPN  : 7300
———————————————————
Config HTTP Custom: ${domain}:1-65535@${user}:${password}
———————————————————
Payload: GET / HTTP/1.1[crlf]Host: ${domain}[crlf]Upgrade: websocket[crlf][crlf]
———————————————————
OVPN File: https://$domain/risqinf/index.html
———————————————————
Expired  : $exp_display
———————————————————"
fi

# Check VLESS
if [[ -f /etc/xray/database/vless/$user.txt ]]; then
    found=1
    uuid=$(grep -w "uuid:" /etc/xray/database/vless/$user.txt | cut -d' ' -f2)
    exp_full=$(grep -w "expired:" /etc/xray/database/vless/$user.txt | cut -d' ' -f2)
    limit_ip=$(grep -w "limit_ip:" /etc/xray/database/vless/$user.txt | cut -d' ' -f2)
    quota=$(grep -w "quota:" /etc/xray/database/vless/$user.txt | cut -d' ' -f2)
    [[ -z "$limit_ip" || "$limit_ip" == "0" ]] && limit_ip="Unlimited"
    [[ -z "$quota" || "$quota" == "0" ]] && quota="Unlimited" || quota="$quota GB"

    vlesslink1="vless://${uuid}@${domain}:443?path=/vless&security=tls&encryption=none&type=ws&host=${domain}&sni=${domain}#${user}"
    vlesslink2="vless://${uuid}@${domain}:80?path=/vless&encryption=none&type=ws&host=${domain}#${user}"

    echo -e "
━━━━━━━━━━━━━━━━━━━━━━━━
 [<= VLESS ACCOUNT =>]
━━━━━━━━━━━━━━━━━━━━━━━━
Hostname    : ${domain}
Username    : ${user}
Expired     : ${exp_full}
━━━━━━━━━━━━━━━━━━━━━━━━
   ACCOUNT INFORMATION
━━━━━━━━━━━━━━━━━━━━━━━━
UUID/Key    : $uuid
Encryption  : none
Path WS     : /vless
━━━━━━━━━━━━━━━━━━━━━━━━
Limit IP    : ${limit_ip}
Limit Quota : $quota
━━━━━━━━━━━━━━━━━━━━━━━━
     PORT & SERVICE
━━━━━━━━━━━━━━━━━━━━━━━━
VLESS WS TLS : 443
VLESS WS HTTP: 80
━━━━━━━━━━━━━━━━━━━━━━━━
Link VLESS WS TLS   : 
$vlesslink1
━━━━━━━━━━━━━━━━━━━━━━━━
Link VLESS WS Non-TLS : 
$vlesslink2
━━━━━━━━━━━━━━━━━━━━━━━━"
fi

# Check VMESS
if [[ -f /etc/xray/database/vmess/$user.txt ]]; then
    found=1
    uuid=$(grep -w "uuid:" /etc/xray/database/vmess/$user.txt | cut -d' ' -f2)
    exp_full=$(grep -w "expired:" /etc/xray/database/vmess/$user.txt | cut -d' ' -f2)
    limit_ip=$(grep -w "limit_ip:" /etc/xray/database/vmess/$user.txt | cut -d' ' -f2)
    quota=$(grep -w "quota:" /etc/xray/database/vmess/$user.txt | cut -d' ' -f2)
    [[ -z "$limit_ip" || "$limit_ip" == "0" ]] && limit_ip="Unlimited"
    [[ -z "$quota" || "$quota" == "0" ]] && quota="Unlimited" || quota="$quota GB"

    acs=`cat<<EOF
      {
      "v": "2",
      "ps": "${user}",
      "add": "${domain}",
      "port": "443",
      "id": "${uuid}",
      "aid": "0",
      "net": "ws",
      "path": "/vmess",
      "type": "none",
      "host": "${domain}",
      "tls": "tls"
}
EOF`

    ask=`cat<<EOF
      {
      "v": "2",
      "ps": "${user}",
      "add": "${domain}",
      "port": "80",
      "id": "${uuid}",
      "aid": "0",
      "net": "ws",
      "path": "/vmess",
      "type": "none",
      "host": "${domain}",
      "tls": "none"
}
EOF`
    vmesslink1="vmess://$(echo $acs | base64 -w 0)"
    vmesslink2="vmess://$(echo $ask | base64 -w 0)"

    echo -e "
━━━━━━━━━━━━━━━━━━━━━━━━
 [<= VMESS ACCOUNT =>]
━━━━━━━━━━━━━━━━━━━━━━━━
Hostname    : ${domain}
Username    : ${user}
Expired     : ${exp_full}
━━━━━━━━━━━━━━━━━━━━━━━━
   ACCOUNT INFORMATION
━━━━━━━━━━━━━━━━━━━━━━━━
UUID/Key    : $uuid
Encryption  : none
Path WS     : /multipath
━━━━━━━━━━━━━━━━━━━━━━━━
Limit IP    : ${limit_ip}
Limit Quota : $quota
━━━━━━━━━━━━━━━━━━━━━━━━
     PORT & SERVICE
━━━━━━━━━━━━━━━━━━━━━━━━
VMESS WS TLS : 443
VMESS WS HTTP: 80
━━━━━━━━━━━━━━━━━━━━━━━━
Link VMESS WS TLS   : 
$vmesslink1
━━━━━━━━━━━━━━━━━━━━━━━━
Link VMESS WS Non-TLS : 
$vmesslink2
━━━━━━━━━━━━━━━━━━━━━━━━"
fi

# Check TROJAN
if [[ -f /etc/xray/database/trojan/$user.txt ]]; then
    found=1
    uuid=$(grep -w "uuid:" /etc/xray/database/trojan/$user.txt | cut -d' ' -f2)
    exp_full=$(grep -w "expired:" /etc/xray/database/trojan/$user.txt | cut -d' ' -f2)
    limit_ip=$(grep -w "limit_ip:" /etc/xray/database/trojan/$user.txt | cut -d' ' -f2)
    quota=$(grep -w "quota:" /etc/xray/database/trojan/$user.txt | cut -d' ' -f2)
    [[ -z "$limit_ip" || "$limit_ip" == "0" ]] && limit_ip="Unlimited"
    [[ -z "$quota" || "$quota" == "0" ]] && quota="Unlimited" || quota="$quota GB"

    trojanlink1="trojan://${uuid}@${domain}:443?type=ws&security=tls&host=${domain}&path=/trojan&sni=${domain}#${user}"

    echo -e "
━━━━━━━━━━━━━━━━━━━━━━━━
 [<= TROJAN ACCOUNT =>]
━━━━━━━━━━━━━━━━━━━━━━━━
Hostname    : ${domain}
Username    : ${user}
Expired     : ${exp_full}
━━━━━━━━━━━━━━━━━━━━━━━━
   ACCOUNT INFORMATION
━━━━━━━━━━━━━━━━━━━━━━━━
UUID/Key    : $uuid
Encryption  : none
Path WS     : /trojan
━━━━━━━━━━━━━━━━━━━━━━━━
Limit IP    : ${limit_ip}
Limit Quota : $quota
━━━━━━━━━━━━━━━━━━━━━━━━
     PORT & SERVICE
━━━━━━━━━━━━━━━━━━━━━━━━
TROJAN WS TLS : 443
TROJAN WS HTTP: 80
━━━━━━━━━━━━━━━━━━━━━━━━
Link TROJAN WS TLS   : 
$trojanlink1
━━━━━━━━━━━━━━━━━━━━━━━━"
fi

if [[ $found -eq 0 ]]; then
    echo -e "\e[31mAccount '$user' not found in any protocol database.\e[0m"
    echo "------------------------------------------------------------"
fi

read -n 1 -s -r -p "Press any key to return to menu..."
menu