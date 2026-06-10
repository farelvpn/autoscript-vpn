# Autoscript VPN

> Version: **0.1.0-beta** — see [CHANGELOG.md](CHANGELOG.md).

AutoScript VPN & Tunneling Management System, developed for **Rocky Linux 9**.

Supports SSH, VLESS, VMESS, Trojan, and OpenVPN with WebSocket (WS), TLS, and HAProxy, plus a Web API for account management.

## Features

- SSH (OpenSSH + Dropbear) with SSH-over-WebSocket (GO-TUNNEL PRO)
- VLESS, VMESS, Trojan over WebSocket (TLS + non-TLS) via Xray-core
- OpenVPN (TCP 1194, UDP 2200)
- HAProxy + Nginx front (TLS termination, WS routing)
- SQLite-backed account database with soft-delete + recovery and audit log
- Per-account quota and IP limit (VLESS/VMESS/Trojan); SSH IP limit
- Live SSH session monitor with per-user bandwidth (info only)
- Encrypted backup/restore to Telegram; account notifications to Telegram
- Strict firewall allowlist; hardened systemd services
- Auto-tuning by RAM/CPU (Nginx/HAProxy connections, TCP buffers, file limits,
  swap), so it fits a 1 CPU / 1 GB VPS and scales up on larger machines

## Auto-tuning

The installer detects total RAM and CPU count and tunes the stack to fit the
machine (no manual editing needed):

| RAM tier | Nginx conn/worker | HAProxy maxconn | TCP buffers | Swap | swappiness |
|----------|-------------------|-----------------|-------------|------|------------|
| ≤ 1 GB   | 4096   | 8192   | 16 MB  | 2 GB | 60 |
| ≤ 2 GB   | 16384  | 32768  | 32 MB  | 2 GB | 15 |
| ≤ 4 GB   | 65535  | 100000 | 64 MB  | 4 GB | 15 |
| > 4 GB   | 131072 | 200000 | 128 MB | 4 GB | 15 |

Nginx `worker_processes` follows the CPU count. Swap size is capped by free
disk (needs the swap size + 5 GB headroom). This prevents the previous
fixed `worker_connections 1048576` (which alone reserved ~445 MB/worker) from
OOM-ing a small VPS.

## Ports

| Service | Port | Notes |
|---------|------|-------|
| OpenSSH | 22, 3303 | management |
| Dropbear | 109 | SSH |
| HTTP | 80 | HAProxy → Nginx |
| HTTPS / TLS | 443 | HAProxy → Nginx → Xray/SSH-WS |
| BadVPN / UDPGW | 7300/udp | provided by ssh-ws |
| OpenVPN | 1194/tcp, 2200/udp | |

Internal-only (bound to `127.0.0.1`, not in the firewall allowlist):
Xray API `10085`, Nginx `81`/`444`, SSH-WS proxy `8888`, SSH-WS API `8081`,
WebAPI `9000`.

## Requirements

- Rocky Linux 9 (x86_64)
- Root access
- A domain/subdomain pointed to your server IP

## Install

```shell
dnf install epel-release -y ; dnf update -y ; dnf install wget curl openssl screen -y ; wget -q https://raw.githubusercontent.com/risqinf/autoscript/main/install.sh ; chmod +x install.sh ; screen -S autoscript ./install.sh ; if [ $? -ne 0 ]; then rm -f install.sh; fi
```

## Note

If your session disconnects during installation, log back in and resume with:

```shell
screen -r autoscript
```

## Management

After installation, run the menu with:

```shell
menu
```

## Project Structure

```
autoscript/
├── install.sh              # Installer (Rocky Linux 9)
├── uninstall.sh            # Uninstaller
├── LICENSE                 # Apache License 2.0
├── README.md
├── docs/
│   └── API.md              # Web API documentation
├── files/                  # Reserved for the RESTful API server (WIP)
└── scripts/
    ├── lib/                # Shared libraries (common, db, xraycfg, account)
    ├── menu/               # menu, menu-ssh, menu-vless, menu-vmess, ...
    ├── ssh/                # SSH account management
    ├── vless/              # VLESS account management
    ├── vmess/              # VMESS account management
    ├── trojan/             # Trojan account management
    ├── system/             # backup, restore, db-migrate, domain, timezone, ...
    └── api/                # API command handlers
```

Scripts are stored with a `.sh` extension in the repository. During
installation they are deployed to `/usr/local/sbin` as bare command names
(without `.sh`) so the menu can invoke them directly. Shared libraries are
installed to `/usr/local/sbin/lib` and API handlers to `/usr/local/sbin/api`.

## Data model

Account state lives in a single SQLite database at `/etc/xray/xray.db`
(WAL mode, foreign keys, strict CHECK constraints, audit log). The Xray
`config.json` is pure JSON with no comment markers; clients are managed with
`jq` and every change is validated with `xray -test` and rolled back on
failure. There are no `.txt` account files. Existing installs are migrated
automatically by `db-migrate` during install.

> The RESTful API server in `files/` is being rebuilt (C++ or Rust) and is
> not yet shipped.

## SSH WebSocket

SSH-over-WebSocket is provided by **GO-TUNNEL PRO**
([risqinf/websocket-proxy](https://github.com/risqinf/websocket-proxy)) — a
static Go binary installed as `/usr/local/bin/ssh-ws` with the `ssh-ws`
systemd service. On Rocky Linux 9 it is tuned to read `/var/log/secure`
(instead of Debian's `/var/log/auth.log`) and runs as root. It listens on
`127.0.0.1`-reachable port `8888` (fronted by nginx/HAProxy on 80/443),
provides UDPGW on `7300`, and a localhost monitoring API on `8081`.

## Uninstall

```shell
wget -q https://raw.githubusercontent.com/risqinf/autoscript/main/uninstall.sh ; chmod +x uninstall.sh ; ./uninstall.sh
```

## API

See [docs/API.md](docs/API.md) for the full Web API documentation.

## License

Licensed under the Apache License 2.0. See the [LICENSE](LICENSE) file for details.

## Repository

https://github.com/risqinf/autoscript
