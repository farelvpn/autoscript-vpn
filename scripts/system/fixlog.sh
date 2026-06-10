#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: Log maintenance (cap sizes; keep recent data for monitors)
# License: Apache License 2.0 (see LICENSE file)
# Repository: https://github.com/risqinf/autoscript
# ========================================================
# Truncating ssh-ws.log fully would drop the [CONNECT] lines that map a live
# session's proxy-port to its real client IP, breaking the SSH monitor. So
# instead of wiping it, we keep the most recent lines (enough to cover any
# currently-live session) and only hard-wipe the bulky system logs.

# Hard-wipe high-volume logs that the monitors do not need historically.
: > /var/log/messages       2>/dev/null
: > /var/log/syslog         2>/dev/null
: > /var/log/xray/access.log 2>/dev/null
: > /var/log/xray/error.log  2>/dev/null

# /var/log/secure: keep the tail so proxy-port -> user auth mappings for live
# sessions survive (the IP-limit and SSH monitor read it).
if [[ -f /var/log/secure ]]; then
    tail -n 2000 /var/log/secure > /var/log/secure.tmp 2>/dev/null && \
        cat /var/log/secure.tmp > /var/log/secure && rm -f /var/log/secure.tmp
fi

# ssh-ws.log: keep the tail so [CONNECT] lines for live sessions are retained.
if [[ -f /var/log/ssh-ws.log ]]; then
    tail -n 5000 /var/log/ssh-ws.log > /var/log/ssh-ws.log.tmp 2>/dev/null && \
        cat /var/log/ssh-ws.log.tmp > /var/log/ssh-ws.log && rm -f /var/log/ssh-ws.log.tmp
fi
