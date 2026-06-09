#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: AutoScript VPN & Tunneling Management System
# Developed for Rocky Linux 9
# ========================================================
# // limit quota trojan
while true; do
  sleep 30
  data=($(cat /etc/xray/config.json | grep '^#@' | cut -d ' ' -f 2 | sort | uniq))
  
  # Create necessary directories
  if [[ ! -e /etc/xray/usage/quota/trojan ]]; then
    mkdir -p /etc/xray/usage/quota/trojan
  fi
  
  if [[ ! -e /etc/xray/limit/quota/trojan ]]; then
    mkdir -p /etc/xray/limit/quota/trojan
  fi
  
  # Collect usage data for each user
  for user in ${data[@]}
  do
    xray api stats --server=127.0.0.1:10085 -name "user>>>${user}>>>traffic>>>downlink" >& /tmp/${user}
    getThis=$(cat /tmp/${user} | awk '{print $1}');
    
    if [[ ${getThis} != "failed" ]]; then
      downlink=$(xray api stats --server=127.0.0.1:10085 -name "user>>>${user}>>>traffic>>>downlink" | grep -w "value" | awk '{print $2}' | cut -d '"' -f2);
      
      # Store current usage in /etc/xray/usage/quota/trojan/$username
      if [ -e /etc/xray/usage/quota/trojan/${user} ]; then
        current_usage=$(cat /etc/xray/usage/quota/trojan/${user});
        if [[ ${#current_usage} -gt 0 ]]; then
          total_usage=$(( ${downlink} + ${current_usage} ));
          echo "${total_usage}" > /etc/xray/usage/quota/trojan/"${user}"
        else
          echo "${downlink}" > /etc/xray/usage/quota/trojan/"${user}"
        fi
      else
        echo "${downlink}" > /etc/xray/usage/quota/trojan/"${user}"
      fi
      
      # Reset API stats
      xray api stats --server=127.0.0.1:10085 -name "user>>>${user}>>>traffic>>>downlink" -reset > /dev/null 2>&1
    fi
  done
  
  # Check quota limits and delete accounts if exceeded
  for user in ${data[@]}
  do
    # Check if limit file exists
    if [ -e /etc/xray/limit/quota/trojan/${user} ]; then
      limit_quota=$(cat /etc/xray/limit/quota/trojan/${user});
      
      # Check if usage file exists
      if [ -e /etc/xray/usage/quota/trojan/${user} ]; then
        current_usage=$(cat /etc/xray/usage/quota/trojan/${user});
        
        # Compare usage with limit (limit is already divided by 1000)
        if [[ ${current_usage} -gt ${limit_quota} ]]; then
          # Delete account - move to recovery
          echo "User ${user} exceeded quota limit. Deleting account..."
          
          # Create recovery directory if it doesn't exist
          mkdir -p /etc/xray/recovery/trojan
          
          # Move database file to recovery directory
          if [[ -f "/etc/xray/database/trojan/${user}.txt" ]]; then
            mv "/etc/xray/database/trojan/${user}.txt" "/etc/xray/recovery/trojan/${user}.txt"
          fi
          
          # Remove usage quota file
          if [[ -f "/etc/xray/usage/quota/trojan/${user}" ]]; then
            rm -f "/etc/xray/usage/quota/trojan/${user}"
          fi
          
          # Remove IP limit file if exists
          if [[ -f "/etc/xray/limit/ip/trojan/${user}" ]]; then
            rm -f "/etc/xray/limit/ip/trojan/${user}"
          fi
          
          # Remove user from config.json
          sed -i "/#@ $user /,/^}/d" /etc/xray/config.json
          # Clean up any trailing comma
          sed -i '/},/ { :a;N;$!ba;s/},\n\s*}/}\n}/g; }' /etc/xray/config.json
          
          # Restart Xray service
          systemctl restart xray.service

          # Telegram Notification
          BOT_TOKEN=$(cat /etc/xray/bot.key 2>/dev/null)
          CHAT_ID=$(cat /etc/xray/client.id 2>/dev/null)

          if [[ -n "$BOT_TOKEN" && -n "$CHAT_ID" ]]; then
              TEXT="<b>━━━━━━━━━━━━━━━━━━━━━━━━</b>%0A"
              TEXT+="<b>   QUOTA LIMIT EXCEEDED    </b>%0A"
              TEXT+="<b>━━━━━━━━━━━━━━━━━━━━━━━━</b>%0A"
              TEXT+="<b>Protocol     :</b> <code>TROJAN</code>%0A"
              TEXT+="<b>Username     :</b> <code>$user</code>%0A"
              TEXT+="<b>Limit Quota  :</b> <code>$limit_quota</code>%0A"
              TEXT+="<b>Status       :</b> <code>DELETED</code>%0A"
              TEXT+="<b>Recovery     :</b> <code>Available</code>%0A"
              TEXT+="<b>━━━━━━━━━━━━━━━━━━━━━━━━</b>%0A"

              curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
                  -d chat_id="${CHAT_ID}" \
                  -d parse_mode="HTML" \
                  -d text="${TEXT}" > /dev/null
          fi
        fi
      fi
    fi
  done
done