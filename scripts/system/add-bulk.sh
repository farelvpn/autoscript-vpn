#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: AutoScript VPN & Tunneling Management System
# Developed for Rocky Linux 9
# ========================================================
# ========================================================
# Auto Bulk Account Generator
# ========================================================
clear
domain=$(cat /etc/xray/domain 2>/dev/null || echo "not set")
if [[ -s /root/.ip ]]; then
  ip=$(cat /root/.ip)
else
  ip=$(hostname -I | awk '{print $1}')
fi
BOT_TOKEN=$(cat /etc/xray/bot.key 2>/dev/null)
CHAT_ID=$(cat /etc/xray/client.id 2>/dev/null)

echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"
echo -e "\e[0;41;36m                 AUTO BULK ACCOUNT GENERATOR                \e[0m"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"
echo "1. SSH"
echo "2. VLESS"
echo "3. VMESS"
echo "4. TROJAN"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"
read -p "Select Protocol (1-4): " prot_sel

case $prot_sel in
    1) proto="ssh";;
    2) proto="vless";;
    3) proto="vmess";;
    4) proto="trojan";;
    *) echo "Invalid selection"; exit 1;;
esac

read -p "Account Prefix (e.g., user): " prefix
# Validasi prefix: huruf, angka, underscore (1-16 char). Cegah path traversal & injeksi.
if ! [[ "$prefix" =~ ^[a-zA-Z0-9_]{1,16}$ ]]; then
    echo "Prefix can only contain letters, numbers and underscores (1-16 chars)."
    exit 1
fi
read -p "Number of Accounts: " count

if ! [[ "$count" =~ ^[0-9]+$ ]] || [ "$count" -lt 1 ]; then
    echo "Count must be a positive number."
    exit 1
fi

read -p "Expired (days): " exp_days
if ! [[ "$exp_days" =~ ^[0-9]+$ ]]; then
    echo "Expired days must be a number."
    exit 1
fi

read -p "Max IP Login: " limit_ip
if ! [[ "$limit_ip" =~ ^[0-9]+$ ]]; then
    echo "Max IP must be a number."
    exit 1
fi

if [[ "$proto" != "ssh" ]]; then
    read -p "Quota (GB, 0 for unlimited): " quota
    if ! [[ "$quota" =~ ^[0-9]+$ ]]; then
        echo "Quota must be a number."
        exit 1
    fi
    [[ "$quota" == "0" ]] && quota_display="Unlimited" || quota_display="${quota} GB"
fi

[[ "$limit_ip" == "0" ]] && iplimit_display="Unlimited" || iplimit_display="${limit_ip}"

echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"
echo "Generating $count $proto accounts..."
sleep 1

# Password generator
gen_pass() {
    < /dev/urandom tr -dc A-Za-z0-9 | head -c8
}

success_count=0

for ((i=1; i<=count; i++)); do
    # Generate username
    rand_suffix=$(< /dev/urandom tr -dc a-z0-9 | head -c4)
    username="${prefix}${rand_suffix}"
    
    # Generate pass/uuid
    if [[ "$proto" == "ssh" ]]; then
        password=$(gen_pass)
        
        exp_system=$(date -d "$exp_days days" +%Y-%m-%d)
        exp_display=$(date -d "$exp_days days" +"%d-%m-%Y %H:%M:%S")

        if ! id "$username" &>/dev/null && [[ ! -e /etc/xray/database/ssh/$username.txt ]]; then
            useradd -e "$exp_system" -M -N -s /sbin/nologin "$username" 2>/dev/null
            echo "$username:$password" | chpasswd 2>/dev/null
            echo "$limit_ip" > /etc/xray/limit/ip/ssh/$username
            cat > /etc/xray/database/ssh/$username.txt <<EOF
username: $username
password: $password
limit_ip: $limit_ip
expired: $exp_display
EOF
            echo -e "
———————————————————
 Success Create SSH Account 
———————————————————
Domain   : $domain / $ip 
Username : $username 
Password : $password 
Limit IP : $iplimit_display 
———————————————————
Port OpenSSH : 109
Port WS HTTP : 80, 8888
Port WS TLS  : 443
Port BadVPN  : 7300
Port Openvpn : 1194 (TCP) / 2200 (UDP)
———————————————————
Config HTTP Custom: ${domain}:1-65535@${username}:${password}
———————————————————
Payload: GET / HTTP/1.1[crlf]Host: ${domain}[crlf]Upgrade: websocket[crlf][crlf]
———————————————————
OVPN TCP : https://$domain:444/risqinf/openvpn/tcp.ovpn
OVPN UDP : https://$domain:444/risqinf/openvpn/udp.ovpn
———————————————————
Expired  : $exp_display
———————————————————"

            if [[ -n "$BOT_TOKEN" && -n "$CHAT_ID" ]]; then
                TEKS="<b>Success Create SSH Account</b>%0A"
                TEKS+="<b>———————————————————</b>%0A"
                TEKS+="<b>Domain:</b> <code>$domain</code> / <code>$ip</code>%0A"
                TEKS+="<b>Username:</b> <code>$username</code>%0A"
                TEKS+="<b>Password:</b> <code>$password</code>%0A"
                TEKS+="<b>Limit IP:</b> <code>$iplimit_display</code>%0A"
                TEKS+="<b>———————————————————</b>%0A"
                TEKS+="<b>Port OpenSSH:</b> <code>109</code>%0A"
                TEKS+="<b>Port WS HTTP:</b> <code>80, 8888</code>%0A"
                TEKS+="<b>Port WS TLS:</b> <code>443</code>%0A"
                TEKS+="<b>Port BadVPN:</b> <code>7300</code>%0A"
                TEKS+="<b>Port Openvpn:</b> <code>1194 (TCP), 2200 (UDP)</code>%0A"
                TEKS+="<b>Port Squid:</b> <code>8080</code>%0A"
                TEKS+="<b>Port OHP:</b> <code>3128, 8000</code>%0A"
                TEKS+="<b>———————————————————</b>%0A"
                TEKS+="<b>Config HTTP Custom:</b> <code>${domain}:1-65535@${username}:${password}</code>%0A"
                TEKS+="<b>———————————————————</b>%0A"
                TEKS+="<b>Payload:</b> <code>GET / HTTP/1.1[crlf]Host: ${domain}[crlf]Upgrade: websocket[crlf][crlf]</code>%0A"
                TEKS+="<b>———————————————————</b>%0A"
                TEKS+="<b>OVPN TCP: https://$domain:444/risqinf/openvpn/tcp.ovpn</b>%0A"
                TEKS+="<b>OVPN UDP: https://$domain:444/risqinf/openvpn/udp.ovpn</b>%0A"
                TEKS+="<b>———————————————————</b>%0A"
                TEKS+="<b>Expired:</b> <code>$exp_display</code>%0A"
                TEKS+="<b>———————————————————</b>%0A"
                curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" -d "chat_id=$CHAT_ID" -d "parse_mode=HTML" --data-urlencode "text=$TEKS" > /dev/null
            fi
            ((success_count++))
        fi
        
    else
        uuid=$(cat /proc/sys/kernel/random/uuid)
        exp_full=$(date -d "+${exp_days} days" +"%Y-%m-%d-%H-%M-%S")
        
        if [[ $quota -gt 0 ]]; then
            bytes=$((quota * 1024 * 1024 * 1024))
        else
            bytes=0
        fi

        if [[ "$proto" == "vless" ]]; then
            if ! grep -qw "\"$username\"" /etc/xray/config.json; then
                sed -i '/#vless$/a\#÷ '"$username $exp_full"'\
},{"id": "'"$uuid"'","email": "'"$username"'"' /etc/xray/config.json
                echo "$limit_ip" > "/etc/xray/limit/ip/vless/$username"
                [[ $bytes -gt 0 ]] && echo "$bytes" > "/etc/xray/limit/quota/vless/$username"
                cat > /etc/xray/database/vless/$username.txt <<EOF
username: $username
uuid: $uuid
limit_ip: $limit_ip
quota: $quota
expired: $exp_full
EOF
                vlesslink1="vless://${uuid}@${domain}:443?path=/vless&security=tls&encryption=none&type=ws&host=${domain}&sni=${domain}#${username}"
                vlesslink2="vless://${uuid}@${domain}:80?path=/vless&encryption=none&type=ws&host=${domain}#${username}"
                
                echo -e "
━━━━━━━━━━━━━━━━━━━━━━━━
 [<= VLESS ACCOUNT =>]
━━━━━━━━━━━━━━━━━━━━━━━━
Hostname    : ${domain}
Username    : ${username}
Expired     : ${exp_full}
━━━━━━━━━━━━━━━━━━━━━━━━
   ACCOUNT INFORMATION
━━━━━━━━━━━━━━━━━━━━━━━━
UUID/Key    : $uuid
Encryption  : none
Path WS     : /vless
━━━━━━━━━━━━━━━━━━━━━━━━
Limit IP    : ${iplimit_display}
Limit Quota : $quota_display
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

                if [[ -n "$BOT_TOKEN" && -n "$CHAT_ID" ]]; then
                    TEXT="<b>━━━━━━━━━━━━━━━━━━━━━━━━</b>%0A"
                    TEXT+="<b>     [ VLESS ACCOUNT ]     </b>%0A"
                    TEXT+="<b>━━━━━━━━━━━━━━━━━━━━━━━━</b>%0A"
                    TEXT+="<b>Hostname : </b> <code>${domain}</code>%0A"
                    TEXT+="<b>Username : </b> <code>${username}</code>%0A"
                    TEXT+="<b>Expired  : </b> <code>${exp_full}</code>%0A"
                    TEXT+="<b>━━━━━━━━━━━━━━━━━━━━━━━━</b>%0A"
                    TEXT+="<b>     Account Information     </b>%0A"
                    TEXT+="<b>━━━━━━━━━━━━━━━━━━━━━━━━</b>%0A"
                    TEXT+="<b>UUID/Key : </b> <code>$uuid</code>%0A"
                    TEXT+="<b>Encryption:</b> <code>none</code>%0A"
                    TEXT+="<b>Path WS  : </b> <code>/vless</code>%0A"
                    TEXT+="<b>━━━━━━━━━━━━━━━━━━━━━━━━</b>%0A"
                    TEXT+="<b>Limit IP : </b> <code>$iplimit_display</code>%0A"
                    TEXT+="<b>Quota    : </b> <code>$quota_display</code>%0A"
                    TEXT+="<b>━━━━━━━━━━━━━━━━━━━━━━━━</b>%0A"
                    TEXT+="<b>        Port & Service       </b>%0A"
                    TEXT+="<b>━━━━━━━━━━━━━━━━━━━━━━━━</b>%0A"
                    TEXT+="<b>VLESS WS TLS : 443</b>%0A"
                    TEXT+="<b>VLESS WS HTTP: 80</b>%0A"
                    TEXT+="<b>━━━━━━━━━━━━━━━━━━━━━━━━</b>%0A"
                    TEXT+="<b>Link VLESS WS TLS : </b>%0A<code>$vlesslink1</code>%0A"
                    TEXT+="<b>━━━━━━━━━━━━━━━━━━━━━━━━</b>%0A"
                    TEXT+="<b>Link VLESS WS Non-TLS : </b>%0A<code>$vlesslink2</code>%0A"
                    TEXT+="<b>━━━━━━━━━━━━━━━━━━━━━━━━</b>%0A"
                    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" -d chat_id="${CHAT_ID}" -d parse_mode="HTML" -d text="${TEXT}" > /dev/null
                fi
                ((success_count++))
            fi
            
        elif [[ "$proto" == "vmess" ]]; then
            if ! grep -qw "\"$username\"" /etc/xray/config.json; then
                sed -i '/#vmess$/a\### '"$username $exp_full"'\
},{"id": "'"$uuid"'","alterId": 0,"email": "'"$username"'"' /etc/xray/config.json
                echo "$limit_ip" > "/etc/xray/limit/ip/vmess/$username"
                [[ $bytes -gt 0 ]] && echo "$bytes" > "/etc/xray/limit/quota/vmess/$username"
                cat > /etc/xray/database/vmess/$username.txt <<EOF
username: $username
uuid: $uuid
limit_ip: $limit_ip
quota: $quota
expired: $exp_full
EOF
                acs=`cat<<EOF
      {
      "v": "2",
      "ps": "${username}",
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
      "ps": "${username}",
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
Username    : ${username}
Expired     : ${exp_full}
━━━━━━━━━━━━━━━━━━━━━━━━
   ACCOUNT INFORMATION
━━━━━━━━━━━━━━━━━━━━━━━━
UUID/Key    : $uuid
Encryption  : none
Path WS     : /multipath
━━━━━━━━━━━━━━━━━━━━━━━━
Limit IP    : ${iplimit_display}
Limit Quota : $quota_display
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
                if [[ -n "$BOT_TOKEN" && -n "$CHAT_ID" ]]; then
                    TEXT="<b>━━━━━━━━━━━━━━━━━━━━━━━━</b>%0A"
                    TEXT+="<b>     [ VMESS ACCOUNT ]     </b>%0A"
                    TEXT+="<b>━━━━━━━━━━━━━━━━━━━━━━━━</b>%0A"
                    TEXT+="<b>Hostname : </b> <code>${domain}</code>%0A"
                    TEXT+="<b>Username : </b> <code>${username}</code>%0A"
                    TEXT+="<b>Expired  : </b> <code>${exp_full}</code>%0A"
                    TEXT+="<b>━━━━━━━━━━━━━━━━━━━━━━━━</b>%0A"
                    TEXT+="<b>     Account Information     </b>%0A"
                    TEXT+="<b>━━━━━━━━━━━━━━━━━━━━━━━━</b>%0A"
                    TEXT+="<b>UUID/Key : </b> <code>$uuid</code>%0A"
                    TEXT+="<b>Encryption:</b> <code>none</code>%0A"
                    TEXT+="<b>Path WS  : </b> <code>/multipath</code>%0A"
                    TEXT+="<b>━━━━━━━━━━━━━━━━━━━━━━━━</b>%0A"
                    TEXT+="<b>Limit IP : </b> <code>$iplimit_display</code>%0A"
                    TEXT+="<b>Quota    : </b> <code>$quota_display</code>%0A"
                    TEXT+="<b>━━━━━━━━━━━━━━━━━━━━━━━━</b>%0A"
                    TEXT+="<b>        Port & Service       </b>%0A"
                    TEXT+="<b>━━━━━━━━━━━━━━━━━━━━━━━━</b>%0A"
                    TEXT+="<b>VMESS WS TLS : 443</b>%0A"
                    TEXT+="<b>VMESS WS HTTP: 80</b>%0A"
                    TEXT+="<b>━━━━━━━━━━━━━━━━━━━━━━━━</b>%0A"
                    TEXT+="<b>Link VMESS WS TLS : </b>%0A<code>$vmesslink1</code>%0A"
                    TEXT+="<b>━━━━━━━━━━━━━━━━━━━━━━━━</b>%0A"
                    TEXT+="<b>Link VMESS WS Non-TLS : </b>%0A<code>$vmesslink2</code>%0A"
                    TEXT+="<b>━━━━━━━━━━━━━━━━━━━━━━━━</b>%0A"
                    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" -d chat_id="${CHAT_ID}" -d parse_mode="HTML" -d text="${TEXT}" > /dev/null
                fi
                ((success_count++))
            fi
            
        elif [[ "$proto" == "trojan" ]]; then
            if ! grep -qw "\"$username\"" /etc/xray/config.json; then
                sed -i '/#trojan$/a\#@ '"$username $exp_full"'\
},{"password": "'"$uuid"'","email": "'"$username"'"' /etc/xray/config.json
                echo "$limit_ip" > "/etc/xray/limit/ip/trojan/$username"
                [[ $bytes -gt 0 ]] && echo "$bytes" > "/etc/xray/limit/quota/trojan/$username"
                cat > /etc/xray/database/trojan/$username.txt <<EOF
username: $username
uuid: $uuid
limit_ip: $limit_ip
quota: $quota
expired: $exp_full
EOF
                trojanlink1="trojan://${uuid}@${domain}:443?type=ws&security=tls&host=${domain}&path=/trojan&sni=${domain}#${username}"

                echo -e "
━━━━━━━━━━━━━━━━━━━━━━━━
 [<= TROJAN ACCOUNT =>]
━━━━━━━━━━━━━━━━━━━━━━━━
Hostname    : ${domain}
Username    : ${username}
Expired     : ${exp_full}
━━━━━━━━━━━━━━━━━━━━━━━━
   ACCOUNT INFORMATION
━━━━━━━━━━━━━━━━━━━━━━━━
UUID/Key    : $uuid
Encryption  : none
Path WS     : /trojan
━━━━━━━━━━━━━━━━━━━━━━━━
Limit IP    : ${iplimit_display}
Limit Quota : $quota_display
━━━━━━━━━━━━━━━━━━━━━━━━
     PORT & SERVICE
━━━━━━━━━━━━━━━━━━━━━━━━
TROJAN WS TLS : 443
TROJAN WS HTTP: 80
━━━━━━━━━━━━━━━━━━━━━━━━
Link TROJAN WS TLS   : 
$trojanlink1
━━━━━━━━━━━━━━━━━━━━━━━━"
                if [[ -n "$BOT_TOKEN" && -n "$CHAT_ID" ]]; then
                    TEXT="<b>━━━━━━━━━━━━━━━━━━━━━━━━</b>%0A"
                    TEXT+="<b>     [ TROJAN ACCOUNT ]     </b>%0A"
                    TEXT+="<b>━━━━━━━━━━━━━━━━━━━━━━━━</b>%0A"
                    TEXT+="<b>Hostname : </b> <code>${domain}</code>%0A"
                    TEXT+="<b>Username : </b> <code>${username}</code>%0A"
                    TEXT+="<b>Expired  : </b> <code>${exp_full}</code>%0A"
                    TEXT+="<b>━━━━━━━━━━━━━━━━━━━━━━━━</b>%0A"
                    TEXT+="<b>     Account Information     </b>%0A"
                    TEXT+="<b>━━━━━━━━━━━━━━━━━━━━━━━━</b>%0A"
                    TEXT+="<b>UUID/Key : </b> <code>$uuid</code>%0A"
                    TEXT+="<b>Encryption:</b> <code>none</code>%0A"
                    TEXT+="<b>Path WS  : </b> <code>/trojan</code>%0A"
                    TEXT+="<b>━━━━━━━━━━━━━━━━━━━━━━━━</b>%0A"
                    TEXT+="<b>Limit IP : </b> <code>$iplimit_display</code>%0A"
                    TEXT+="<b>Quota    : </b> <code>$quota_display</code>%0A"
                    TEXT+="<b>━━━━━━━━━━━━━━━━━━━━━━━━</b>%0A"
                    TEXT+="<b>        Port & Service       </b>%0A"
                    TEXT+="<b>━━━━━━━━━━━━━━━━━━━━━━━━</b>%0A"
                    TEXT+="<b>TROJAN WS TLS : 443</b>%0A"
                    TEXT+="<b>TROJAN WS HTTP: 80</b>%0A"
                    TEXT+="<b>━━━━━━━━━━━━━━━━━━━━━━━━</b>%0A"
                    TEXT+="<b>Link TROJAN WS TLS : </b>%0A<code>$trojanlink1</code>%0A"
                    TEXT+="<b>━━━━━━━━━━━━━━━━━━━━━━━━</b>%0A"
                    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" -d chat_id="${CHAT_ID}" -d parse_mode="HTML" -d text="${TEXT}" > /dev/null
                fi
                ((success_count++))
            fi
        fi
    fi
done

if [[ "$proto" != "ssh" ]]; then
    systemctl restart xray.service
else
    systemctl restart dropbear sshd ssh-ws 2>/dev/null
fi

echo "------------------------------------------------------------"
echo -e "\e[32mSuccessfully created $success_count out of $count accounts.\e[0m"
read -n 1 -s -r -p "Press any key to return to menu..."
clear
menu