#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: AutoScript VPN & Tunneling Management System
# Developed for Rocky Linux 9
# ========================================================
# ========================================================
# IP LIMIT CHECKER FOR VLESS ACCOUNTS
# ========================================================

# Number of consecutive violation cycles required before enforcement.
# This absorbs transient NAT / log-race false positives so a legitimate
# user is not suspended over a single spurious reading.
VIOLATION_THRESHOLD=3
VIOL_DIR="/etc/xray/limit/ip/vless/.violations"
mkdir -p "$VIOL_DIR"

while true; do
    # Get all VLESS users
    readarray -t data < <(grep '#÷' /etc/xray/config.json | cut -d ' ' -f 2 | sort | uniq)
    
    for akun in "${data[@]}"; do
        [[ -z "$akun" ]] && continue
        
        # Check if IP limit file exists for this user
        if [[ -f "/etc/xray/limit/ip/vless/$akun" ]]; then
            limit_ip=$(cat "/etc/xray/limit/ip/vless/$akun")
            
            # Only check if limit is greater than 0
            if [[ "$limit_ip" -gt 0 ]]; then
                # Get current active IPs for this user
                temp_log="/tmp/vless_${akun}_iplimit.tmp"
                temp_ips="/tmp/vless_${akun}_current_ips.tmp"
                temp_networks="/tmp/vless_${akun}_networks.tmp"
                viol_file="$VIOL_DIR/$akun"
                
                # Get recent connections for this user
                grep -w "email: $akun" /var/log/xray/access.log | grep "accepted" | tail -n 100 > "$temp_log" 2>/dev/null
                
                if [[ -s "$temp_log" ]]; then
                    # Extract all source IPs
                    awk '{print $4}' "$temp_log" | cut -d':' -f1 | grep -v "^$" > "$temp_ips"
                    
                    # Group IPs by network prefix (first 3 octets) to handle NAT
                    if [[ -s "$temp_ips" ]]; then
                        # Create unique network prefixes (first 3 octets)
                        awk -F'.' '{print $1"."$2"."$3}' "$temp_ips" | sort -u > "$temp_networks"
                    fi
                    
                    # Count unique networks
                    current_networks=$(wc -l < "$temp_networks" 2>/dev/null || echo "0")
                    
                    # Check if limit exceeded
                    if [[ "$current_networks" -gt "$limit_ip" ]]; then
                        # Increment consecutive-violation counter
                        viol=$(cat "$viol_file" 2>/dev/null || echo 0)
                        viol=$((viol + 1))
                        echo "$viol" > "$viol_file"

                        if [[ "$viol" -lt "$VIOLATION_THRESHOLD" ]]; then
                            echo "User $akun over IP limit ($current_networks > $limit_ip) - strike $viol/$VIOLATION_THRESHOLD (grace)."
                        else
                        echo "User $akun exceeded IP limit ($current_networks > $limit_ip) for $viol cycles. Suspending account (moved to recovery)..."
                        rm -f "$viol_file"
                        
                        # Create recovery directory if it doesn't exist
                        mkdir -p /etc/xray/recovery/vless
                        
                        # Move database file to recovery directory (reversible via Recovery menu)
                        if [[ -f "/etc/xray/database/vless/${akun}.txt" ]]; then
                            mv "/etc/xray/database/vless/${akun}.txt" "/etc/xray/recovery/vless/${akun}.txt"
                        fi
                        
                        # Remove quota limit file if exists
                        if [[ -f "/etc/xray/limit/quota/vless/${akun}" ]]; then
                            rm -f "/etc/xray/limit/quota/vless/${akun}"
                        fi
                        
                        # Remove usage quota file if exists
                        if [[ -f "/etc/xray/usage/quota/vless/${akun}" ]]; then
                            rm -f "/etc/xray/usage/quota/vless/${akun}"
                        fi
                        
                        # Remove IP limit file
                        if [[ -f "/etc/xray/limit/ip/vless/${akun}" ]]; then
                            rm -f "/etc/xray/limit/ip/vless/${akun}"
                        fi
                        
                        # Remove user from config.json
                        sed -i "/#÷ $akun /,/^}/d" /etc/xray/config.json
                        # Clean up any trailing comma
                        sed -i '/},/ { :a;N;$!ba;s/},\n\s*}/}\n}/g; }' /etc/xray/config.json
                        
                        # Restart Xray service
                        systemctl restart xray.service
                        
                        # Send to Telegram (if configured)
                        BOT_TOKEN=$(cat /etc/xray/bot.key 2>/dev/null)
                        CHAT_ID=$(cat /etc/xray/client.id 2>/dev/null)
                        
                        if [[ -n "$BOT_TOKEN" && -n "$CHAT_ID" ]]; then
                            TEXT="<b>━━━━━━━━━━━━━━━━━━━━━━━━</b>%0A"
                            TEXT+="<b>     IP LIMIT EXCEEDED     </b>%0A"
                            TEXT+="<b>━━━━━━━━━━━━━━━━━━━━━━━━</b>%0A"
                            TEXT+="<b>Username     :</b> <code>$akun</code>%0A"
                            TEXT+="<b>IP Count     :</b> <code>$current_networks</code>%0A"
                            TEXT+="<b>IP Limit     :</b> <code>$limit_ip</code>%0A"
                            TEXT+="<b>Status       :</b> <code>SUSPENDED</code>%0A"
                            TEXT+="<b>Recovery     :</b> <code>Restore via Recovery menu</code>%0A"
                            TEXT+="<b>━━━━━━━━━━━━━━━━━━━━━━━━</b>%0A"
                            
                            curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
                                -d chat_id="${CHAT_ID}" \
                                -d parse_mode="HTML" \
                                -d text="${TEXT}" > /dev/null
                        fi
                        fi
                    else
                        # Within limit: reset the violation counter
                        rm -f "$viol_file" 2>/dev/null
                    fi
                    
                    # Cleanup temporary files
                    rm -f "$temp_log" "$temp_ips" "$temp_networks"
                else
                    # No connections found: reset counter and cleanup
                    rm -f "$viol_file" 2>/dev/null
                    rm -f "$temp_log" "$temp_ips" "$temp_networks"
                fi
            fi
        fi
    done
    
    # Sleep for 30 seconds before next check
    sleep 30
done