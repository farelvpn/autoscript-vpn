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

# Direktori kerja
backup_dir="/root"

# Backup encryption password: read from secure store, else prompt the user.
backup_pass_file="/etc/xray/backup.pass"
if [[ -s "$backup_pass_file" ]]; then
    PASSWORD=$(cat "$backup_pass_file")
else
    read -rsp "Enter backup encryption password: " PASSWORD; echo
    if [[ -z "$PASSWORD" ]]; then
        echo "Backup password cannot be empty."
        exit 1
    fi
fi

# Fungsi warna output
green() { echo -e "\\033[32;1m${*}\\033[0m"; }
red() { echo -e "\\033[31;1m${*}\\033[0m"; }
yellow() { echo -e "\\033[33;1m${*}\\033[0m"; }
export NC='\033[0m'

# Fungsi untuk mencari file backup
find_backup_file() {
    local backup_files=($(ls $backup_dir/backup-*.zip 2>/dev/null))
    
    if [[ ${#backup_files[@]} -eq 0 ]]; then
        return 1
    fi
    
    # Urutkan file berdasarkan waktu modifikasi (terbaru pertama)
    IFS=$'\n' sorted_files=($(ls -t $backup_dir/backup-*.zip 2>/dev/null))
    unset IFS
    
    echo "${sorted_files[0]}"
    return 0
}

# Fungsi untuk menampilkan header
show_header() {
    clear
    echo "========================================================"
    echo "               SCRIPT RESTORE BACKUP"
    echo "          Author: risqinf"
    echo "========================================================"
    echo
}

# Fungsi untuk validasi file ZIP
validate_zip_file() {
    local zip_file="$1"
    
    if [[ ! -f "$zip_file" ]]; then
        echo -e "$(red "❌ File backup tidak ditemukan: $zip_file")"
        return 1
    fi
    
    # Cek apakah file adalah ZIP yang valid
    if ! unzip -t -P "$PASSWORD" "$zip_file" &>/dev/null; then
        echo -e "$(red "❌ File ZIP tidak valid atau password salah")"
        return 1
    fi
    
    echo -e "$(green "✅ File backup valid: $(basename "$zip_file")")"
    return 0
}

# Main process
show_header
echo -e "$(green "Memulai proses restore...")"
echo

# Cek file backup lokal
echo -e "$(yellow "🔍 Mencari file backup di folder /root...")"
backup_file=$(find_backup_file)

if [[ -n "$backup_file" ]]; then
    echo -e "$(green "✅ File backup ditemukan: $(basename "$backup_file")")"
    echo
    echo -e "$(yellow "📋 Detail file backup:")"
    echo -e "   Nama File: $(basename "$backup_file")"
    echo -e "   Ukuran: $(du -h "$backup_file" | cut -f1)"
    echo -e "   Modifikasi: $(stat -c %y "$backup_file" 2>/dev/null || stat -f %Sm "$backup_file")"
    echo
    
    # Konfirmasi penggunaan file backup lokal
    read -p "$(yellow "⚠️  Gunakan file backup ini untuk restore? (y/N): ")" use_local
    
    if [[ "$use_local" =~ ^[Yy]$ ]]; then
        echo -e "$(green "✅ Menggunakan file backup lokal...")"
    else
        backup_file=""
    fi
fi

# Jika tidak ada file backup lokal atau user memilih tidak
if [[ -z "$backup_file" ]]; then
    echo -e "$(yellow "📥 Mode: Download dari Google Drive")"
    echo
    
    # Meminta pengguna memasukkan ID Backup atau URL
    while [[ -z "$backup_url" ]]; do
        read -rp "$(yellow "🔗 Masukkan ID Backup atau URL Google Drive: ")" input

        if [[ -z "$input" ]]; then
            echo -e "$(red "❌ Tidak ada input! Proses restore dibatalkan.")"
            exit 1
        fi

        if [[ "$input" == https://drive.google.com* ]]; then
            backup_url="$input"
        else
            backup_url="https://drive.google.com/uc?id=${input}&export=download"
        fi
    done

    # Pastikan paket yang dibutuhkan terinstal
    echo
    echo -e "$(yellow "📦 Memeriksa dependencies...")"
    
    if ! command -v python3 &>/dev/null || ! command -v pip3 &>/dev/null; then
        echo -e "$(green "Menginstal Python3 dan pip3...")"
        dnf install -y python3 python3-pip > /dev/null 2>&1 || { 
            echo -e "$(red "❌ Gagal menginstal Python3 dan pip3!")"; 
            exit 1; 
        }
        echo -e "$(green "✅ Python3 dan pip3 berhasil diinstal")"
    fi

    # Pastikan gdown terinstal
    if ! command -v gdown &>/dev/null; then
        echo -e "$(green "Menginstal gdown...")"
        pip3 install --no-cache-dir gdown > /dev/null 2>&1 || \
        pip3 install --no-cache-dir --break-system-packages gdown > /dev/null 2>&1 || { 
            echo -e "$(red "❌ Gagal menginstal gdown!")"; 
            exit 1; 
        }
        echo -e "$(green "✅ gdown berhasil diinstal")"
    fi

    # Unduh file backup menggunakan gdown
    echo
    echo -e "$(yellow "⬇️  Mengunduh file backup...")"
    backup_file="$backup_dir/restore_backup.zip"
    
    gdown --fuzzy -O "$backup_file" "$backup_url" 2>/dev/null

    if [[ $? -ne 0 ]] || [[ ! -f "$backup_file" ]]; then
        echo -e "$(red "❌ Gagal mengunduh file backup!")"
        echo -e "$(yellow "💡 Pastikan ID/URL benar dan file dapat diakses")"
        exit 1
    fi

    echo -e "$(green "✅ File backup berhasil diunduh: $(basename "$backup_file")")"
fi

# Validasi file ZIP
echo
echo -e "$(yellow "🔐 Memvalidasi file backup...")"
if ! validate_zip_file "$backup_file"; then
    echo -e "$(red "❌ File backup tidak valid!")"
    exit 1
fi

# Ekstrak file backup
echo
echo -e "$(yellow "📂 Mengekstrak file backup...")"
unzip -P "$PASSWORD" -o "$backup_file" -d "$backup_dir" > /dev/null 2>&1

if [[ $? -ne 0 ]]; then
    echo -e "$(red "❌ Gagal mengekstrak file backup!")"
    echo -e "$(yellow "💡 Pastikan password benar: $PASSWORD")"
    exit 1
fi

echo -e "$(green "✅ File backup berhasil diekstrak")"

# Restore file sesuai dengan struktur awal
echo
echo -e "$(yellow "🔄 Memulai proses pemulihan data...")"

# Buat direktori backup jika belum ada
mkdir -p /root/backup

# Ekstrak ulang untuk memastikan struktur benar
unzip -P "$PASSWORD" -o "$backup_file" -d "/root" > /dev/null 2>&1

cd /root/backup

# Restore file sistem
echo -e "$(yellow "   📝 Restore file sistem...")"
[[ -f passwd ]] && cp -f passwd /etc/ 2>/dev/null && echo -e "      $(green "✅") /etc/passwd"
[[ -f group ]] && cp -f group /etc/ 2>/dev/null && echo -e "      $(green "✅") /etc/group"
[[ -f shadow ]] && cp -f shadow /etc/ 2>/dev/null && echo -e "      $(green "✅") /etc/shadow"
[[ -f gshadow ]] && cp -f gshadow /etc/ 2>/dev/null && echo -e "      $(green "✅") /etc/gshadow"

# Restore konfigurasi Xray
echo -e "$(yellow "   🌐 Restore konfigurasi Xray...")"
if [[ -d xray ]]; then
    cp -rf xray /etc/ 2>/dev/null
    echo -e "      $(green "✅") /etc/xray/"
fi

# Restore konfigurasi NoobzVPN
echo -e "$(yellow "   🔐 Restore konfigurasi NoobzVPN...")"
if [[ -d noobzvpns ]]; then
    cp -rf noobzvpns /etc/ 2>/dev/null
    echo -e "      $(green "✅") /etc/noobzvpns/"
fi

echo -e "$(green "✅ Proses restore data selesai")"

# Membersihkan file sementara
echo
echo -e "$(yellow "🧹 Membersihkan file sementara...")"
rm -f "$backup_dir/restore_backup.zip" 2>/dev/null
rm -rf /root/backup 2>/dev/null

echo -e "$(green "✅ Pembersihan file sementara selesai")"

# Restart layanan
echo
echo -e "$(yellow "🔄 Merestart layanan...")"
systemctl daemon-reload > /dev/null 2>&1

services=("xray" "quota" "quota-vmess" "quota-trojan" "ssh" "sshd")
for service in "${services[@]}"; do
    if systemctl is-active --quiet "$service" 2>/dev/null; then
        systemctl restart "$service" > /dev/null 2>&1
        echo -e "      $(green "✅") $service"
    else
        echo -e "      $(yellow "⚠️") $service (tidak aktif)"
    fi
done

# Tampilkan hasil akhir
clear
echo
echo "========================================================"
echo -e "$(green "🎉 PROSES RESTORE SELESAI!")"
echo "========================================================"
echo -e "$(green "✅ Semua data berhasil dipulihkan")"
echo -e "$(green "✅ Layanan telah di-restart")"
echo -e "$(green "✅ File sementara telah dibersihkan")"
echo
echo -e "$(yellow "📋 File yang di-restore:")"
echo -e "   • Konfigurasi Xray (/etc/xray/)"
echo -e "   • Konfigurasi NoobzVPN (/etc/noobzvpns/)"
echo -e "   • File sistem (/etc/passwd, /etc/shadow, dll)"
echo
echo -e "$(green "✨ Sistem siap digunakan!")"
echo -e "$NC"