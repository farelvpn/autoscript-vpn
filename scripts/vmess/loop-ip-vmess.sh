#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: Service entrypoint for VMESS IP-limit enforcement
# License: Apache License 2.0 (see LICENSE file)
# Repository: https://github.com/risqinf/autoscript
# ========================================================
exec /usr/local/sbin/limit-ip-vmess
