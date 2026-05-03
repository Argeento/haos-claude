---
name: ha-dashboards
description: Edit Home Assistant Lovelace dashboards via the WebSocket API — cards, views, sections, resources, dashboard list. Use for any task touching the Lovelace UI configuration.
---

# Home Assistant Dashboards (Lovelace)

## Storage mode vs YAML mode — check first

A dashboard is editable via the API **only if `mode: storage`**. YAML-mode dashboards are read-only via the API and must be edited by the user in the YAML file.

- **Check the mode** before any edit: `./haos ws lovelace/dashboards/list` and look at the `mode` field of each entry.
- The default dashboard (created by HA on install) is storage-mode and has `url_path: null` in the dashboards list. To address it in `lovelace/config` / `lovelace/config/save`, omit `url_path` (or pass `null`).
- A YAML-mode dashboard returns `Cannot save in YAML mode` from `lovelace/config/save`. Stop and tell the user to edit the YAML file directly — do not try to work around it.

## NEVER edit `.storage/lovelace*` directly

Files in `/config/.storage/` (including `lovelace`, `lovelace.<dashboard_id>`, `lovelace_dashboards`, `lovelace_resources`) are managed by Core. Manual edits cause corruption and the in-memory cache will overwrite your changes on next save. The WebSocket API is the only safe path.

## WebSocket commands

### Dashboards (the dashboard list, not their content)

| Task | Command | Params |
|------|---------|--------|
| List dashboards | `./haos ws lovelace/dashboards/list` | — |
| Create dashboard | `./haos ws lovelace/dashboards/create '{...}'` | required: `url_path`, `title`; optional: `icon`, `show_in_sidebar`, `require_admin` |
| Update dashboard metadata | `./haos ws lovelace/dashboards/update '{...}'` | required: `dashboard_id`; optional: `url_path`, `title`, `icon`, `show_in_sidebar`, `require_admin` |
| Delete dashboard | `./haos ws lovelace/dashboards/delete '{...}'` | required: `dashboard_id` |

`dashboard_id` is the storage identifier from `lovelace/dashboards/list`. `url_path` is the URL slug (e.g. `home`, `energy`). `lovelace/config` uses `url_path`, the others use `dashboard_id` — they are NOT interchangeable.

### Dashboard config (the actual cards/views)

| Task | Command | Params |
|------|---------|--------|
| Get dashboard config | `./haos ws lovelace/config '{"url_path":"<slug>"}'` | optional: `url_path` (omit for default), `force` |
| Save dashboard config | `./haos ws lovelace/config/save '{"url_path":"<slug>","config":{...}}'` | required: `config`; optional: `url_path` |
| Delete dashboard config | `./haos ws lovelace/config/delete '{"url_path":"<slug>"}'` | optional: `url_path` |

`config` is the full dashboard structure (`{"views": [...]}`) — `lovelace/config/save` does a full replace, not a patch. **Always read the current config first, modify in memory, then save.** Never construct a config from scratch unless the user explicitly wants to replace everything.

### Resources (custom cards, themes, modules)

| Task | Command | Params |
|------|---------|--------|
| List resources | `./haos ws lovelace/resources` | — |
| Create resource | `./haos ws lovelace/resources/create '{"res_type":"module","url":"/local/..."}'` | required: `res_type` (`module`/`css`/`js`), `url` |
| Update resource | `./haos ws lovelace/resources/update '{"resource_id":"...","res_type":"...","url":"..."}'` | required: `resource_id`, `res_type`, `url` |
| Delete resource | `./haos ws lovelace/resources/delete '{"resource_id":"..."}'` | required: `resource_id` |

Resource changes require a browser refresh to take effect.

## Dashboard config structure

### Sections layout (HA 2024.10+, the modern default)

```yaml
views:
  - title: Home
    path: home
    type: sections
    sections:
      - type: grid
        cards:
          - type: tile
            entity: light.living_room
          - type: weather-forecast
            entity: weather.home
      - type: grid
        cards: [...]
```

### Legacy layout (panel, masonry, sidebar)

```yaml
views:
  - title: Home
    path: home
    cards:
      - type: tile
        entity: light.living_room
```

**Always handle both** when walking the config: a view may have `sections[]` (modern) OR `cards[]` (legacy). Some dashboards mix view types.

### Recursive card walk

Cards can nest cards — `vertical-stack`, `horizontal-stack`, `grid`, `conditional`, `picture-elements`. To find a card by some predicate, walk recursively across:

- `views[].sections[].cards[]` — modern layout
- `views[].cards[]` — legacy layout
- `card.cards[]` — stack/grid containers
- `card.card` — `conditional` card has a single nested card
- `card.elements[]` — `picture-elements` (each element may have a `card` key)
- `views[].badges[]` — badges are not cards but sometimes worth scanning

A starter Python walker (run with `--py`):

```python
import json, sys

dashboard = json.load(sys.stdin)

def walk(node, path):
    if isinstance(node, dict):
        if "type" in node:
            yield path, node
        for k in ("cards", "elements"):
            for i, child in enumerate(node.get(k, []) or []):
                yield from walk(child, f"{path}.{k}[{i}]")
        if "card" in node:
            yield from walk(node["card"], f"{path}.card")
    elif isinstance(node, list):
        for i, child in enumerate(node):
            yield from walk(child, f"{path}[{i}]")

for v_idx, view in enumerate(dashboard.get("views", [])):
    base = f"views[{v_idx}]"
    for s_idx, section in enumerate(view.get("sections", []) or []):
        for c_idx, card in enumerate(section.get("cards", []) or []):
            yield_from = walk(card, f"{base}.sections[{s_idx}].cards[{c_idx}]")
            for path, c in yield_from:
                print(path, c.get("type"), c.get("entity", ""))
    for c_idx, card in enumerate(view.get("cards", []) or []):
        for path, c in walk(card, f"{base}.cards[{c_idx}]"):
            print(path, c.get("type"), c.get("entity", ""))
```

## Editing workflow (storage-mode dashboards)

**Default approach for any dashboard edit — do this, do NOT hand the user YAML to paste manually unless they ask.**

1. **Read current config** to a local file (use `-o`, NOT `>` — local redirects are blocked):

```bash
./haos ws lovelace/config '{"url_path":"home"}' -o ./tmp/dashboard.json
```

2. **Modify** with the Write tool or a Python script that loads `./tmp/dashboard.json`, finds the target card/view/section, mutates it, and writes back to `./tmp/dashboard.new.json`.

3. **Build the save payload** (wraps the config under a `config` key with `url_path`) — write the payload directly to `./tmp/payload.json` with the Write tool (or a `--py` script). Structure:

```json
{"url_path": "home", "config": { ... full dashboard config ... }}
```

4. **Save**:

```bash
./haos ws lovelace/config/save "$(cat ./tmp/payload.json)"
```

If the payload is too large for a command-line argument (Windows limit ~32 KB), use `--py` to load the file and call the WS API directly using `HA_URL` / `HA_TOKEN` from `os.environ`.

5. **Verify** by re-reading (`./haos ws lovelace/config '{"url_path":"home"}' -o ./tmp/after.json`) and diffing.

If `lovelace/config/save` returns a validation error, the new config is rejected and the live dashboard is unchanged — fix the payload and retry.

## Limitations

- `./haos ws` passes the JSON payload as a command-line argument. On Windows the cmdline limit is ~32 KB. A typical dashboard payload is well under that, but if you hit `Argument list too long` on save, the dashboard is too big to pass inline — tell the user.
- No subscriptions over `./haos ws` — you cannot watch for live config changes.
- `lovelace/config/save` is a full replace. There is no partial-update endpoint.

## Examples

### List dashboards with mode

```bash
./haos ws lovelace/dashboards/list --jq '[.[] | {url_path, title, mode}]'
```

### Read default dashboard config

```bash
./haos ws lovelace/config
```

### List all card types used in a dashboard

```bash
./haos ws lovelace/config '{"url_path":"home"}' --py ./tmp/list_card_types.py
```

### Add a new card to the first section of the first view

Read → mutate locally → save:

```bash
# 1. Read into a file (use -o, not >)
./haos ws lovelace/config '{"url_path":"home"}' -o ./tmp/d.json

# 2. Edit ./tmp/d.json (append a card to views[0].sections[0].cards) and write
#    the full payload {"url_path":"home","config":{...}} to ./tmp/payload.json

# 3. Save
./haos ws lovelace/config/save "$(cat ./tmp/payload.json)"
```

### Create a new storage-mode dashboard

```bash
./haos ws lovelace/dashboards/create '{"url_path":"energy_v2","title":"Energy v2","icon":"mdi:lightning-bolt","show_in_sidebar":true,"require_admin":false}'
```

### Add a custom card resource

```bash
./haos ws lovelace/resources/create '{"res_type":"module","url":"/local/community/mushroom/mushroom.js"}'
```

## Troubleshooting

### `Cannot save in YAML mode`

The dashboard is in YAML mode — the API cannot edit it. Tell the user which YAML file controls it (usually referenced from `configuration.yaml` under `lovelace:` or `lovelace.dashboards:`).

### `unknown_command` for `lovelace/...`

Old HA version. `lovelace/config` and dashboard management have existed since the storage-mode dashboards landed (HA 0.107+) — only relevant if the user runs something ancient.

### Config saves but dashboard looks broken in UI

The save accepts any JSON shape — schema is validated lazily by the frontend. Verify the structure (`views: [...]`, each view has `cards` or `sections`, card `type` is valid). A hard refresh in the browser may also be needed.

### `Argument list too long` on save

Payload exceeds the OS cmdline limit (~32 KB on Windows). Currently the wrapper has no `--data-file` for `ws` — tell the user, and consider trimming unused views or splitting cards across more dashboards.
