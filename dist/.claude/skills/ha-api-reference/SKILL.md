---
name: ha-api-reference
description: Home Assistant REST and WebSocket API reference — endpoints, jq/py filters, registry operations. Use for fetching states, calling services, rendering templates, listing devices/entities/areas/integrations, or any HA data access.
---

# Home Assistant API Reference

## How to access HA

- **`./haos api <METHOD> <ENDPOINT> [BODY]`** — REST API (states, services, templates, history)
- **`./haos ws <TYPE> [JSON_DATA]`** — WebSocket (registries: devices, entities, areas, floors, labels, categories, integrations)
- **`./haos cmd <command>`** — SSH (CLI diagnostics, reading files)
- **`./haos put <local> <remote>`** — SCP (copying files to HAOS)

Both `./haos api` and `./haos ws` support:

- `--jq '<filter>'` — JSON filtering (preferred for projecting fields)
- `--py <script>` — Python script on stdin (for complex processing; can read `HA_URL`/`HA_TOKEN` from `os.environ` for follow-up calls; must NOT shell out to `./haos`)
- `-o <file>` — write output to file instead of stdout (use this instead of `>`, which is blocked by permissions)

**For Lovelace dashboards** (cards, views, sections, resources) see the `ha-dashboards` skill — the WS endpoints (`lovelace/config`, `lovelace/config/save`, `lovelace/dashboards/*`, `lovelace/resources/*`) and the storage-mode constraints are documented there.

**Note:** `./haos ws` sends one command and returns one response. It does NOT support subscriptions (`subscribe_events`, `subscribe_entities`). For `get_states`, `call_service`, `fire_event` — use `./haos api` (REST).

## Output efficiency (read this before list calls)

List endpoints can return huge payloads — `/api/states` on a typical install is hundreds of KB, `lovelace/config` for a busy dashboard is similar. Loading those raw into the conversation wastes tokens and slows everything down. Defaults:

- **Always combine `select()` with a `{...}` projection** — narrow rows AND fields. The canonical pattern is `[.[] | select(<filter>) | {<fields>}]`. Both halves matter — `select` alone still returns full objects with all 15+ fields per row.
- **Save big payloads to a file with `-o`** when you need to inspect or mutate them locally (dashboard configs, full registries). Then read with the Read tool only what you need: `./haos ws lovelace/config '{"url_path":"home"}' -o ./tmp/dash.json`.
- **For logs**, never run unfiltered `ha core logs` — it can be megabytes. Quote the pipe to run it on HAOS: `./haos cmd "ha core logs | tail -100"` or `./haos cmd "ha core logs | grep -i error | tail -50"`.
- **For history/logbook**, use `?minimal_response&filter_entity_id=...` query params and bound the time window — those endpoints multiply rows by time.
- **Pipes/redirects**: any `|`, `>`, `head`, `tail`, `grep`, `wc` only work when wrapped inside a quoted `./haos cmd "..."` (executes on HAOS) or via `-o` for output capture. Local `|` / `>` are blocked.

### Common projections

When listing these endpoints, default to these field sets unless the user asks for something specific:

| Endpoint | Compact projection |
|---|---|
| `/api/states` | `{entity_id, state}` (add `last_changed` if relevant) |
| `config/entity_registry/list` | `{entity_id, name, area_id, device_id, disabled_by, platform}` |
| `config/device_registry/list` | `{id, name, name_by_user, area_id, manufacturer, model, disabled_by}` |
| `config/area_registry/list` | `{area_id, name, floor_id, labels}` |
| `config/floor_registry/list` | `{floor_id, name, level}` |
| `config/label_registry/list` | `{label_id, name, color}` |
| `config_entries/get` | `{entry_id, domain, title, state, disabled_by}` |
| `lovelace/dashboards/list` | `{url_path, title, mode, icon}` |
| `lovelace/resources` | `{resource_id, type, url}` |

Example combining filter + projection:

```bash
./haos ws config/entity_registry/list --jq '[.[] | select(.entity_id | test("furtka")) | {entity_id, name, area_id, disabled_by}]'
```

### Regex in `test()` — escaping gotcha

jq string literals only accept a small set of escape sequences (`\n`, `\t`, `\\`, `\"`, …). `\.` is **not** valid and crashes with `Invalid escape … '"\."'`. The wrapper also strips one level of backslashes when forwarding `--jq` on Windows, so naive `\\.` often arrives at jq as `\.` and dies.

Rules of thumb for entity-id filters:

- **Prefer `startswith` / `endswith` / `contains` over regex** — no escaping needed:
  ```bash
  --jq '[.[] | select(.entity_id | startswith("binary_sensor.satel_"))]'
  ```
- **If you need regex, use `[.]` instead of `\.`** for a literal dot:
  ```bash
  --jq '[.[] | select(.entity_id | test("binary_sensor[.]satel"))]'
  ```
- **Never use `\.` inside `test("...")`** — it will not survive the shell + jq round-trip.

If `startswith("binary_sensor.satel")` returns `[]`, the integration likely names entities by friendly label (e.g. `binary_sensor.lazienka`), not with a `satel_` prefix — list `binary_sensor.*` first and inspect.

### Schema discovery (when unsure what fields exist)

If an endpoint isn't in the table above or you're not sure what fields a row has, peek at one element instead of dumping the whole list:

```bash
# List of field names only:
./haos ws <endpoint> --jq '.[0] | keys'

# Or one full sample row:
./haos ws <endpoint> --jq '.[0]'
```

That's a few hundred bytes vs. potentially hundreds of KB for the full list. Once you know the schema, run the real query with a `select() | {...}` projection.

## Full reference

**This is the complete list of available operations.** Do NOT try endpoints or types not listed here.

### States & services

| Task | Command |
|------|---------|
| Read all entity states | `./haos api GET /api/states` |
| Read single entity state | `./haos api GET /api/states/<entity_id>` |
| Create/update entity state | `./haos api POST /api/states/<entity_id> '{"state":"...","attributes":{...}}'` |
| Remove orphaned entity | `./haos api DELETE /api/states/<entity_id>` |
| Call service | `./haos api POST /api/services/<domain>/<service> '{"entity_id":"..."}'` |
| List available services | `./haos api GET /api/services` |

### Templates & configuration

| Task | Command |
|------|---------|
| Render Jinja2 template | `./haos api POST /api/template '{"template":"{{ states(\"sensor.x\") }}"}'` |
| Validate configuration | `./haos api POST /api/config/core/check_config` |
| HA configuration | `./haos api GET /api/config` |
| Loaded components | `./haos api GET /api/components` |
| Handle intent | `./haos api POST /api/intent/handle '{"name":"...","data":{...}}'` |

### History & logs

| Task | Command |
|------|---------|
| State history | `./haos api GET /api/history/period/<timestamp>` |
| Logbook entries | `./haos api GET /api/logbook/<timestamp>` |
| Error log (plaintext) | `./haos api GET /api/error_log` |

History supports query params: `?filter_entity_id=sensor.x&end_time=...&minimal_response`

### Events

| Task | Command |
|------|---------|
| List event types | `./haos api GET /api/events` |
| Fire event | `./haos api POST /api/events/<event_type> '{"key":"value"}'` |

### Calendars & camera

| Task | Command |
|------|---------|
| List calendars | `./haos api GET /api/calendars` |
| Calendar events | `./haos api GET /api/calendars/<entity_id>` |
| Camera snapshot | `./haos api GET /api/camera_proxy/<entity_id>` |

### API health

| Task | Command |
|------|---------|
| Ping / health check | `./haos api GET /api/` |

### Device registry

| Task | Command | Params |
|------|---------|--------|
| List all devices | `./haos ws config/device_registry/list` | — |
| Update device | `./haos ws config/device_registry/update '{...}'` | required: `device_id`; optional: `area_id`, `name_by_user`, `disabled_by`, `labels` |
| Detach integration from device | `./haos ws config/device_registry/remove_config_entry '{...}'` | required: `device_id`, `config_entry_id` |

**There is no `remove_device` command.** To remove a device: delete its integration (see Integrations below) or detach it with `remove_config_entry`.

### Entity registry

| Task | Command | Params |
|------|---------|--------|
| List all entities | `./haos ws config/entity_registry/list` | — |
| Get single entity | `./haos ws config/entity_registry/get '{...}'` | required: `entity_id` |
| Get multiple entities | `./haos ws config/entity_registry/get_entries '{...}'` | required: `entity_ids` (array) |
| Update entity | `./haos ws config/entity_registry/update '{...}'` | required: `entity_id`; optional: `name`, `icon`, `area_id`, `disabled_by`, `hidden_by`, `new_entity_id`, `aliases`, `labels`, `categories`, `device_class`, `options_domain`, `options` |
| Remove entity | `./haos ws config/entity_registry/remove '{...}'` | required: `entity_id` |

### Area registry

| Task | Command | Params |
|------|---------|--------|
| List areas | `./haos ws config/area_registry/list` | — |
| Create area | `./haos ws config/area_registry/create '{...}'` | required: `name`; optional: `icon`, `floor_id`, `labels`, `aliases`, `picture` |
| Update area | `./haos ws config/area_registry/update '{...}'` | required: `area_id`; optional: `name`, `icon`, `floor_id`, `labels`, `aliases`, `picture` |
| Delete area | `./haos ws config/area_registry/delete '{...}'` | required: `area_id` |

### Floor registry

| Task | Command | Params |
|------|---------|--------|
| List floors | `./haos ws config/floor_registry/list` | — |
| Create floor | `./haos ws config/floor_registry/create '{...}'` | required: `name`; optional: `aliases`, `icon`, `level` |
| Update floor | `./haos ws config/floor_registry/update '{...}'` | required: `floor_id`; optional: `name`, `aliases`, `icon`, `level` |
| Delete floor | `./haos ws config/floor_registry/delete '{...}'` | required: `floor_id` |

### Label registry

| Task | Command | Params |
|------|---------|--------|
| List labels | `./haos ws config/label_registry/list` | — |
| Create label | `./haos ws config/label_registry/create '{...}'` | required: `name`; optional: `color`, `description`, `icon` |
| Update label | `./haos ws config/label_registry/update '{...}'` | required: `label_id`; optional: `name`, `color`, `description`, `icon` |
| Delete label | `./haos ws config/label_registry/delete '{...}'` | required: `label_id` |

### Category registry

| Task | Command | Params |
|------|---------|--------|
| List categories | `./haos ws config/category_registry/list '{"scope":"..."}'` | required: `scope` |
| Create category | `./haos ws config/category_registry/create '{...}'` | required: `scope`, `name`; optional: `icon` |
| Update category | `./haos ws config/category_registry/update '{...}'` | required: `scope`, `category_id`; optional: `name`, `icon` |
| Delete category | `./haos ws config/category_registry/delete '{...}'` | required: `scope`, `category_id` |

### Integrations (config entries)

| Task | Command | Params |
|------|---------|--------|
| List integrations | `./haos ws config_entries/get` | optional: `domain`, `type_filter` |
| Get single integration | `./haos ws config_entries/get_single '{"entry_id":"..."}'` | required: `entry_id` |
| Update integration | `./haos ws config_entries/update '{"entry_id":"..."}'` | required: `entry_id`; optional: `title`, `pref_disable_new_entities`, `pref_disable_polling` |
| Disable integration | `./haos ws config_entries/disable '{"entry_id":"...","disabled_by":"user"}'` | required: `entry_id`; optional: `disabled_by` |
| Delete integration | `./haos api DELETE /api/config/config_entries/entry/<entry_id>` | — |

### Files & reload

| Task | Command |
|------|---------|
| Read YAML file | `./haos cmd cat /config/<file>.yaml` |
| Write YAML file | `./haos put ./tmp/<file>.yaml /config/<file>.yaml` |
| Reload automations | `./haos api POST /api/services/automation/reload` |
| Reload scenes | `./haos api POST /api/services/scene/reload` |
| Reload scripts | `./haos api POST /api/services/script/reload` |
| Reload groups | `./haos api POST /api/services/group/reload` |
| Reload input helpers | `./haos api POST /api/services/input_boolean/reload` |
| Core restart (if reload insufficient) | `./haos cmd ha core restart` |

### Diagnostics (SSH)

| Task | Command |
|------|---------|
| System info | `./haos cmd ha info` |
| Core info | `./haos cmd ha core info` |
| Core logs | `./haos cmd ha core logs` |
| Core config check | `./haos cmd ha core check` |
| OS info | `./haos cmd ha os info` |
| Host info | `./haos cmd ha host info` |
| Resolution info | `./haos cmd ha resolution info` |
| List addons | `./haos cmd ha addons` |
| Addon info | `./haos cmd ha addons info <slug>` |
| List backups | `./haos cmd ha backups list` |

## Deleting entities — which method to use

- **Orphaned entities** (`"restored": true`, unavailable) — `./haos api DELETE /api/states/<entity_id>`
- **YAML-defined automations** — remove from `automations.yaml`, then: `./haos api POST /api/services/automation/reload`
- **Entity registry entries** — `./haos ws config/entity_registry/remove '{"entity_id":"..."}'`
- **Devices** — detach integration: `./haos ws config/device_registry/remove_config_entry '{"device_id":"...","config_entry_id":"..."}'`
- **Integrations** — `./haos api DELETE /api/config/config_entries/entry/<entry_id>`

## Examples

### List all devices with manufacturer info

```bash
./haos ws config/device_registry/list --jq '[.[] | {id, name, manufacturer, model}]'
```

### Remove entity from registry

```bash
./haos ws config/entity_registry/remove '{"entity_id":"sensor.old_sensor"}'
```

### Delete integration (config entry)

```bash
./haos api DELETE /api/config/config_entries/entry/abc123def456
```

### Detach integration from device

```bash
./haos ws config/device_registry/remove_config_entry '{"device_id":"abc123","config_entry_id":"xyz789"}'
```

### List all areas

```bash
./haos ws config/area_registry/list --jq '[.[] | {id: .area_id, name}]'
```

### Create a new floor

```bash
./haos ws config/floor_registry/create '{"name":"Ground Floor","level":0}'
```

### Disable an integration

```bash
./haos ws config_entries/disable '{"entry_id":"abc123","disabled_by":"user"}'
```

### Get all entity states (compact)

```bash
./haos api GET /api/states --jq '[.[] | {entity_id, state}]'
```

For just one domain:

```bash
./haos api GET /api/states --jq '[.[] | select(.entity_id | startswith("light.")) | {entity_id, state}]'
```

For full raw states (only when you genuinely need attributes/context — save to a file):

```bash
./haos api GET /api/states -o ./tmp/states.json
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

### Service call has no effect

Cause: Wrong entity_id, wrong service domain, or entity unavailable.
Solution: First verify the entity exists: `./haos api GET /api/states/<entity_id>`. Then check the correct service name: `./haos api GET /api/services`.
