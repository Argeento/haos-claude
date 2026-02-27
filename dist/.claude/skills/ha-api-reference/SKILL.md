---
name: ha-api-reference
description: Reference for Home Assistant Supervisor API and Core REST API. Use when user asks to "call API", "fetch entity states", "call service via API", "use REST API", "curl HA", "fire event", "render template", "check states via API", or any task involving HTTP requests to the Supervisor or HA Core REST endpoints.
---

# Home Assistant API Reference

## Instructions

### Supervisor API (via SSH)

Claude runs locally and connects to HAOS via the `haos` wrapper. The `$SUPERVISOR_TOKEN` is available inside the SSH session — no additional setup needed. Use single quotes so the variable expands on the HAOS side.

```bash
./haos cmd 'curl -sSL -H "Authorization: Bearer $SUPERVISOR_TOKEN" http://supervisor/<endpoint>'
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

Use `./haos api` — it handles authentication automatically via `~/.claude/.env`.

```bash
./haos api <METHOD> <ENDPOINT> [JSON_BODY]
```

Available endpoints (**this is the complete list** — do NOT try other paths):

| Endpoint                              | Method | Description              |
| ------------------------------------- | ------ | ------------------------ |
| `/api/`                               | GET    | Ping / health check      |
| `/api/config`                         | GET    | HA configuration         |
| `/api/components`                     | GET    | Loaded components        |
| `/api/events`                         | GET    | List event types         |
| `/api/services`                       | GET    | List available services  |
| `/api/states`                         | GET    | All entity states        |
| `/api/states/<entity_id>`             | GET    | Single entity state      |
| `/api/states/<entity_id>`             | POST   | Create/update state      |
| `/api/states/<entity_id>`             | DELETE | Remove entity            |
| `/api/services/<domain>/<service>`    | POST   | Call service             |
| `/api/events/<event_type>`            | POST   | Fire event               |
| `/api/template`                       | POST   | Render Jinja2 template   |
| `/api/config/core/check_config`       | POST   | Validate config          |
| `/api/intent/handle`                  | POST   | Handle intent            |
| `/api/history/period/<timestamp>`     | GET    | State history            |
| `/api/logbook/<timestamp>`            | GET    | Logbook entries          |
| `/api/calendars`                      | GET    | List calendars           |
| `/api/calendars/<entity_id>`          | GET    | Calendar events          |
| `/api/camera_proxy/<entity_id>`       | GET    | Camera image             |
| `/api/error_log`                      | GET    | Error log (plaintext)    |

**NOT available via REST** (WebSocket-only, will return 404):
`/api/config/device_registry/*`, `/api/config/entity_registry/*`, `/api/config/area_registry/*`, `/api/config/config_entries/*`. To list devices/entities, use `/api/states` with `--jq` filtering instead.

## Examples

### Get all entity states

```bash
./haos api GET /api/states
```

### Call a service

```bash
./haos api POST /api/services/light/turn_on '{"entity_id": "light.living_room_ceiling"}'
```

### Get a single entity state

```bash
./haos api GET /api/states/sensor.living_room_temperature
```

### Render a Jinja2 template

```bash
./haos api POST /api/template '{"template": "{{ states(\"sensor.living_room_temperature\") }}"}'
```

## Troubleshooting

### "401 Unauthorized" or token error from `./haos api`

Cause: Missing, invalid, or expired Long-Lived Access Token (LLAT).
Solution: Generate a new LLAT in HA UI → Profile → Security → Long-Lived Access Tokens. Then update `HA_TOKEN` in `~/.claude/.env`.

Note: `$SUPERVISOR_TOKEN` does NOT work with the Core REST API. `./haos api` uses LLAT from `~/.claude/.env`.

### "401 Unauthorized" from Supervisor endpoints (`/supervisor/*`, `/os/*`)

Cause: Missing or invalid `$SUPERVISOR_TOKEN`.
Solution: The token is automatically available inside the SSH session. Verify with `./haos cmd 'echo $SUPERVISOR_TOKEN'`. If empty, the SSH addon may not have proper Supervisor access configured.

### Supervisor API returns "502 Bad Gateway"

Cause: HA Core is not running or still starting.
Solution: Check Core status with `./haos cmd ha core info`. If it's stopped, start it with `./haos cmd ha core start`.

### Service call has no effect

Cause: Wrong entity_id, wrong service domain, or entity unavailable.
Solution: First verify the entity exists: `./haos api GET /api/states/<entity_id>`. Then check the correct service name: `./haos api GET /api/services`.
