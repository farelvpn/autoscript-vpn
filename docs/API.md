API Documentation - SSH/Trojan/VLESS/VMESS Account Management
Base Information
Base URL: https://www.risqinf.biz.id/api/script

Authentication: Bearer Token

Content-Type: application/json

Script Execution: All scripts are executed without .sh extension

Authentication
All requests require Bearer token authentication in the header:

bash
Authorization: Bearer your_token_here
SSH Account Management
1. Create SSH Account (POST)
Script: add-ssh

Request:
```bash
curl -X POST https://www.risqinf.biz.id/api/add-ssh \
  -H "Authorization: Bearer your_token" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "john_doe",
    "password": "securepass123",
    "masa": 30,
    "iplimit": 2
  }'
  ```
Success Response (200):
```json
{
  "status": "true",
  "code": 200,
  "message": "Akun SSH berhasil dibuat",
  "username": "john_doe",
  "password": "securepass123",
  "domain": "risqinf.biz.id",
  "ip": "192.168.1.100",
  "expired_on": "2024-12-15",
  "ports": {
    "ssh": "443",
    "ws_http": "80, 2082, 8080",
    "ws_tls": "443",
    "socks5": "443, 1080",
    "udp_custom": "1-65535 & 36712",
    "badvpn": "7300",
    "slowdns": "53, 5300"
  },
  "slowdns": {
    "dns": "1.1.1.1, 8.8.8.8",
    "nameserver": "ns1.risqinf.biz.id",
    "publik_key": "abc123def456"
  },
  "config": "risqinf.biz.id:1-65535@john_doe:securepass123",
  "payload": "GET /ssh HTTP/1.1[crlf]Host: risqinf.biz.id[crlf]Upgrade: websocket[crlf][crlf]"
}
```

Error Response (400):
```json
{
  "status": "false",
  "code": 400,
  "message": "Username 'john_doe' is already in use"
}
```

2. Delete SSH Account (DELETE)
Script: delete-ssh

Request:
```bash
curl -X DELETE https://www.risqinf.biz.id/api/delete-ssh \
  -H "Authorization: Bearer your_token" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "john_doe"
  }'
  ```
  
Success Response (200):
```json
{
  "status": "true",
  "code": 200,
  "message": "User 'john_doe' has been successfully deleted",
  "data": {
    "username": "john_doe",
    "system_user_removed": true,
    "recovery_backup": true
  }
}
```

Error Response (404):
```json
{
  "status": "false",
  "code": 404,
  "message": "User 'john_doe' does not exist in database"
}
```

3. Extend SSH Account (PUT)
Script: renew-ssh

Request:
```bash
curl -X PUT https://www.risqinf.biz.id/api/renew-ssh \
  -H "Authorization: Bearer your_token" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "john_doe",
    "days": 30
  }'
  ```
  
Success Response (200):
```json
{
  "status": "true",
  "code": 200,
  "message": "Account 'john_doe' successfully extended by 30 days",
  "data": {
    "username": "john_doe",
    "days_added": 30,
    "old_expiration": "15-12-2024 14:30:00",
    "new_expiration": "14-01-2025 14:30:00",
    "system_updated": true
  }
}
```

4. Create SSH Trial Account (POST)
Script: trial-ssh

Request:
```bash
curl -X POST https://www.risqinf.biz.id/api/trial-ssh \
  -H "Authorization: Bearer your_token" \
  -H "Content-Type: application/json" \
  -d '{
    "duration": "2h",
    "limit_ip": 1
  }'
  ```
  
Success Response (201):
```json
{
  "status": "true",
  "code": 201,
  "message": "SSH Trial account created successfully",
  "data": {
    "username": "trial8542",
    "password": "xYz987Abc",
    "domain": "risqinf.biz.id",
    "ip": "192.168.1.100",
    "limit_ip": 1,
    "duration": "2h",
    "expired_system": "2024-12-15",
    "expired_display": "15-12-2024 16:30:00",
    "ports": {
      "ssh": "443",
      "ws_http": "80, 2082",
      "ws_tls": "443",
      "badvpn": "7300"
    },
    "config": "risqinf.biz.id:1-65535@trial8542:xYz987Abc",
    "payload": "GET / HTTP/1.1[crlf]Host: risqinf.biz.id[crlf]Upgrade: websocket[crlf][crlf]",
    "telegram_notification": "sent"
  }
}
```

Trojan Account Management
1. Create Trojan Account (POST)
Script: add-trojan

Request:
```bash
curl -X POST https://www.risqinf.biz.id/api/add-trojan \
  -H "Authorization: Bearer your_token" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "trojan_user",
    "uuid": "12345678-1234-1234-1234-123456789012",
    "quota": 50,
    "iplimit": 3,
    "duration": "30d"
  }'
```

Success Response (201):
```json
{
  "status": "true",
  "code": 201,
  "message": "Trojan account created successfully",
  "data": {
    "username": "trojan_user",
    "uuid": "12345678-1234-1234-1234-123456789012",
    "domain": "risqinf.biz.id",
    "expired_system": "2024-12-15-14-30-00",
    "expired_display": "15-12-2024 14:30:00",
    "limits": {
      "ip": 3,
      "ip_display": "3",
      "quota": 50,
      "quota_display": "50 GB",
      "quota_bytes": 53687091200,
      "quota_human": "50 GB"
    },
    "duration": "30d",
    "ports": {
      "trojan_ws_tls": 443,
      "trojan_ws_http": 80
    },
    "configuration": {
      "encryption": "none",
      "path_ws": "/multipath",
      "sni": "risqinf.biz.id"
    },
    "links": {
      "trojan_ws_tls": "trojan://12345678-1234-1234-1234-123456789012@risqinf.biz.id:443?type=ws&security=tls&host=risqinf.biz.id&path=/trojan&sni=risqinf.biz.id#trojan_user"
    },
    "telegram_notification": "sent"
  }
}
```

Error Response (409):
```json
{
  "status": "false",
  "code": 409,
  "message": "UUID '12345678-1234-1234-1234-123456789012' is already used by another user"
}
```

2. Delete Trojan Account (DELETE)
Script: delete-trojan

Request:
```bash
curl -X DELETE https://www.risqinf.biz.id/api/delete-trojan \
  -H "Authorization: Bearer your_token" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "trojan_user"
  }'
  ```
  
Success Response (200):
```json
{
  "status": "true",
  "code": 200,
  "message": "Trojan account 'trojan_user' deleted successfully",
  "data": {
    "username": "trojan_user",
    "uuid": "12345678-1234-1234-1234-123456789012",
    "expired": "2024-12-15-14-30-00",
    "recovery": {
      "created": true,
      "path": "/etc/xray/recovery/trojan/trojan_user.txt"
    },
    "files_removed": ["database", "quota_limit", "ip_limit", "config_entry"],
    "service_restarted": true,
    "config_updated": true,
    "telegram_notification": "true",
    "domain": "risqinf.biz.id"
  }
}
```

3. Renew Trojan Account (PUT)
Script: renew-trojan

Request:
```bash
curl -X PUT https://www.risqinf.biz.id/api/renew-trojan \
  -H "Authorization: Bearer your_token" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "trojan_user",
    "days": 15
  }'
  ```
  
Success Response (200):
```json
{
  "status": "true",
  "code": 200,
  "message": "Trojan account 'trojan_user' renewed successfully",
  "data": {
    "username": "trojan_user",
    "uuid": "12345678-1234-1234-1234-123456789012",
    "days_added": 15,
    "old_expiration": "2024-12-15-14-30-00",
    "new_expiration": "2024-12-30-14-30-00",
    "new_expiration_display": "30-12-2024 14:30:00",
    "config_updated": true,
    "service_restarted": true,
    "telegram_notification": "true",
    "domain": "risqinf.biz.id"
  }
}
```

4. Create Trojan Trial Account (POST)
Script: trial-trojan

Request:
```bash
curl -X POST https://www.risqinf.biz.id/api/trial-trojan \
  -H "Authorization: Bearer your_token" \
  -H "Content-Type: application/json" \
  -d '{
    "duration": "1h",
    "prefix": "test"
  }'
  ```
  
Success Response (201):
```json
{
  "status": "true",
  "code": 201,
  "message": "Trial Trojan account created successfully",
  "data": {
    "username": "test5678",
    "uuid": "87654321-4321-4321-4321-876543214321",
    "domain": "risqinf.biz.id",
    "duration": "1h",
    "expired_system": "2024-12-15-15-30-00",
    "expired_display": "15-12-2024 15:30:00",
    "limits": {
      "quota": 10,
      "quota_display": "10 GB",
      "quota_bytes": 10737418240,
      "quota_human": "10 GB",
      "ip_limit": 2,
      "ip_limit_display": "2"
    },
    "configuration": {
      "encryption": "none",
      "path_ws": "/trojan",
      "sni": "risqinf.biz.id",
      "ports": {
        "trojan_ws_tls": 443,
        "trojan_ws_http": 80
      }
    },
    "links": {
      "trojan_ws_tls": "trojan://87654321-4321-4321-4321-876543214321@risqinf.biz.id:443?type=ws&security=tls&host=risqinf.biz.id&path=/trojan&sni=risqinf.biz.id#test5678"
    },
    "account_type": "trial",
    "telegram_notification": "sent"
  }
}
```

VLESS Account Management
1. Create VLESS Account (POST)
Script: add-vless

Request:
```bash
curl -X POST https://www.risqinf.biz.id/api/add-vless \
  -H "Authorization: Bearer your_token" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "vless_user",
    "uuid": "abcdef12-3456-7890-abcd-ef1234567890",
    "quota": 25,
    "iplimit": 2,
    "duration": "14d"
  }'
  ```
  
Success Response (201):
```json
{
  "status": "true",
  "code": 201,
  "message": "VLESS account created successfully",
  "data": {
    "username": "vless_user",
    "uuid": "abcdef12-3456-7890-abcd-ef1234567890",
    "domain": "risqinf.biz.id",
    "expired_system": "2024-12-15-14-30-00",
    "expired_display": "15-12-2024 14:30:00",
    "limits": {
      "ip": 2,
      "ip_display": "2",
      "quota": 25,
      "quota_display": "25 GB",
      "quota_bytes": 26843545600,
      "quota_human": "25 GB"
    },
    "duration": "14d",
    "ports": {
      "vless_ws_tls": 443,
      "vless_ws_http": 80
    },
    "configuration": {
      "encryption": "none",
      "path_ws": "/multipath",
      "sni": "risqinf.biz.id"
    },
    "links": {
      "vless_ws_tls": "vless://abcdef12-3456-7890-abcd-ef1234567890@risqinf.biz.id:443?path=/vless&security=tls&encryption=none&type=ws&host=risqinf.biz.id&sni=risqinf.biz.id#vless_user",
      "vless_ws_http": "vless://abcdef12-3456-7890-abcd-ef1234567890@risqinf.biz.id:80?path=/vless&encryption=none&type=ws&host=risqinf.biz.id#vless_user"
    },
    "telegram_notification": "sent"
  }
}
```

2. Delete VLESS Account (DELETE)
Script: delete-vless

Request:
```bash
curl -X DELETE https://www.risqinf.biz.id/api/delete-vless \
  -H "Authorization: Bearer your_token" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "vless_user"
  }'
Success Response (200):

json
{
  "status": "true",
  "code": 200,
  "message": "VLESS account 'vless_user' deleted successfully",
  "data": {
    "username": "vless_user",
    "uuid": "abcdef12-3456-7890-abcd-ef1234567890",
    "expired": "2024-12-15-14-30-00",
    "recovery": {
      "created": true,
      "path": "/etc/xray/recovery/vless/vless_user.txt"
    },
    "files_removed": ["database", "quota_limit", "ip_limit", "config_entry"],
    "service_restarted": true,
    "config_updated": true,
    "telegram_notification": "true",
    "domain": "risqinf.biz.id"
  }
}
```

3. Renew VLESS Account (PUT)
Script: renew-vless

Request:
```bash
curl -X PUT https://www.risqinf.biz.id/api/renew-vless \
  -H "Authorization: Bearer your_token" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "vless_user",
    "days": 7
  }'
  ```
  
Success Response (200):
```json
{
  "status": "true",
  "code": 200,
  "message": "VLESS account 'vless_user' renewed successfully",
  "data": {
    "username": "vless_user",
    "uuid": "abcdef12-3456-7890-abcd-ef1234567890",
    "days_added": 7,
    "old_expiration": "2024-12-15-14-30-00",
    "new_expiration": "2024-12-22-14-30-00",
    "new_expiration_display": "22-12-2024 14:30:00",
    "config_updated": true,
    "service_restarted": true,
    "telegram_notification": "true",
    "domain": "risqinf.biz.id"
  }
}
```

4. Create VLESS Trial Account (POST)
Script: trial-vless

Request:
```bash
curl -X POST https://www.risqinf.biz.id/api/trial-vless \
  -H "Authorization: Bearer your_token" \
  -H "Content-Type: application/json" \
  -d '{
    "duration": "30m"
  }'
  ```
  
Success Response (201):
```json
{
  "status": "true",
  "code": 201,
  "message": "Trial VLESS account created successfully",
  "data": {
    "username": "trial4321",
    "uuid": "11223344-5566-7788-9900-aabbccddeeff",
    "domain": "risqinf.biz.id",
    "duration": "30m",
    "expired_system": "2024-12-15-15-00-00",
    "expired_display": "15-12-2024 15:00:00",
    "limits": {
      "quota": 10,
      "quota_display": "10 GB",
      "quota_bytes": 10737418240,
      "quota_human": "10 GB",
      "ip_limit": 2,
      "ip_limit_display": "2"
    },
    "configuration": {
      "encryption": "none",
      "path_ws": "/multipath",
      "sni": "risqinf.biz.id",
      "ports": {
        "vless_ws_tls": 443,
        "vless_ws_http": 80
      }
    },
    "links": {
      "vless_ws_tls": "vless://11223344-5566-7788-9900-aabbccddeeff@risqinf.biz.id:443?path=/vless&security=tls&encryption=none&type=ws&host=risqinf.biz.id&sni=risqinf.biz.id#trial4321",
      "vless_ws_http": "vless://11223344-5566-7788-9900-aabbccddeeff@risqinf.biz.id:80?path=/vless&encryption=none&type=ws&host=risqinf.biz.id#trial4321"
    },
    "account_type": "trial",
    "telegram_notification": "sent"
  }
}
```

VMESS Account Management
1. Create VMESS Account (POST)
Script: add-vmess

Request:
```bash
curl -X POST https://www.risqinf.biz.id/api/add-vmess \
  -H "Authorization: Bearer your_token" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "vmess_user",
    "uuid": "98765432-1010-2020-3030-987654321010",
    "quota": 30,
    "iplimit": 2,
    "duration": "7d"
  }'
  ```
  
Success Response (201):
```json
{
  "status": "true",
  "code": 201,
  "message": "VMESS account created successfully",
  "data": {
    "username": "vmess_user",
    "uuid": "98765432-1010-2020-3030-987654321010",
    "domain": "risqinf.biz.id",
    "expired_system": "2024-12-15-14-30-00",
    "expired_display": "15-12-2024 14:30:00",
    "limits": {
      "ip": 2,
      "ip_display": "2",
      "quota": 30,
      "quota_display": "30 GB",
      "quota_bytes": 32212254720,
      "quota_human": "30 GB"
    },
    "duration": "7d",
    "ports": {
      "vmess_ws_tls": 443,
      "vmess_ws_http": 80
    },
    "configuration": {
      "encryption": "none",
      "alter_id": 0,
      "path_ws": "/multipath",
      "sni": "risqinf.biz.id"
    },
    "links": {
      "vmess_ws_tls": "vmess://eyAgICAgIHsidjogIjIiLCAicHMiOiAidm1lc3NfdXNlciIsICJhZGQiOiAicmlzcWluZi5iaXouaWQiLCAicG9ydCI6ICI0NDMiLCAiaWQiOiAiOTg3NjU0MzItMTAxMC0yMDIwLTMwMzAtOTg3NjU0MzIxMDEwIiwgImFpZCI6ICIwIiwgIm5ldCI6ICJ3cyIsICJwYXRoIjogIi92bWVzcyIsICJ0eXBlIjogIm5vbmUiLCAiaG9zdCI6ICJyaXNxaW5mLmJpei5pZCIsICJ0bHMiOiAidGxzIn0K",
      "vmess_ws_http": "vmess://eyAgICAgIHsidjogIjIiLCAicHMiOiAidm1lc3NfdXNlciIsICJhZGQiOiAicmlzcWluZi5iaXouaWQiLCAicG9ydCI6ICI4MCIsICJpZCI6ICI5ODc2NTQzMi0xMDEwLTIwMjAtMzAzMC05ODc2NTQzMjEwMTAiLCAiYWlkIjogIjAiLCAibmV0IjogIndzIiwgInBhdGgiOiAiL3ZtZXNzIiwgInR5cGUiOiAibm9uZSIsICJob3N0IjogInJpc3FpbmYuYml6LmlkIiwgInRscyI6ICJub25lIn0K"
    },
    "telegram_notification": "sent"
  }
}
```

2. Delete VMESS Account (DELETE)
Script: delete-vmess

Request:
```bash
curl -X DELETE https://www.risqinf.biz.id/api/delete-vmess \
  -H "Authorization: Bearer your_token" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "vmess_user"
  }'
  ```
  
Success Response (200):
```json
{
  "status": "true",
  "code": 200,
  "message": "VMESS account 'vmess_user' deleted successfully",
  "data": {
    "username": "vmess_user",
    "uuid": "98765432-1010-2020-3030-987654321010",
    "expired": "2024-12-15-14-30-00",
    "recovery": {
      "created": true,
      "path": "/etc/xray/recovery/vmess/vmess_user.txt"
    },
    "files_removed": ["database", "quota_limit", "ip_limit", "config_entry"],
    "service_restarted": true,
    "config_updated": true,
    "telegram_notification": "true",
    "domain": "risqinf.biz.id"
  }
}
```

3. Renew VMESS Account (PUT)
Script: renew-vmess

Request:
```bash
curl -X PUT https://www.risqinf.biz.id/api/renew-vmess \
  -H "Authorization: Bearer your_token" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "vmess_user",
    "days": 10
  }'
  ```
  
Success Response (200):
```json
{
  "status": "true",
  "code": 200,
  "message": "VMESS account 'vmess_user' renewed successfully",
  "data": {
    "username": "vmess_user",
    "uuid": "98765432-1010-2020-3030-987654321010",
    "days_added": 10,
    "old_expiration": "2024-12-15-14-30-00",
    "new_expiration": "2024-12-25-14-30-00",
    "new_expiration_display": "25-12-2024 14:30:00",
    "config_updated": true,
    "service_restarted": true,
    "telegram_notification": "true",
    "domain": "risqinf.biz.id"
  }
}
```

4. Create VMESS Trial Account (POST)
Script: trial-vmess

Request:
```bash
curl -X POST https://www.risqinf.biz.id/api/trial-vmess \
  -H "Authorization: Bearer your_token" \
  -H "Content-Type: application/json" \
  -d '{
    "duration": "1h",
    "prefix": "demo"
  }'
  ```
  
Success Response (201):
```json
{
  "status": "true",
  "code": 201,
  "message": "Trial VMESS account created successfully",
  "data": {
    "username": "demo7890",
    "uuid": "aabbccdd-eeff-0011-2233-445566778899",
    "domain": "risqinf.biz.id",
    "duration": "1h",
    "expired_system": "2024-12-15-15-30-00",
    "expired_display": "15-12-2024 15:30:00",
    "limits": {
      "quota": 10,
      "quota_display": "10 GB",
      "quota_bytes": 10737418240,
      "quota_human": "10 GB",
      "ip_limit": 2,
      "ip_limit_display": "2"
    },
    "configuration": {
      "encryption": "none",
      "alter_id": 0,
      "path_ws": "/multipath",
      "sni": "risqinf.biz.id",
      "ports": {
        "vmess_ws_tls": 443,
        "vmess_ws_http": 80
      }
    },
    "links": {
      "vmess_ws_tls": "vmess://eyAgICAgIHsidjogIjIiLCAicHMiOiAiZGVtbzc4OTAiLCAiYWRkIjogInJpc3FpbmYuYml6LmlkIiwgInBvcnQiOiAiNDQzIiwgImlkIjogImFhYmJjY2RkLWVlZmYtMDAxMS0yMjMzLTQ0NTU2Njc3ODg5OSIsICJhaWQiOiAiMCIsICJuZXQiOiAid3MiLCAicGF0aCI6ICIvdm1lc3MiLCAidHlwZSI6ICJub25lIiwgImhvc3QiOiAicmlzcWluZi5iaXouaWQiLCAidGxzIjogInRscyJ9Cg==",
      "vmess_ws_http": "vmess://eyAgICAgIHsidjogIjIiLCAicHMiOiAiZGVtbzc4OTAiLCAiYWRkIjogInJpc3FpbmYuYml6LmlkIiwgInBvcnQiOiAiODAiLCAiaWQiOiAiYWFiYmNjZGQtZWVmZi0wMDExLTIyMzMtNDQ1NTY2Nzc4ODk5IiwgImFpZCI6ICIwIiwgIm5ldCI6ICJ3cyIsICJwYXRoIjogIi92bWVzcyIsICJ0eXBlIjogIm5vbmUiLCAiaG9zdCI6ICJyaXNxaW5mLmJpei5pZCIsICJ0bHMiOiAibm9uZSJ9Cg=="
    },
    "account_type": "trial",
    "telegram_notification": "sent"
  }
}
```

Common Error Responses
Authentication Error (401)
```json
{
  "status": "false",
  "code": 401,
  "message": "Unauthorized: Invalid or missing Bearer token"
}
```

Validation Error (400)
```json
{
  "status": "false",
  "code": 400,
  "message": "Invalid JSON input or missing required fields"
}
```

Detailed Validation Error:
```json
{
  "status": "false",
  "code": 400,
  "message": "Username can only contain letters, numbers and underscores"
}
```

Resource Not Found (404)
```json
{
  "status": "false",
  "code": 404,
  "message": "User 'nonexistent_user' not found in database"
}
```

Conflict Error (409)
```json
{
  "status": "false",
  "code": 409,
  "message": "A client with this username already exists"
}
```

UUID Conflict:
```json
{
  "status": "false",
  "code": 409,
  "message": "UUID '12345678-1234-1234-1234-123456789012' is already used by another user"
}
```

Server Error (500)
```json
{
  "status": "false",
  "code": 500,
  "message": "Internal server error: Failed to update Xray configuration"
}
```

Database Error:
```json
{
  "status": "false",
  "code": 500,
  "message": "Failed to update database file"
}
```

Service Error:
```json
{
  "status": "false",
  "code": 500,
  "message": "Failed to restart Xray service"
}
```

Field Specifications
- Duration Format
30m - 30 minutes

2h - 2 hours

1d - 1 day

7d - 7 days

30d - 30 days

UUID Format
Standard UUIDv4 format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx

Auto-generated if not provided

Must be unique across all accounts

Quota Limits
Minimum: 1 GB

Maximum: Unlimited (0 for unlimited)

Default for trials: 10 GB

Stored in bytes for internal processing

IP Limits
Minimum: 1 IP

Maximum: Unlimited (0 for unlimited)

Default for trials: 2 IPs

Controls maximum simultaneous connections

Username Rules
Only alphanumeric characters and underscores

Minimum length: 3 characters

Maximum length: 20 characters

Must be unique per account type

Rate Limiting
Maximum requests: 10 requests per minute per IP

Trial accounts: Limited to 5 creations per hour per IP

Burst protection: Temporary block after 20 failed auth attempts

Telegram Notifications
All account operations automatically send notifications to configured Telegram channels when:

Bot token and chat ID are configured in server settings

Operation is successful

Includes account details, expiration information, and configuration links

Notification status included in response as telegram_notification field

Recovery System
All DELETE operations support recovery:

Account data moved to recovery directory

Can be restored using recovery tools

Recovery path provided in delete response

Automatic cleanup after 30 days
