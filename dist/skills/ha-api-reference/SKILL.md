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

Use the `ha-api` wrapper — it handles authentication automatically via `~/.claude/.ha-token`.

```bash
ha-api <METHOD> <ENDPOINT> [JSON_BODY]
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

### Get all entity states

```bash
ha-api GET /api/states
```

### Call a service

```bash
ha-api POST /api/services/light/turn_on '{"entity_id": "light.living_room_ceiling"}'
```

### Get a single entity state

```bash
ha-api GET /api/states/sensor.living_room_temperature
```

### Render a Jinja2 template

```bash
ha-api POST /api/template '{"template": "{{ states(\"sensor.living_room_temperature\") }}"}'
```

## Troubleshooting

### "401 Unauthorized" or token error from `ha-api`

Cause: Missing, invalid, or expired Long-Lived Access Token (LLAT).
Solution: Generate a new LLAT in HA UI → Profile → Security → Long-Lived Access Tokens. Save it: `echo "YOUR_TOKEN" > ~/.claude/.ha-token`

Note: `$SUPERVISOR_TOKEN` does NOT work with the Core REST API. The `ha-api` wrapper uses LLAT from `~/.claude/.ha-token`.

### "401 Unauthorized" from Supervisor endpoints (`/supervisor/*`, `/os/*`)

Cause: Missing or invalid `$SUPERVISOR_TOKEN`.
Solution: The token is automatically injected by the addon environment. Verify with `echo $SUPERVISOR_TOKEN`. If empty, the addon may not have proper Supervisor access configured.

### Supervisor API returns "502 Bad Gateway"

Cause: HA Core is not running or still starting.
Solution: Check Core status with `ha core info`. If it's stopped, start it with `ha core start`.

### Service call has no effect

Cause: Wrong entity_id, wrong service domain, or entity unavailable.
Solution: First verify the entity exists: `GET /core/api/states/<entity_id>`. Then check the correct service name: `GET /core/api/services`.
