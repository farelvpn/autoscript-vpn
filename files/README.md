# files/

Reserved for the **RESTful API server** (work in progress).

The previous API server binary was removed. A new server will be written from
scratch (C++ or Rust) and published here. The JSON request/response contract
that the server must implement is documented in [`../docs/API.md`](../docs/API.md).

## Planned server behavior

- Bearer-token auth; tokens stored one-per-line in `/etc/api/key`.
- Listen on `127.0.0.1:9000` only (Nginx/HAProxy terminate TLS and proxy `/api`).
- Dispatch validated JSON to the command handlers in `/usr/local/sbin/api/*`.
- Rate limiting, request-size limits, constant-time token comparison.
- Never interpolate untrusted input into shell commands.
- Run under the hardened `server.service` systemd unit with least privilege.

Until then, `server.service` is prepared by the installer but **not started**.

> The SSH-over-WebSocket proxy is a separate component and is **not** built
> from this directory — it is the prebuilt GO-TUNNEL PRO binary from
> [risqinf/websocket-proxy](https://github.com/risqinf/websocket-proxy),
> installed by `install.sh`.
