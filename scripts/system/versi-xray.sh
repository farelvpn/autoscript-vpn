#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: AutoScript VPN & Tunneling Management System
# Developed for Rocky Linux 9
# ========================================================
# ========================================================
# XRAY CORE VERSION CHANGER
# ========================================================

clear
NC='\033[0m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BICyan='\033[1;96m'
BIWhite='\033[1;97m'

echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"
echo -e "\e[0;41;36m                 XRAY CORE VERSION CHANGER                  \e[0m"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"

# Check current Xray location
xray_path=$(which xray 2>/dev/null)
if [[ -z "$xray_path" ]]; then
    echo -e "${RED}Error: Xray not found in system!${NC}"
    echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"
    read -n 1 -s -r -p "Press any key to return to menu..."
    menu
    exit 1
fi

echo -e "${BIWhite}Current Xray Location:${NC} ${GREEN}$xray_path${NC}"

# Check architecture
architecture=$(uname -m)
case $architecture in
    x86_64)
        arch="64"
        ;;
    aarch64)
        arch="arm64-v8a"
        ;;
    armv7l)
        arch="arm32-v7a"
        ;;
    *)
        echo -e "${RED}Unsupported architecture: $architecture${NC}"
        echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"
        read -n 1 -s -r -p "Press any key to return to menu..."
        menu
        exit 1
        ;;
esac

echo -e "${BIWhite}System Architecture :${NC} ${GREEN}$architecture${NC}"
echo -e "${BIWhite}Download Architecture:${NC} ${GREEN}$arch${NC}"

# Get current version
current_version=$($xray_path version | head -1 | awk '{print $2}')
echo -e "${BIWhite}Current Version     :${NC} ${GREEN}$current_version${NC}"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"

# Display available versions (confirmed from GitHub releases)
echo -e "${BICyan}Available Xray Core Versions:${NC}"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"
echo -e "1.  Xray v1.8.4    (Stable)"
echo -e "2.  Xray v1.8.5    (Stable)"
echo -e "3.  Xray v1.8.6    (Stable)"
echo -e "4.  Xray v1.8.9    (Stable)"
echo -e "5.  Xray v1.8.10   (Stable)"
echo -e "6.  Xray v1.8.12   (Stable)"
echo -e "7.  Xray v1.8.15   (Stable)"
echo -e "8.  Xray v1.8.20   (Stable)"
echo -e "9.  Xray v1.8.25   (Stable)"
echo -e "10. Xray v25.3.6   (Latest Stable)"  # Based on search result [[1]]
echo -e "11. Xray v25.7.24  (Recent)"
echo -e "12. Xray v25.7.25  (Recent)"
echo -e "13. Xray v25.7.26  (Recent)"  # Based on search result [[4]]
echo -e "14. Xray v25.8.3   (Latest)"  # Based on search result [[4]]
echo -e "15. Custom Version (Enter manually)"
echo -e "0.  Cancel"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"

read -rp "Select version (0-15): " choice

case $choice in
    1)
        version="v1.8.4"
        ;;
    2)
        version="v1.8.5"
        ;;
    3)
        version="v1.8.6"
        ;;
    4)
        version="v1.8.9"
        ;;
    5)
        version="v1.8.10"
        ;;
    6)
        version="v1.8.12"
        ;;
    7)
        version="v1.8.15"
        ;;
    8)
        version="v1.8.20"
        ;;
    9)
        version="v1.8.25"
        ;;
    10)
        version="v25.3.6"
        ;;
    11)
        version="v25.7.24"
        ;;
    12)
        version="v25.7.25"
        ;;
    13)
        version="v25.7.26"
        ;;
    14)
        version="v25.8.3"
        ;;
    15)
        echo ""
        read -rp "Enter version (e.g., v1.8.9 or v25.8.3): " version
        if [[ -z "$version" ]]; then
            echo -e "${RED}Version cannot be empty!${NC}"
            echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"
            read -n 1 -s -r -p "Press any key to return to menu..."
            menu
            exit 1
        fi
        # Validate version format
        if [[ ! "$version" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo -e "${RED}Invalid version format! Please use format: v1.8.9${NC}"
            echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"
            read -n 1 -s -r -p "Press any key to return to menu..."
            menu
            exit 1
        fi
        ;;
    0|*)
        echo -e "${YELLOW}Operation cancelled.${NC}"
        echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"
        read -n 1 -s -r -p "Press any key to return to menu..."
        menu
        exit 0
        ;;
esac

echo ""
echo -e "${BIWhite}Selected Version:${NC} ${GREEN}$version${NC}"

# Confirmation
echo ""
read -rp $'\e[1;31mAre you sure you want to update Xray core? (y/N): \e[0m' confirm

if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Operation cancelled.${NC}"
    echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"
    read -n 1 -s -r -p "Press any key to return to menu..."
    menu
    exit 0
fi

echo ""
echo -e "${YELLOW}Stopping Xray service...${NC}"
systemctl stop xray.service

# Backup current core
echo -e "${YELLOW}Backing up current Xray core...${NC}"
cp "$xray_path" "${xray_path}.backup"

# Download new version
echo -e "${YELLOW}Downloading Xray $version for $architecture...${NC}"
temp_dir="/tmp/xray-update"
mkdir -p "$temp_dir"

download_url="https://github.com/XTLS/Xray-core/releases/download/$version/Xray-linux-$arch.zip"
wget -O "$temp_dir/xray.zip" "$download_url" 2>/dev/null

if [[ $? -ne 0 ]]; then
    echo -e "${RED}Failed to download Xray $version!${NC}"
    echo -e "${YELLOW}Restoring backup...${NC}"
    mv "${xray_path}.backup" "$xray_path"
    systemctl start xray.service
    rm -rf "$temp_dir"
    echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"
    read -n 1 -s -r -p "Press any key to return to menu..."
    menu
    exit 1
fi

# Extract and replace
echo -e "${YELLOW}Extracting and installing new core...${NC}"
unzip -o "$temp_dir/xray.zip" -d "$temp_dir" >/dev/null 2>&1
chmod +x "$temp_dir/xray"

# Replace core
mv "$temp_dir/xray" "$xray_path"

# Cleanup
rm -rf "$temp_dir"
rm -f "${xray_path}.backup"

# Start service
echo -e "${YELLOW}Starting Xray service...${NC}"
systemctl start xray.service

# Verify installation
new_version=$($xray_path version | head -1 | awk '{print $2}')
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"
if [[ "$new_version" == *"$version"* ]]; then
    echo -e "${GREEN}SUCCESS:${NC} ${BIWhite}Xray core updated to ${GREEN}$new_version${NC}"
    echo -e "${BIWhite}Previous Version:${NC} ${RED}$current_version${NC}"
    echo -e "${BIWhite}Current Version :${NC} ${GREEN}$new_version${NC}"
else
    echo -e "${YELLOW}WARNING:${NC} ${BIWhite}Version verification failed${NC}"
    echo -e "${BIWhite}Expected Version:${NC} ${GREEN}$version${NC}"
    echo -e "${BIWhite}Current Version :${NC} ${GREEN}$new_version${NC}"
fi

echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"
echo -e "${GREEN}✓${NC} ${BIWhite}Config.json preserved${NC}"
echo -e "${GREEN}✓${NC} ${BIWhite}Service configuration preserved${NC}"
echo -e "${GREEN}✓${NC} ${BIWhite}Log files preserved${NC}"
echo -e "${GREEN}✓${NC} ${BIWhite}Only core binary replaced${NC}"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"

read -n 1 -s -r -p "Press any key to return to menu..."
menu