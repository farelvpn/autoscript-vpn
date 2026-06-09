# Autoscript VPN

> Version: **0.1.0-beta** — see [CHANGELOG.md](CHANGELOG.md).

AutoScript VPN & Tunneling Management System, developed for **Rocky Linux 9**.

Supports SSH, VLESS, VMESS, Trojan, and OpenVPN with WebSocket (WS), TLS, and HAProxy, plus a Web API for account management.

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
