#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: AutoScript VPN & Tunneling Management System
# Developed for Rocky Linux 9
# ========================================================
# ========================================================
# Author: risqinf
# License: Apache License 2.0 (see LICENSE file)
# Repository: https://github.com/risqinf/autoscript
# ========================================================

clear

# Variabel Waktu
tanggal=$(date +"%m-%d-%Y")
waktu=$(date +"%H-%M-%S")  # Menggunakan format waktu yang aman untuk nama file
random_code=$(openssl rand -hex 4)  # Menghasilkan 4 byte (8 karakter heksadesimal)
zip_file="/root/backup-${tanggal}-${waktu}-${random_code}.zip"
backup_dir="/root/backup"
bot_token_file="/etc/xray/bot.key"
chat_id_file="/etc/xray/client.id"
USERNAME="risqinf"
PASSWORD="risqinf"

# Autentikasi dan Informasi Server
domain=$(cat /etc/xray/domain 2>/dev/null || echo "Unknown")
ipsaya=$(curl -s http://checkip.amazonaws.com)
asn_info=$(timeout 5 curl -s "http://ip-api.com/json/$ipsaya" | jq -r '.isp // "Unknown ISP"')

# Fungsi Warna Output
green() { echo -e "\\033[32;1m${*}\\033[0m"; }
red() { echo -e "\\033[31;1m${*}\\033[0m"; }
yellow() { echo -e "\\033[33;1m${*}\\033[0m"; }

# Fungsi untuk memvalidasi file konfigurasi
validate_config_files() {
    local missing_files=()
    
    # Cek file bot token
    if [[ ! -f "$bot_token_file" ]] || [[ ! -s "$bot_token_file" ]]; then
        missing_files+=("Bot Token")
        echo -e "$(red "❌ File bot token tidak ditemukan atau kosong: $bot_token_file")"
    else
        botToken=$(cat "$bot_token_file")
        # Validasi format bot token (harus mengandung angka dan huruf)
        if ! echo "$botToken" | grep -qE '[0-9]+:[a-zA-Z0-9_-]+'; then
            echo -e "$(red "❌ Format bot token tidak valid")"
            missing_files+=("Bot Token")
        fi
    fi
    
    # Cek file chat ID
    if [[ ! -f "$chat_id_file" ]] || [[ ! -s "$chat_id_file" ]]; then
        missing_files+=("Chat ID")
        echo -e "$(red "❌ File chat ID tidak ditemukan atau kosong: $chat_id_file")"
    else
        chatId=$(cat "$chat_id_file")
        # Validasi format chat ID (harus angka)
        if ! echo "$chatId" | grep -qE '^-?[0-9]+$'; then
            echo -e "$(red "❌ Format chat ID tidak valid")"
            missing_files+=("Chat ID")
        fi
    fi
    
    # Jika ada file yang missing, minta input dari user
    if [[ ${#missing_files[@]} -gt 0 ]]; then
        echo -e "\n$(yellow "⚠️  File konfigurasi berikut tidak ditemukan atau kosong:")"
        printf '%s\n' "${missing_files[@]}"
        echo -e "\n$(yellow "Silakan isi informasi berikut:")"
        
        for item in "${missing_files[@]}"; do
            case "$item" in
                "Bot Token")
                    echo -e "$(yellow "Masukkan Bot Token Telegram:")"
                    read -r botToken
                    if [[ -n "$botToken" ]]; then
                        # Buat direktori jika belum ada
                        mkdir -p "/etc/xray"
                        echo "$botToken" > "$bot_token_file"
                        chmod 600 "$bot_token_file"
                        echo -e "$(green "✅ Bot Token disimpan ke $bot_token_file")"
                    else
                        echo -e "$(red "❌ Bot Token tidak boleh kosong!")"
                        exit 1
                    fi
                    ;;
                "Chat ID")
                    echo -e "$(yellow "Masukkan Chat ID Telegram:")"
                    read -r chatId
                    if [[ -n "$chatId" ]]; then
                        # Buat direktori jika belum ada
                        mkdir -p "/etc/xray"
                        echo "$chatId" > "$chat_id_file"
                        chmod 600 "$chat_id_file"
                        echo -e "$(green "✅ Chat ID disimpan ke $chat_id_file")"
                    else
                        echo -e "$(red "❌ Chat ID tidak boleh kosong!")"
                        exit 1
                    fi
                    ;;
            esac
        done
    else
        # Jika file ada dan valid, baca nilainya
        botToken=$(cat "$bot_token_file")
        chatId=$(cat "$chat_id_file")
        echo -e "$(green "✅ File konfigurasi ditemukan dan valid")"
    fi
}

# Fungsi untuk test koneksi Telegram
test_telegram_connection() {
    echo -e "$(yellow "Menguji koneksi ke Telegram...")"
    local response
    response=$(curl -s -w "%{http_code}" "https://api.telegram.org/bot${botToken}/getMe")
    local status_code="${response: -3}"
    
    if [[ "$status_code" == "200" ]]; then
        echo -e "$(green "✅ Koneksi Telegram berhasil")"
        return 0
    else
        echo -e "$(red "❌ Gagal terhubung ke Telegram. Status code: $status_code")"
        echo -e "$(yellow "Periksa kembali Bot Token dan pastikan bot sudah aktif.")"
        return 1
    fi
}

# Fungsi untuk mengirim file ke Telegram
send_file_to_telegram() {
    local file_path="$1"
    local caption="$2"
    
    echo -e "$(yellow "Mengirim file ke Telegram...")"
    
    # Cek ukuran file
    local file_size=$(stat -c%s "$file_path" 2>/dev/null || stat -f%z "$file_path")
    local max_size=$((50 * 1024 * 1024))  # 50MB batas maksimal Telegram
    
    if [[ $file_size -gt $max_size ]]; then
        echo -e "$(red "❌ File terlalu besar ($((file_size/1024/1024))MB). Batas maksimal Telegram adalah 50MB.")"
        return 1
    fi
    
    # Kirim file menggunakan API Telegram
    local response
    response=$(curl -s -F "chat_id=${chatId}" \
                    -F "caption=${caption}" \
                    -F "parse_mode=Markdown" \
                    -F "document=@${file_path}" \
                    "https://api.telegram.org/bot${botToken}/sendDocument")
    
    # Cek apakah pengiriman berhasil
    if echo "$response" | grep -q '"ok":true'; then
        echo -e "$(green "✅ File berhasil dikirim ke Telegram")"
        return 0
    else
        echo -e "$(red "❌ Gagal mengirim file ke Telegram")"
        echo -e "$(yellow "Response: $response")"
        return 1
    fi
}

# Validasi file konfigurasi
echo -e "$(green "Memulai validasi konfigurasi...")"
validate_config_files

# Test koneksi Telegram
if ! test_telegram_connection; then
    echo -e "$(red "Gagal terhubung ke Telegram. Script dihentikan.")"
    exit 1
fi

echo -e "$(green "Memulai Backup")"
sleep 1

# Buat Direktori Backup
rm -rf "$backup_dir"
mkdir -p "$backup_dir"

# Salin File yang Akan Dibackup
sleep 1
echo Start Backup 2>/dev/null
rm -rf /root/backup 2>/dev/null
mkdir /root/backup 2>/dev/null
cp /etc/passwd /root/backup/ &> /dev/null
cp /etc/group /root/backup/ &> /dev/null
cp /etc/shadow /root/backup/ &> /dev/null
cp /etc/gshadow /root/backup/ &> /dev/null
cp -r /etc/xray/ /root/backup/xray 2>/dev/null
mkdir -p /root/backup/noobzvpns
cd /root

# Buat File ZIP dengan Password
echo -e "$(yellow "Membuat file backup terenkripsi...")"
zip -rP "$PASSWORD" "$zip_file" "backup"

if [[ ! -f "$zip_file" ]]; then
    echo -e "$(red "Gagal membuat file ZIP.")"
    exit 1
fi

# Buat caption untuk Telegram
caption="✅ *Backup Berhasil!*

📁 *File Backup:* \`$(basename "$zip_file")\`

🖥 *Informasi Server:*
┣ 📛 **Nama Pengguna:** $USERNAME
┣ 🌐 **Domain:** $domain
┣ 🏢 **ISP:** $asn_info
┣ 🌍 **IP VPS:** \`$ipsaya\`
┣ ⏰ **Waktu Backup:** $tanggal pukul $waktu
┣ 🔑 **Kode Unik:** $random_code
┣ 🔒 **Password:** \`$PASSWORD\`
┗━━━━━━━━━━━━━━━━━

📊 *Detail Backup:*
┣ 📅 **Tanggal:** $tanggal
┣ 🕐 **Waktu:** $waktu
┣ 🆔 **Kode Unik:** $random_code
┗ 🔐 **Password:** $PASSWORD

🔒 *Keamanan: File backup dilindungi dengan password.*  
🔄 *Proses backup ini dilakukan secara otomatis untuk menjaga data Anda tetap aman.*

✨ *Terima kasih telah menggunakan layanan kami!*"

# Kirim file langsung ke Telegram
if send_file_to_telegram "$zip_file" "$caption"; then
    echo -e "$(green "✅ Backup berhasil dikirim ke Telegram")"
else
    echo -e "$(red "❌ Gagal mengirim backup ke Telegram")"
    # Tampilkan informasi meskipun gagal kirim
fi

# Tampilkan detail backup di CLI
clear
echo -e "\n$(green "Backup selesai.")"
echo -e "$(green "Detail Backup:")"
echo -e "📁 File Backup: $(basename "$zip_file")"
echo -e "🖥 Informasi Server:"
echo -e "┣ 📛 Nama Pengguna: $USERNAME"
echo -e "┣ 🌐 Domain: $domain"
echo -e "┣ 🏢 ISP: $asn_info"
echo -e "┣ 🌍 IP VPS: $ipsaya"
echo -e "┣ ⏰ Waktu Backup: $tanggal pukul $waktu"
echo -e "┣ 🔑 Kode Unik: $random_code"
echo -e "┣ 🔒 Password: $PASSWORD"
echo -e "┗━━━━━━━━━━━━━━━━━"
echo -e "📊 Detail Backup:"
echo -e "┣ 📅 Tanggal: $tanggal"
echo -e "┣ 🕐 Waktu: $waktu"
echo -e "┣ 🆔 Kode Unik: $random_code"
echo -e "┗ 🔐 Password: $PASSWORD"
echo -e "🔒 Keamanan: File backup dilindungi dengan password."
echo -e "🔄 Proses backup ini dilakukan secara otomatis untuk menjaga data Anda tetap aman."

# Bersihkan file temporary
rm -f "$zip_file"
rm -rf "$backup_dir"

echo -e "\n$(green "✅ Proses backup selesai!")"