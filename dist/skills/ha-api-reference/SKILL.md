---
name: ha-api-reference
description: Reference for Home Assistant Supervisor API and Core REST API. Use when user asks to "call API", "fetch entity states", "call service via API", "use REST API", "curl HA", "fire event", "render template", "check states via API", or any task involving HTTP requests to the Supervisor or HA Core REST endpoints.
---

# Home Assistant API Reference

## Instructions

### Supervisor API (from addon container)

From inside the SSH addon, the Supervisor API is available with the `$SUPERVISOR_TOKEN`. No additional setup needed.

```bash
curl -sSL -H "Authorization: Bearer $SUPERVISOR_TOKEN" http://supervisor/<endpoint>
```

Available endpoints:

| Endpoint                                | Method | Description              |
| --------------------------------------- | ------ | ------------------------ |
| `/supervisor/info`                      | GET    | Supervisor info          |
| `/supervisor/ping`                      | GET    | Ping                     |
| `/core/info`                            | GET    | Core info                |
| `/core/api/states`                      | GET    | Proxy: all entity states |
| `/core/api/services/<domain>/<service>` | POST   | Proxy: call service      |
| `/os/info`                              | GET    | HAOS info                |
| `/host/info`                            | GET    | Host info                |
| `/addons`                               | GET    | List addons              |
| `/addons/<slug>/info`                   | GET    | Addon details            |
| `/addons/<slug>/start`                  | POST   | Start                    |
| `/addons/<slug>/stop`                   | POST   | Stop                     |
| `/addons/<slug>/restart`                | POST   | Restart                  |
| `/addons/<slug>/logs`                   | GET    | Logs (text/plain)        |
| `/backups`                              | GET    | List backups             |
| `/backups/new/full`                     | POST   | New full backup          |
| `/network/info`                         | GET    | Network info             |
| `/hardware/info`                        | GET    | Hardware info            |

### HA Core REST API

Requires a Long-Lived Access Token (LLAT) — generated in UI → Profile → Tokens.

```bash
curl -H "Authorization: Bearer <LLAT>" http://<HA_IP>:8123/api/<endpoint>
```

Available endpoints:

| Endpoint                           | Method   | Description            |
| ---------------------------------- | -------- | ---------------------- |
| `/api/`                            | GET      | Ping                   |
| `/api/config`                      | GET      | HA configuration       |
| `/api/states`                      | GET      | All entity states      |
| `/api/states/<entity_id>`          | GET/POST | Read/write state       |
| `/api/services`                    | GET      | List services          |
| `/api/services/<domain>/<service>` | POST     | Call service           |
| `/api/events/<event_type>`         | POST     | Fire event             |
| `/api/template`                    | POST     | Render Jinja2 template |
| `/api/config/core/check_config`    | POST     | Validate config        |
| `/api/history/period/<timestamp>`  | GET      | State history          |
| `/api/error_log`                   | GET      | Error log              |

## Examples

### Get all entity states via Supervisor proxy

```bash
curl -sSL -H "Authorization: Bearer $SUPERVISOR_TOKEN" \
  http://supervisor/core/api/states
```

### Call a service via Supervisor proxy

```bash
curl -sSL -X POST \
  -H "Authorization: Bearer $SUPERVISOR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"entity_id": "light.living_room_ceiling"}' \
  http://supervisor/core/api/services/light/turn_on
```

### Get a single entity state via Core REST API

```bash
curl -H "Authorization: Bearer <LLAT>" \
  http://<HA_IP>:8123/api/states/sensor.living_room_temperature
```

### Render a Jinja2 template via Core REST API

```bash
curl -X POST \
  -H "Authorization: Bearer <LLAT>" \
  -H "Content-Type: application/json" \
  -d '{"template": "{{ states(\"sensor.living_room_temperature\") }}"}' \
  http://<HA_IP>:8123/api/template
```

## Troubleshooting

### "401 Unauthorized" from Supervisor API

Cause: Missing or invalid `$SUPERVISOR_TOKEN`.
Solution: The token is automatically injected by the addon environment. Verify with `echo $SUPERVISOR_TOKEN`. If empty, the addon may not have proper Supervisor access configured.

### "401 Unauthorized" from Core REST API

Cause: Missing or expired Long-Lived Access Token (LLAT).
Solution: Generate a new LLAT in the HA UI → Profile → Long-Lived Access Tokens. Never expose or log the token.

### Supervisor API returns "502 Bad Gateway"

Cause: HA Core is not running or still starting.
Solution: Check Core status with `ha core info`. If it's stopped, start it with `ha core start`.

### Service call has no effect

Cause: Wrong entity_id, wrong service domain, or entity unavailable.
Solution: First verify the entity exists: `GET /core/api/states/<entity_id>`. Then check the correct service name: `GET /core/api/services`.
