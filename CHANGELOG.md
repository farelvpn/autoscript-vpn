# Changelog

All notable changes to this project are documented here.
This project adheres to [Semantic Versioning](https://semver.org/).

## [0.2.0-beta] - 2026-06-10

Developed for **Rocky Linux 9**. Builds on 0.1.0-beta with routing, output,
logging, and resource-tuning improvements from live VPS testing.

### Added
- SSH-SSL/TLS (SNI) direct tunneling on port 443 alongside SSH-WebSocket.
  HAProxy now terminates TLS on 443 and splits the decrypted stream: an HTTP
  request line goes to the WebSocket stack (nginx -> Xray/ssh-ws), and any
  other (raw SSH) stream is sent straight to Dropbear. One 443 port now serves
  SSH-WS, SSH-SSL/SNI, VMESS, VLESS, and Trojan together. Account output and
  Telegram messages now list the SSH SSL/SNI (Host/SNI, port 443) details.
- Telegram setup menu (`set-telegram`, under System): configure the bot token
  and admin chat id from the panel, send a test message, or clear the config.
  Previously these had to be created by hand at `/etc/xray/{bot.key,client.id}`.
- Service-status overview (`status`, under System): lists every installed
  component (HAProxy, Nginx, Xray, Dropbear, ssh-ws, OpenSSH, OpenVPN, vnStat,
  rsyslog, cron, firewalld, quota/ip-limit loops) with colored ON/OFF and ports.
- 3-state SSH tunnel badge on the main menu and status page: green when both
  Dropbear and ssh-ws are up, yellow when only one is up, red when both down.
- Grouped main menu (Account Panels / Tools / Server) plus a new `menu-system`
  submenu (domain+SSL, DNS, stream check, speedtest, Xray/Dropbear version,
  timezone, service status, Telegram setup, uninstall); `change-dns` extracted
  as a standalone command.

### Changed
- RAM/CPU auto-tuning: Nginx connections, HAProxy `maxconn`, TCP buffers,
  `fs.file-max`, swap size, and `vm.swappiness` scale to the machine so it fits
  a 1 CPU / 1 GB VPS and scales up on larger ones.
- VMESS now uses true multipath: the Xray vmess inbound listens on path `/`,
  Nginx routes by path/handshake, and all VMESS links advertise path `/`.
- Rewrote `xray.service` (uses `xray run -config`, `ExecReload`, higher
  resource limits, `Nice=-10`); removes any unit created by the XTLS installer.
- `rsyslog` is installed and `authpriv` routed to `/var/log/secure`; Dropbear
  logs via syslog (dropped `-E`) so logins are visible there.
- SSH IP-limit counts only currently-live sessions (via `ss` + proxy-port).
- `fixlog` keeps the tail of `ssh-ws.log` and `/var/log/secure` instead of
  wiping them, so the live SSH monitor keeps its proxy-port -> IP/user mapping.
- Both `install.sh` and `uninstall.sh` self-delete when they finish.

### Fixed
- **SSH-WS "400 Bad Request"** (Xray logged `unsupported version: 13 not found
  in 'Sec-Websocket-Version'`). SSH-WS payloads use path `/` like VMESS
  multipath but are not real WebSocket handshakes, so they hit the VMESS
  inbound and were rejected. Nginx now discriminates at `/` by the
  `Sec-WebSocket-Key` header (present only on genuine WS clients): with it →
  VMESS, without it → ssh-ws. An explicit `/ssh` path is also provided (the
  recommended payload), with the correct `Connection: upgrade` mapping and long
  proxy timeouts so tunnels stay open.
- **Login monitor client IP.** Xray's access line is
  `... from <IP>:port accepted ...`; the parser read the wrong field and
  printed a literal "from". It now reads the token after `from` and counts
  distinct client IPs within a recent window, so one client that reconnects
  many times shows as a single IP with its real address.
- **Uninstall is now complete.** Removes the SSH system users it created
  (`userdel --force`, killing their sessions first, from the DB list so only
  script-created accounts are touched), HAProxy config + combined PEM, and
  acme.sh data; restores a working `nginx.conf` (ours `include`s the removed
  `risqinf.conf`); removes `/etc/xray`, `/etc/openvpn`, and the web/log dirs;
  and closes the firewall ports/masquerade it opened (keeps port 22).
- **OpenVPN certificates** are generated non-interactively (EasyRSA batch mode
  with pre-filled fields) and every credential (CA, server cert/key, DH, TA) is
  verified non-empty before the client `.ovpn` profiles are considered valid.
- OpenVPN download links 404: Nginx `/risqinf/` alias now points to
  `/var/www/html/risqinf/` (where the `.ovpn` files are written).
- SSH login "incorrect username or password": register `/usr/sbin/nologin`
  in `/etc/shells` (PAM `pam_shells`).
- vnStat daemon is enabled/started at install so the bandwidth panel works
  (fixes "Failed to open database /var/lib/vnstat/vnstat.db").
- Rewrote `menu-backup` (was a broken inline `menu()`/`backup`/`restore` that
  shadowed the global menu) to call the real `backup`/`restore` commands.

### UI
- One clean horizontal-rule style (dropped the `=`/box-drawing mix);
  width-adaptive `ui_header`/`ui_rule` so menus stay tidy on small phone
  terminals (Termux/PuTTY) and don't wrap; shared `ui_kv` "label : value" rows.
- All decorative glyphs in terminal output replaced with ASCII so they render
  on every terminal/codepage. Telegram messages keep their rich HTML formatting
  for copy-paste by sellers.
- Login checker (cek-vless/vmess/trojan) shows per-account IP usage vs limit,
  quota used vs limit, expiry, and active IPs.
- Shared SSH display helpers so create/trial/view/checker all show the full
  detail block (ports, HTTP-custom config, WS payload, OpenVPN links).
- Defined the previously-undefined main-menu colors (`PURPLE`/`LIGHT`).
- Removed the duplicate "Change Domain" main-menu entry (it lives under
  System → Change Domain / Renew SSL).

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
- RAM/CPU auto-tuning: the installer detects total RAM and CPU and scales
  Nginx `worker_connections`/`worker_rlimit_nofile`, HAProxy `maxconn`, TCP
  buffer sizes, `fs.file-max`, swap size, and `vm.swappiness` accordingly —
  fits a 1 CPU / 1 GB VPS and scales up on larger machines.
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
- Replaced the fixed Nginx `worker_connections 1048576` (which reserved
  ~445 MB per worker and could OOM a 1 GB VPS) with RAM-aware values.
- Removed a stray `stress-ng --vm-bytes 1G` swap "test" that could OOM a
  low-RAM box during install.

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

[0.2.0-beta]: https://github.com/risqinf/autoscript/releases/tag/v0.2.0-beta
[0.1.0-beta]: https://github.com/risqinf/autoscript/releases/tag/v0.1.0-beta
