#!/usr/bin/env python3
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: SSH-over-WebSocket / HTTP-Upgrade proxy
# License: Apache License 2.0 (see LICENSE file)
# Repository: https://github.com/risqinf/autoscript
# ========================================================
#
# Accepts WebSocket / HTTP-Upgrade (and raw "injector") connections from the
# front proxy (nginx -> 127.0.0.1:8888), replies with a 101 Switching
# Protocols handshake, then transparently bridges the TCP stream to the local
# SSH backend. Dependency-free (Python 3 stdlib only).
#
# Usage: ssh-ws.py [listen_host] [listen_port] [backend_host] [backend_port]
# Defaults: 0.0.0.0 8888 127.0.0.1 109   (Dropbear)

import socket
import sys
import threading
import select

LISTEN_HOST = sys.argv[1] if len(sys.argv) > 1 else "0.0.0.0"
LISTEN_PORT = int(sys.argv[2]) if len(sys.argv) > 2 else 8888
BACKEND_HOST = sys.argv[3] if len(sys.argv) > 3 else "127.0.0.1"
BACKEND_PORT = int(sys.argv[4]) if len(sys.argv) > 4 else 109

RESPONSE = (
    "HTTP/1.1 101 Switching Protocols\r\n"
    "Upgrade: websocket\r\n"
    "Connection: Upgrade\r\n"
    "\r\n"
)
BUFFER = 65536


def pipe(src, dst):
    try:
        while True:
            r, _, _ = select.select([src], [], [], 300)
            if not r:
                break
            data = src.recv(BUFFER)
            if not data:
                break
            dst.sendall(data)
    except Exception:
        pass
    finally:
        for s in (src, dst):
            try:
                s.shutdown(socket.SHUT_RDWR)
            except Exception:
                pass


def handle(client):
    backend = None
    try:
        client.settimeout(10)
        # Read (and discard) the initial HTTP/injector request headers.
        try:
            client.recv(BUFFER)
        except Exception:
            pass
        # Send the upgrade handshake the client expects.
        try:
            client.sendall(RESPONSE.encode())
        except Exception:
            pass
        client.settimeout(None)

        backend = socket.create_connection((BACKEND_HOST, BACKEND_PORT))
        t1 = threading.Thread(target=pipe, args=(client, backend), daemon=True)
        t2 = threading.Thread(target=pipe, args=(backend, client), daemon=True)
        t1.start()
        t2.start()
        t1.join()
        t2.join()
    except Exception:
        pass
    finally:
        for s in (client, backend):
            try:
                if s:
                    s.close()
            except Exception:
                pass


def main():
    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind((LISTEN_HOST, LISTEN_PORT))
    srv.listen(512)
    print("ssh-ws proxy listening on %s:%d -> %s:%d"
          % (LISTEN_HOST, LISTEN_PORT, BACKEND_HOST, BACKEND_PORT), flush=True)
    while True:
        try:
            client, _ = srv.accept()
            threading.Thread(target=handle, args=(client,), daemon=True).start()
        except KeyboardInterrupt:
            break
        except Exception:
            continue


if __name__ == "__main__":
    main()
