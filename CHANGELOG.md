# Changelog

All notable changes to this project are documented here.
This project adheres to [Semantic Versioning](https://semver.org/).

## [0.1.0-beta] - 2026-06-10

First public beta. Developed for **Rocky Linux 9**.

> Beta notice: this release is for testing. The RESTful API server is not yet
> shipped (handlers exist; the HTTP server will be built in a later release).

### Added
- Apache License 2.0 and `.gitignore`.
- Organized project layout: `scripts/{lib,menu,ssh,vless,vmess,trojan,system,api}`,
  `docs/`, `files/`.
- SQLite database (`/etc/xray/xray.db`) as the single source of truth, with
  `accounts`, `audit_log`, and `meta` tables (WAL, foreign keys, CHECK
  constraints, soft-delete, audit logging).
- Shared libraries: `common.sh`, `db.sh`, `xraycfg.sh`, `account.sh`.
- Pure-JSON Xray `config.json` managed with `jq`; every change is validated
  with `xray -test` and rolled back on failure.
- `db-migrate` to import legacy `.txt` accounts and strip config markers.
- Strict firewall allowlist; internal services bound to `127.0.0.1`.
- Service health checks during install; certificate issuance verified before
  starting services.
- Rich, copy-paste-friendly account output (terminal + Telegram HTML) for
  SSH/VLESS/VMESS/Trojan create, trial, and view.
- SSH-over-WebSocket via GO-TUNNEL PRO (risqinf/websocket-proxy) static Go
  binary, tuned for Rocky Linux 9 (`--auth-log /var/log/secure`, runs as root);
  also provides UDPGW on `7300`.
- Live SSH session monitor (`cek-ssh`): correlates ssh-ws.log bandwidth and
  the real client IP to each username via the proxy-port ↔ /var/log/secure
  mapping (informational; no SSH quota enforcement).
- `rsyslog` setup so `authpriv` (SSH/Dropbear logins) is written to
  `/var/log/secure` on minimal EL9 installs.
- Clean, tabular `docs/API.md` describing the JSON handler contract.

### Changed
- Installer fetches the repository tarball from GitHub and deploys command
  scripts to `/usr/local/sbin` as bare names (no `.sh`); libraries to
  `/usr/local/sbin/lib`; API handlers to `/usr/local/sbin/api`.
- IP-limit enforcement uses a consecutive-violation grace threshold and
  suspends (recoverable) instead of hard-deleting. SSH IP-limit counts only
  currently-live sessions (via `ss` + proxy-port correlation).
- Dropbear logs via syslog (dropped `-E`) so logins reach `/var/log/secure`.
- Backup/restore now archive the SQLite database and pure-JSON config.

### Fixed
- SSH login failures ("incorrect username or password"): register the nologin
  shell (`/usr/sbin/nologin`) in `/etc/shells` so PAM's `pam_shells` accepts
  tunneling accounts.

### Security
- Removed a leaked Google Drive OAuth token; rclone is configured
  interactively.
- Strict input validation (username, password, duration, days, domain,
  prefix) across menu and API entry points to prevent path traversal and
  argument injection.
- Backup encryption password is requested at install and stored at
  `/etc/xray/backup.pass` (chmod 600); private keys are chmod 600;
  `/etc/xray` is chmod 700.
- Removed personal names; normalized repository URLs to
  `github.com/risqinf/autoscript`.

### Removed
- Legacy `.txt` account files and `config.json` comment markers.
- Ads Block (helium) menu entry.

[0.1.0-beta]: https://github.com/risqinf/autoscript/releases/tag/v0.1.0-beta
