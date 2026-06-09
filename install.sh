#!/bin/bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: AutoScript VPN & Tunneling Management System
# Developed for Rocky Linux 9
# License: Apache License 2.0 (see LICENSE file)
# Repository: https://github.com/risqinf/autoscript
# ========================================================
# --- Color Definitions ---
NC='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
LIGHT='\033[0;37m'

# --- UI Helpers ---
print_header() {
    clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${PURPLE}         ◎ ENTERPRISE VPN AUTOSCRIPT INSTALLER ◎            ${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_success() { echo -e "${GREEN}[OK]${NC} $1"; }
print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Verify a service is active after enable/start. Usage: check_service <name> [fatal]
# If the second arg is "fatal", abort installation when the service is not active.
check_service() {
    local svc="$1"
    local fatal="${2:-}"
    if systemctl is-active --quiet "$svc"; then
        print_success "Service '$svc' is active."
        return 0
    fi
    print_error "Service '$svc' failed to start."
    systemctl status "$svc" --no-pager -l 2>/dev/null | head -n 15
    if [[ "$fatal" == "fatal" ]]; then
        print_error "Critical service '$svc' is not running. Aborting installation."
        exit 1
    fi
    return 1
}

show_progress() {
    local duration=$1
    local col=$(tput cols)
    local width=$((col - 20))
    echo -ne "  Progress: ["
    for ((i=0; i<width; i++)); do echo -ne " "; done
    echo -ne "] 0%"
    for ((i=0; i<=width; i++)); do
        local per=$((i * 100 / width))
        echo -ne "\r  Progress: ["
        for ((j=0; j<i; j++)); do echo -ne "■"; done
        for ((j=i; j<width; j++)); do echo -ne " "; done
        echo -ne "] $per%"
        sleep 0.05
    done
    echo -e "\n"
}

# Check if the user is root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Error: This script must be run as root!${NC}"
  exit 1
fi

# Password Root Change
print_header
echo -e "${LIGHT}Preparation: Security Hardening${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
while true; do
    read -rsp "Enter new root password: " root_pass; echo
    if [[ -z "$root_pass" ]]; then
        print_error "Root password cannot be empty."
        continue
    fi
    if [[ ${#root_pass} -lt 8 ]]; then
        print_warn "Password is shorter than 8 characters. Use a stronger one."
    fi
    read -rsp "Confirm new root password: " root_pass2; echo
    [[ "$root_pass" == "$root_pass2" ]] && break
    print_error "Passwords do not match. Try again."
done
echo "root:$root_pass" | chpasswd
print_success "Root password updated successfully."

# Backup encryption password (stored securely in /etc/xray)
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
mkdir -p /etc/xray
chmod 700 /etc/xray
while true; do
    read -rsp "Enter backup encryption password: " backup_pass; echo
    if [[ -z "$backup_pass" ]]; then
        print_error "Backup password cannot be empty."
        continue
    fi
    if [[ ${#backup_pass} -lt 8 ]]; then
        print_warn "Backup password is shorter than 8 characters. Use a stronger one."
    fi
    read -rsp "Confirm backup encryption password: " backup_pass2; echo
    [[ "$backup_pass" == "$backup_pass2" ]] && break
    print_error "Passwords do not match. Try again."
done
printf '%s' "$backup_pass" > /etc/xray/backup.pass
chmod 600 /etc/xray/backup.pass
unset root_pass root_pass2 backup_pass backup_pass2
print_success "Backup password saved to /etc/xray/backup.pass (chmod 600)."
sleep 1

print_info "Updating system repositories..."
dnf install epel-release -y >/dev/null 2>&1
dnf makecache >/dev/null 2>&1

print_info "Installing core dependencies..."
dnf install wget curl openssl sudo binutils coreutils gnupg2 bc vnstat htop lsof jq sqlite tar gzip python3 ruby rubygems -y >/dev/null 2>&1
gem install lolcat >/dev/null 2>&1
print_success "Core packages installed."

# Fix DNS
print_info "Optimizing DNS resolution..."
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 1.1.1.1" >> /etc/resolv.conf
print_success "DNS configured."

# Fix Port OpenSSH & Permit Root Login
print_info "Configuring SSH Access..."
cd /etc/ssh
sed -i 's/#Port 22/Port 22/g' sshd_config
sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/g' sshd_config
sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/g' sshd_config
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' sshd_config
grep -q "Port 3303" sshd_config || echo -e "Port 3303" >> sshd_config
cd
systemctl daemon-reload
systemctl restart sshd
print_success "SSH Hardening complete (Port 22, 3303)."

# Make A Directory
print_info "Preparing system directories..."
mkdir -p /etc/xray/limit/ip/{ssh,vless,trojan,vmess}
mkdir -p /etc/xray/limit/quota/{vless,trojan,vmess}
mkdir -p /etc/xray/limit/database/{ssh,vless,trojan,vmess}
mkdir -p /etc/xray/usage/quota/{vless,trojan,vmess}
mkdir -p /etc/xray/recovery/{ssh,vless,trojan,vmess}
print_success "Directories created."

# Copy Menu
REPO_OWNER="risqinf"
REPO_NAME="autoscript"
REPO_BRANCH="main"
REPO_TARBALL="https://github.com/${REPO_OWNER}/${REPO_NAME}/archive/refs/heads/${REPO_BRANCH}.tar.gz"

menu_install_logic() {
    print_info "Downloading management menu..."
    dnf install tar gzip -y >/dev/null 2>&1

    local tmpdir
    tmpdir=$(mktemp -d)
    wget -qO "$tmpdir/repo.tar.gz" "$REPO_TARBALL"
    tar -xzf "$tmpdir/repo.tar.gz" -C "$tmpdir" >/dev/null 2>&1

    local srcdir="$tmpdir/${REPO_NAME}-${REPO_BRANCH}"

    # Install shared libraries into /usr/local/sbin/lib (sourced, not commands).
    mkdir -p /usr/local/sbin/lib
    if [[ -d "$srcdir/scripts/lib" ]]; then
        install -m 0644 "$srcdir/scripts/lib/"*.sh /usr/local/sbin/lib/ 2>/dev/null
    fi

    # Install command scripts (strip .sh) into /usr/local/sbin so they are
    # callable by bare name. Exclude api/ and lib/.
    mkdir -p /usr/local/sbin/api
    find "$srcdir/scripts" -maxdepth 2 -type f -name '*.sh' \
         ! -path '*/api/*' ! -path '*/lib/*' | while read -r file; do
        name=$(basename "$file" .sh)
        install -m 0755 "$file" "/usr/local/sbin/$name"
    done

    # Install API command scripts (strip .sh) into /usr/local/sbin/api
    find "$srcdir/scripts/api" -maxdepth 1 -type f -name '*.sh' | while read -r file; do
        name=$(basename "$file" .sh)
        install -m 0755 "$file" "/usr/local/sbin/api/$name"
    done

    rm -rf "$tmpdir"
    print_success "Menu scripts and libraries integrated."
}

if [[ -f "/usr/local/sbin/menu" ]]; then
    print_warn "Menu scripts already exist."
    echo -e "1) Skip\n2) Update Menu"
    read -p "Select [1-2]: " menu_choice
    [[ "$menu_choice" == "2" ]] && menu_install_logic
else
    menu_install_logic
fi

# Initialize SQLite database (single source of truth) and migrate any legacy data.
print_info "Initializing account database (SQLite)..."
if [[ -f /usr/local/sbin/lib/db.sh ]]; then
    . /usr/local/sbin/lib/db.sh
    db_init
    # Import legacy .txt accounts if present (idempotent).
    if [[ -d /etc/xray/database ]] && [[ -x /usr/local/sbin/db-migrate ]]; then
        /usr/local/sbin/db-migrate >/dev/null 2>&1 || true
    fi
    print_success "Database initialized at /etc/xray/xray.db."
else
    print_error "Database library missing; menu may not function."
fi

# Ini firewall
print_info "Hardening Firewall (firewalld - strict allowlist)..."
dnf install firewalld -y >/dev/null 2>&1
systemctl enable firewalld --now >/dev/null 2>&1

# Ensure the default zone denies anything not explicitly allowed.
firewall-cmd --set-default-zone=public >/dev/null 2>&1
firewall-cmd --permanent --zone=public --set-target=default >/dev/null 2>&1

# Remove any previously-opened wide ranges (idempotent cleanup on re-run).
firewall-cmd --permanent --zone=public --remove-port=1-65535/tcp >/dev/null 2>&1
firewall-cmd --permanent --zone=public --remove-port=1-65535/udp >/dev/null 2>&1

# --- Allowlist: only the ports the stack actually uses ---
# SSH management
firewall-cmd --permanent --zone=public --add-port=22/tcp   >/dev/null 2>&1   # OpenSSH
firewall-cmd --permanent --zone=public --add-port=3303/tcp >/dev/null 2>&1   # OpenSSH (alt)
firewall-cmd --permanent --zone=public --add-port=109/tcp  >/dev/null 2>&1   # Dropbear
# Web / proxy entrypoints (HAProxy -> Nginx -> Xray)
firewall-cmd --permanent --zone=public --add-port=80/tcp   >/dev/null 2>&1   # HTTP
firewall-cmd --permanent --zone=public --add-port=443/tcp  >/dev/null 2>&1   # HTTPS/TLS
# BadVPN UDPGW
firewall-cmd --permanent --zone=public --add-port=7300/udp >/dev/null 2>&1
# OpenVPN
firewall-cmd --permanent --zone=public --add-port=1194/tcp >/dev/null 2>&1   # OpenVPN TCP
firewall-cmd --permanent --zone=public --add-port=2200/udp >/dev/null 2>&1   # OpenVPN UDP

firewall-cmd --reload >/dev/null 2>&1
print_success "Firewall locked down (allowlist only)."
print_info "Internal services (Xray API 10085, WebAPI 9000, nginx 81/444) remain bound to 127.0.0.1."

# Enterprise Sysctl Tuning
print_info "Applying Enterprise Network Tweak (BBR, High-Conn)..."
cat > /etc/sysctl.conf <<EOF
net.ipv4.ip_forward = 1
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_fastopen = 3
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.core.somaxconn = 65535
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.ipv4.tcp_low_latency = 1
EOF
sysctl -p >/dev/null 2>&1
print_success "Network stack optimized."

# Set Data Domain Server
print_header
echo -e "${LIGHT}Step 2: Server Identification${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
while true; do
    read -p "Input Domain Name: " domain
    if [[ -n "$domain" ]]; then break; else print_error "Domain cannot be empty."; fi
done
echo -e "$domain" > /etc/xray/domain
print_success "Domain set to: $domain"
sleep 1

# Install Dropbear 2019 on EL9
dropbear_install_logic() {
    print_info "Compiling Dropbear 2019.78 for Rocky Linux 9..."
    dnf groupinstall "Development Tools" -y >/dev/null 2>&1
    dnf install zlib-devel wget bzip2 -y >/dev/null 2>&1
    cd /usr/local/src
    wget -q --no-check-certificate https://matt.ucc.asn.au/dropbear/releases/dropbear-2019.78.tar.bz2 || \
    wget -q --no-check-certificate https://dropbear.nl/mirror/releases/dropbear-2019.78.tar.bz2
    tar xjf dropbear-2019.78.tar.bz2 >/dev/null 2>&1
    cd dropbear-2019.78
    ./configure --prefix=/usr --sysconfdir=/etc/dropbear >/dev/null 2>&1
    make -j$(nproc) >/dev/null 2>&1
    make install >/dev/null 2>&1
    cd ..
    rm -fr dropbear*

    cat >/etc/systemd/system/dropbear.service <<'EOF'
[Unit]
Description=Dropbear SSH Server
After=network.target

[Service]
Type=simple
ExecStart=/usr/sbin/dropbear -E -F -p 109 -b /etc/issue.net -r /etc/dropbear/dropbear_rsa_host_key -W 65536
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    mkdir -p /etc/dropbear
    [ -f /etc/dropbear/dropbear_rsa_host_key ] || dropbearkey -t rsa -f /etc/dropbear/dropbear_rsa_host_key >/dev/null 2>&1
    echo -e "Enterprise VPN Server" > /etc/issue.net
    systemctl daemon-reload
    systemctl enable dropbear --now >/dev/null 2>&1
    check_service dropbear
    print_success "Dropbear installed and running on port 109."
}

print_header
echo -e "${LIGHT}Step 3: Component Installation${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if systemctl is-active dropbear &>/dev/null; then
    print_success "Dropbear is already running."
else
    dropbear_install_logic
fi
clear
cd /root
rm -fr dropbear*

# Install Xray
xray_install_logic() {
    print_info "Synchronizing Xray-core release 25.10.15..."
    mkdir -p /usr/local/share/xray
    wget -q -O /usr/local/share/xray/geosite.dat "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat"
    wget -q -O /usr/local/share/xray/geoip.dat "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat"
    chmod +x /usr/local/share/xray/*
    
    # Write Structured Xray Configuration
    print_info "Generating secure Xray configuration..."
    uuid=$(cat /proc/sys/kernel/random/uuid)
    cat > /etc/xray/config.json <<EOF
{
  "log": {
    "access": "/var/log/xray/access.log",
    "loglevel": "info"
  },
  "api": {
    "tag": "api",
    "services": [
      "StatsService"
    ]
  },
  "stats": {},
  "policy": {
    "levels": {
      "0": {
        "statsUserDownlink": true,
        "statsUserUplink": true
      }
    },
    "system": {
      "statsInboundUplink": true,
      "statsInboundDownlink": true,
      "statsOutboundUplink": true,
      "statsOutboundDownlink": true
    }
  },
  "inbounds": [
    {
      "tag": "api",
      "listen": "127.0.0.1",
      "port": 10085,
      "protocol": "dokodemo-door",
      "settings": {
        "address": "127.0.0.1"
      }
    },
    {
      "tag": "vless-ws",
      "listen": "127.0.0.1",
      "port": 1,
      "protocol": "vless",
      "settings": {
        "decryption": "none",
        "clients": [
          {
            "id": "${uuid}"
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/vless"
        }
      }
    },
    {
      "tag": "trojan-ws",
      "listen": "127.0.0.1",
      "port": 2,
      "protocol": "trojan",
      "settings": {
        "clients": [
          {
            "password": "${uuid}"
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/trojan"
        }
      }
    },
    {
      "tag": "vmess-ws",
      "listen": "127.0.0.1",
      "port": 3,
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "${uuid}",
            "alterId": 0
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/vmess"
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct"
    },
    {
      "protocol": "blackhole",
      "tag": "blocked"
    }
  ],
  "routing": {
    "domainStrategy": "AsIs",
    "rules": [
      {
        "type": "field",
        "inboundTag": [
          "api"
        ],
        "outboundTag": "api"
      },
      {
        "type": "field",
        "outboundTag": "blocked",
        "protocol": [
          "bittorrent"
        ]
      },
      {
        "type": "field",
        "outboundTag": "blocked",
        "ip": [
          "0.0.0.0/8",
          "10.0.0.0/8",
          "100.64.0.0/10",
          "169.254.0.0/16",
          "172.16.0.0/12",
          "192.0.0.0/24",
          "192.0.2.0/24",
          "192.168.0.0/16",
          "198.18.0.0/15",
          "198.51.100.0/24",
          "203.0.113.0/24",
          "::1/128",
          "fc00::/7",
          "fe80::/10"
        ]
      }
    ]
  }
}
EOF

    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install -u nobody --version 25.10.15 >/dev/null 2>&1
    
    mkdir -p /var/log/xray
    touch /var/log/xray/{access,error}.log
    chown -R root:root /var/log/xray
    chmod 644 /var/log/xray/*.log

    cat > /etc/systemd/system/xray.service <<EOF
[Unit]
Description=Xray Service by risqinf
After=network.target nss-lookup.target

[Service]
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/usr/local/bin/xray -config /etc/xray/config.json
Restart=on-failure
LimitNPROC=10000
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable xray --now >/dev/null 2>&1
    check_service xray
    print_success "Xray Core initialized."
}

if [[ -f "/etc/xray/config.json" ]]; then
    print_warn "Xray core is already configured."
    echo -e "1) Skip\n2) Reinstall & Regenerate UUID"
    read -p "Select [1-2]: " xray_choice
    [[ "$xray_choice" == "2" ]] && xray_install_logic
else
    xray_install_logic
fi

# Nginx & Certificate Setup
print_info "Obtaining SSL Certificates (Let's Encrypt)..."
dnf install socat lsof certbot -y >/dev/null 2>&1
systemctl stop httpd nginx >/dev/null 2>&1
certbot certonly --standalone --preferred-challenges http --agree-tos --email www@${domain} -d $domain --non-interactive

# Verify the certificate was actually issued before continuing.
if [[ -f /etc/letsencrypt/live/$domain/fullchain.pem && -f /etc/letsencrypt/live/$domain/privkey.pem ]]; then
    cp /etc/letsencrypt/live/$domain/fullchain.pem /etc/xray/xray.crt
    cp /etc/letsencrypt/live/$domain/privkey.pem /etc/xray/xray.key
    chmod 644 /etc/xray/xray.crt
    chmod 600 /etc/xray/xray.key
    print_success "Certificates issued."
else
    print_error "Certificate issuance failed for ${domain}."
    print_error "Check that the domain points to this server's IP and port 80 is reachable."
    print_warn "Aborting installation. Re-run after fixing DNS/port 80."
    exit 1
fi

# Setup Nginx
nginx_install_logic() {
    print_info "Configuring Nginx Enterprise Node..."
    dnf install nginx -y >/dev/null 2>&1
    
    cat > /etc/nginx/nginx.conf <<EOF
user nginx;
worker_processes auto;
worker_cpu_affinity auto;
worker_rlimit_nofile 1048576;

events {
    worker_connections 1048576;
    multi_accept on;
    use epoll;
}

http {
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 300;
    keepalive_requests 10000;
    server_tokens off;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    access_log off;
    error_log /var/log/nginx/error.log crit;

    set_real_ip_from 127.0.0.1;
    real_ip_header proxy_protocol;

    include /etc/nginx/risqinf.conf;
}
EOF

    cat > /etc/nginx/risqinf.conf <<EOF
upstream vmess_ws {
    server 127.0.0.1:3;
    keepalive 32;
}

upstream ssh_ws {
    server 127.0.0.1:8888;
    keepalive 32;
}

upstream vless_ws {
    server 127.0.0.1:1;
    keepalive 32;
}

upstream trojan_ws {
    server 127.0.0.1:2;
    keepalive 32;
}

server {
    listen 127.0.0.1:81 default_server proxy_protocol;
    listen 127.0.0.1:444 ssl http2 default_server proxy_protocol;

    server_name ${domain};

    ssl_certificate /etc/xray/xray.crt;
    ssl_certificate_key /etc/xray/xray.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    location / {
        if (\$http_upgrade != "Websocket") {
            rewrite /(.*) / break;
        }
        proxy_pass http://vmess_ws;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$http_host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_buffering off;
        error_page 400 403 500 502 503 504 = @ssh_ws;
    }

    location @ssh_ws {
        proxy_pass http://ssh_ws;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$http_host;
        proxy_buffering off;
    }

    location ~ /(vless|trojan|ssh) {
        proxy_pass http://\$1_ws;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$http_host;
        proxy_buffering off;
    }

    location /risqinf/ {
        alias /var/www/html/;
        autoindex on;
    }

    location /api/ {
        proxy_pass http://127.0.0.1:9000/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}
EOF
    systemctl daemon-reload
    systemctl enable nginx --now >/dev/null 2>&1
    check_service nginx
    print_success "Nginx Enterprise Node optimized."
}

if [[ -f "/etc/nginx/risqinf.conf" ]]; then
    print_warn "Nginx is already configured."
    echo -e "1) Skip\n2) Overwrite"
    read -p "Select [1-2]: " nginx_choice
    [[ "$nginx_choice" == "2" ]] && nginx_install_logic
else
    nginx_install_logic
fi

# Setup HAProxy
haproxy_install_logic() {
    print_info "Configuring HAProxy Enterprise Balancing..."
    dnf install haproxy -y >/dev/null 2>&1
    
    # Generate combined certificate for HAProxy
    mkdir -p /etc/haproxy
    cat /etc/xray/xray.crt /etc/xray/xray.key | tee /etc/haproxy/haproxy.pem > /dev/null
    chmod 600 /etc/haproxy/haproxy.pem

    cat > /etc/haproxy/haproxy.cfg <<EOF
global
    log /dev/log local0
    maxconn 100000
    user haproxy
    group haproxy
    daemon

defaults
    log global
    mode tcp
    timeout connect 5s
    timeout client 30m
    timeout server 30m

frontend main_entry
    bind *:80
    bind *:443 ssl crt /etc/haproxy/haproxy.pem
    tcp-request inspect-delay 5s
    tcp-request content accept if { req_ssl_hello_type 1 }
    use_backend nginx_https if { req_ssl_hello_type 1 }
    default_backend nginx_http

backend nginx_http
    mode tcp
    server nginx_node 127.0.0.1:81 send-proxy check

backend nginx_https
    mode tcp
    server nginx_ssl_node 127.0.0.1:444 send-proxy check
EOF
    systemctl enable haproxy --now >/dev/null 2>&1
    check_service haproxy
    print_success "HAProxy Balancing complete."
}

if [[ -f "/etc/haproxy/haproxy.cfg" ]]; then
    print_warn "HAProxy is already configured."
    echo -e "1) Skip\n2) Overwrite"
    read -p "Select [1-2]: " haproxy_choice
    [[ "$haproxy_choice" == "2" ]] && haproxy_install_logic
else
    haproxy_install_logic
fi

# Setup Crontab
dnf install cronie -y

# Auto-expire (DB-driven), backup, log rotation, and SSH IP-limit enforcement.
# VLESS/VMESS/Trojan quota & IP-limit run as looping systemd services (below),
# so they are intentionally NOT in cron.
echo "* * * * * root xp-ssh" >> /etc/crontab
echo "* * * * * root xp-vless" >> /etc/crontab
echo "* * * * * root xp-vmess" >> /etc/crontab
echo "* * * * * root xp-trojan" >> /etc/crontab
echo "*/2 * * * * root limit-ip-ssh" >> /etc/crontab
echo "0 * * * * root backup" >> /etc/crontab
echo "0 0 * * * root fixlog" >> /etc/crontab

# restart service
systemctl daemon-reload
systemctl enable crond --now
systemctl restart crond

# Install Package Lain
curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.rpm.sh | sudo bash
sudo dnf install speedtest -y

# Setup Limit IP & Quota Services
cat > /etc/systemd/system/quota.service <<EOF
[Unit]
Description=Vless Quota Looping
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/sbin/loop-quota-vless
Restart=on-failure
RestartSec=10
User=root

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/limit-ip-vless.service <<EOF
[Unit]
Description=Vless Limit IP Looping
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/sbin/loop-ip-vless
Restart=on-failure
RestartSec=10
User=root

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/quota-trojan.service <<EOF
[Unit]
Description=Trojan Quota Looping
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/sbin/loop-quota-trojan
Restart=on-failure
RestartSec=10
User=root

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/limit-ip-trojan.service <<EOF
[Unit]
Description=Trojan Limit IP Looping
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/sbin/loop-ip-trojan
Restart=on-failure
RestartSec=10
User=root

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/quota-vmess.service <<EOF
[Unit]
Description=Vmess Quota Looping
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/sbin/loop-quota-vmess
Restart=on-failure
RestartSec=10
User=root

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/limit-ip-vmess.service <<EOF
[Unit]
Description=Vmess Limit IP Looping
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/sbin/loop-ip-vmess
Restart=on-failure
RestartSec=10
User=root

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable quota limit-ip-vless --now
systemctl enable quota-trojan limit-ip-trojan --now
systemctl enable quota-vmess limit-ip-vmess --now
for svc in quota limit-ip-vless quota-trojan limit-ip-trojan quota-vmess limit-ip-vmess; do
    check_service "$svc" || print_warn "Looping service '$svc' not active (will retry via Restart=on-failure)."
done

# Api Server
# NOTE: The RESTful API server is being rebuilt from scratch and is not yet
# available. This sets up the directory and systemd unit, but the server
# binary is intentionally not installed or enabled here.
api_server_install_logic() {
    mkdir -p /etc/api
    mkdir -p /usr/local/sbin/api

    # Configure WebAPI Server Service (disabled until the server is rebuilt)
    cat > /etc/systemd/system/server.service <<EOF
[Unit]
Description=WebAPI Server Proxy by risqinf
Documentation=https://github.com/risqinf/autoscript
After=syslog.target network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=/usr/local/sbin/api
ExecStart=/usr/local/bin/server
Restart=on-failure
RestartPreventExitStatus=23
RestartSec=5
TimeoutStopSec=30
KillSignal=SIGTERM

# Performance Tuning
LimitNPROC=10000
LimitNOFILE=1000000

# Security & Sandboxing
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=full
ProtectHome=yes
ProtectKernelTunables=yes
ProtectKernelModules=yes
ProtectControlGroups=yes
ReadWritePaths=/var/log /usr/local/sbin/api /etc/api /etc/xray /tmp /var/tmp

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    print_warn "WebAPI server binary not installed (to be rebuilt). Service unit prepared but not started."
}

if [[ -f "/usr/local/bin/server" ]]; then
    echo -e "\e[32m[SKIP]\e[0m WebAPI Server is already installed."
    echo -e "1) Skip"
    echo -e "2) Reinstall"
    read -p "Select [1-2]: " api_choice
    [[ "$api_choice" == "2" ]] && api_server_install_logic
else
    api_server_install_logic
fi

clear
echo -e "clear ; menu" > /root/.profile

# Dynamic Swap Management (KVM Optimized)
swap_install_logic() {
    echo -e "———————————————————————————————————————————————————————"
    echo -e "            CONFIGURING DYNAMIC SWAP"
    echo -e "———————————————————————————————————————————————————————"

    # Detection: KVM Check
    VIRT=$(hostnamectl status | grep "Virtualization" | awk '{print $2}')
    if [[ "$VIRT" != "kvm" ]]; then
        echo -e "\e[33m[SKIP]\e[0m Virtualization is $VIRT (Not KVM). Skipping swap optimization."
    else
        # Calculate Swap Size based on Disk Space
        # FREE_DISK in KB
        FREE_DISK=$(df -k / | awk 'NR==2 {print $4}')
        
        if [ "$FREE_DISK" -gt 41943040 ]; then   # > 40GB free -> 8GB Swap
            SWAP_SIZE_GB=8
        elif [ "$FREE_DISK" -gt 20971520 ]; then # > 20GB free -> 4GB Swap
            SWAP_SIZE_GB=4
        elif [ "$FREE_DISK" -gt 10485760 ]; then # > 10GB free -> 2GB Swap
            SWAP_SIZE_GB=2
        else
            SWAP_SIZE_GB=0
        fi

        if [ "$SWAP_SIZE_GB" -gt 0 ]; then
            echo -e "\e[32m[INFO]\e[0m Disk space sufficient. Creating ${SWAP_SIZE_GB}GB Swapfile..."
            
            # Cleanup Old Swap
            swapoff -a >/dev/null 2>&1
            sed -i '/swapfile/d' /etc/fstab >/dev/null 2>&1
            rm -f /swapfile >/dev/null 2>&1

            # Create Swapfile
            if command -v fallocate >/dev/null 2>&1; then
                fallocate -l ${SWAP_SIZE_GB}G /swapfile
            else
                dd if=/dev/zero of=/swapfile bs=1M count=$((SWAP_SIZE_GB * 1024))
            fi

            chmod 600 /swapfile
            mkswap /swapfile >/dev/null 2>&1
            swapon /swapfile >/dev/null 2>&1
            echo "/swapfile none swap defaults 0 0" >> /etc/fstab

            # Enterprise Kernel Tuning
            sysctl -w vm.swappiness=60 >/dev/null 2>&1
            echo "vm.swappiness=60" >> /etc/sysctl.conf

            # Optional: Stress test activation (Enterprise minimal)
            if dnf list installed stress-ng >/dev/null 2>&1; then
                stress-ng --vm 1 --vm-bytes 1G --timeout 5s >/dev/null 2>&1
            fi
            
            echo -e "\e[32m[OK]\e[0m ${SWAP_SIZE_GB}GB Swap activated successfully."
        else
            echo -e "\e[31m[WARN]\e[0m Disk space too low for optimized swap."
        fi
    fi
    echo -e "———————————————————————————————————————————————————————"
}

if [[ -f "/swapfile" ]]; then
    echo -e "\e[32m[SKIP]\e[0m Swapfile is already configured."
else
    swap_install_logic
fi

# Backup Setup (Google Drive via rclone)
# NOTE: No credentials are shipped. Configure your own remote interactively.
curl https://rclone.org/install.sh | bash
if [[ ! -f /root/.config/rclone/rclone.conf ]]; then
    print_warn "rclone is installed but no remote is configured."
    print_info "Run 'rclone config' to add your Google Drive remote (name it 'risqinf')."
fi
cd /root

# Setup OpenVPN
WEB_DIR="/var/www/html/risqinf/openvpn"
EASYRSA_DIR="/etc/openvpn/easy-rsa"
ovpn_install_logic() {
    echo "=================================================="
    echo "INSTALLING OPENVPN..."
    echo "=================================================="
    WEB_DIR="/var/www/html/risqinf/openvpn"
    EASYRSA_DIR="/etc/openvpn/easy-rsa"
    dnf install -y openvpn easy-rsa iptables-services
    mkdir -p $WEB_DIR
    mkdir -p $EASYRSA_DIR
    mkdir -p /etc/openvpn/server
    cp -r /usr/share/easy-rsa/3/* $EASYRSA_DIR/
    cd $EASYRSA_DIR

    ./easyrsa init-pki
    ./easyrsa build-ca nopass
    ./easyrsa gen-req server nopass
    ./easyrsa sign-req server server
    ./easyrsa gen-dh
    openvpn --genkey secret ta.key

    cp pki/ca.crt pki/issued/server.crt pki/private/server.key pki/dh.pem ta.key /etc/openvpn/server/
    PLUGIN_PAM="/usr/lib64/openvpn/plugins/openvpn-plugin-auth-pam.so"

    # UDP Server Config
    cat > /etc/openvpn/server/server-udp-2200.conf <<EOF
port 2200
proto udp
dev tun
ca ca.crt
cert server.crt
key server.key
dh dh.pem
tls-auth ta.key 0
topology subnet
server 10.8.0.0 255.255.255.0
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 1.1.1.1"
fast-io
sndbuf 1048576
rcvbuf 1048576
push "sndbuf 1048576"
push "rcvbuf 1048576"
txqueuelen 2000
tun-mtu 1360
mssfix 1320
keepalive 10 30
comp-lzo no
push "comp-lzo no"
cipher none
auth none
data-ciphers none
plugin $PLUGIN_PAM login
verify-client-cert none
username-as-common-name
persist-key
persist-tun
status openvpn-status-udp.log
verb 3
EOF

    # TCP Server Config
    cat > /etc/openvpn/server/server-tcp-1194.conf <<EOF
port 1194
proto tcp
dev tun
ca ca.crt
cert server.crt
key server.key
dh dh.pem
tls-auth ta.key 0
topology subnet
server 10.9.0.0 255.255.255.0
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 1.1.1.1"
socket-flags TCP_NODELAY
push "socket-flags TCP_NODELAY"
keepalive 10 120
comp-lzo no
push "comp-lzo no"
cipher AES-128-GCM
data-ciphers AES-128-GCM:AES-256-GCM
auth SHA256
plugin $PLUGIN_PAM login
verify-client-cert none
username-as-common-name
persist-key
persist-tun
status openvpn-status-tcp.log
verb 3
EOF

    CA_DATA=$(cat /etc/openvpn/server/ca.crt)
    TA_DATA=$(cat /etc/openvpn/server/ta.key)

    # Client OVPN Generation
    cat > $WEB_DIR/udp.ovpn <<EOF
client
dev tun
proto udp
remote $domain 2200
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
key-direction 1
setenv CLIENT_CERT 0
setenv FRIENDLY_NAME "OpenVPN UDP"
fast-io
tun-mtu 1360
mssfix 1320
cipher none
auth none
data-ciphers none
auth-user-pass
comp-lzo no
verb 3
<ca>
$CA_DATA
</ca>
<tls-auth>
$TA_DATA
</tls-auth>
EOF

    cat > $WEB_DIR/tcp.ovpn <<EOF
client
dev tun
proto tcp
remote $domain 1194
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
key-direction 1
setenv CLIENT_CERT 0
setenv FRIENDLY_NAME "OpenVPN TCP"
socket-flags TCP_NODELAY
cipher AES-128-GCM
auth SHA256
auth-user-pass
comp-lzo no
verb 3
<ca>
$CA_DATA
</ca>
<tls-auth>
$TA_DATA
</tls-auth>
EOF

    # Routing & Firewall
    echo 1 > /proc/sys/net/ipv4/ip_forward
    sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf
    sysctl -p
    firewall-cmd --zone=public --add-port=2200/udp --permanent
    firewall-cmd --zone=public --add-port=1194/tcp --permanent
    firewall-cmd --add-masquerade --permanent
    firewall-cmd --reload

    systemctl enable openvpn-server@server-udp-2200
    systemctl enable openvpn-server@server-tcp-1194
    systemctl restart openvpn-server@server-udp-2200
    systemctl restart openvpn-server@server-tcp-1194
    check_service "openvpn-server@server-udp-2200" || print_warn "OpenVPN UDP not active."
    check_service "openvpn-server@server-tcp-1194" || print_warn "OpenVPN TCP not active."
}

if [[ -f "/etc/openvpn/server/server-tcp-1194.conf" ]]; then
    # OpenVPN configuration is complex, we just check for file existence
    # but we can check if the domain matches in the generated files.
    if grep -q "$domain" "$WEB_DIR/tcp.ovpn" 2>/dev/null; then
        echo -e "\e[32m[SKIP]\e[0m OpenVPN is already installed and matches current domain."
    else
        ovpn_install_logic
    fi
else
    ovpn_install_logic
fi

clear
# Notification
echo -e " Script Success Install"
rm -fr *.sh
