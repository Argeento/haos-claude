---
name: ha-system-review
description: Performs a comprehensive audit of a Home Assistant installation — checks naming conventions, area assignments, automation best practices, configuration hygiene, and system health. Use when user asks to "review my system", "audit HA", "check best practices", "what can I improve", "review entities", "check my setup", or any task involving evaluating the quality of an existing HA configuration.
---

# Home Assistant System Review

CRITICAL: This skill contains a complete step-by-step audit procedure. Execute the steps directly — do NOT enter plan mode or create your own plan. Follow the steps below in order.

## Instructions

Go through each section below in order. For each section, collect data, analyze it, and report findings grouped by severity:

- **Problem** — breaks functionality, causes errors, or is a security risk
- **Warning** — works but violates best practices, will cause issues later
- **Suggestion** — optional improvement for better organization or maintainability

At the end, produce a summary with a prioritized action list.

---

### Step 1: System health check

Start with overall system diagnostics:

```bash
./haos cmd ha core info
./haos cmd ha supervisor info
./haos cmd ha host info
./haos cmd ha resolution info
```

Check for:

- Core / Supervisor running and healthy
- Pending updates (Core, OS, Supervisor, addons)
- Disk space usage — flag if above 80%
- Any issues reported by `resolution info`

### Step 2: Entity naming audit

Fetch all entities and check naming conventions:

```bash
./haos ws config/entity_registry/list --jq '[.[] | {entity_id, name, area_id, labels, disabled_by, platform}]'
```

Check for:

- **Naming pattern** — entity_ids should follow `domain.location_device_function` (e.g., `sensor.living_room_temperature`, not `sensor.temp1`)
- **Consistency** — all entities use the same naming convention, not a mix of styles
- **Domain repeated in name** — `light.living_room_ceiling_light` should be `light.living_room_ceiling`
- **Uppercase or special characters** in entity_id — should be lowercase + underscores only
- **Default/auto-generated names** — entities still using platform-generated IDs (e.g., `sensor.0x00158d000xxxxx_temperature`, `light.hue_ambiance_1`)
- **Friendly names** — missing or generic (e.g., "Temperature" instead of "Living Room Temperature")

### Step 3: Area and floor assignments

Check that devices and entities are properly organized:

```bash
./haos ws config/area_registry/list
./haos ws config/floor_registry/list
./haos ws config/device_registry/list --jq '[.[] | {id, name, name_by_user, area_id, model, manufacturer}]'
```

Check for:

- **Devices without areas** — every device should be assigned to an area
- **Areas without floors** — every area should belong to a floor
- **Missing areas** — rooms that exist physically but aren't defined
- **Empty areas** — defined but have no devices assigned
- **Area naming** — consistent, descriptive, matching physical rooms (not "Room 1", "Test")

### Step 4: Labels and categories

```bash
./haos ws config/label_registry/list
./haos ws config/category_registry/list '{"scope":"automation"}'
```

Check for:

- **Labels in use** — are labels defined and assigned to entities?
- **Useful label groups** — functional (night_lights, critical), technical (zigbee, wifi), control (voice, dashboard)
- **Automation categories** — are automations grouped into categories (Lighting, Climate, Security, etc.)?
- **Unused labels** — defined but not assigned to anything

### Step 5: Automation quality

```bash
./haos cmd cat /config/automations.yaml
```

Check each automation for:

| Check | Problem | Fix |
|-------|---------|-----|
| Missing `id` | No debug traces in UI | Add `id: "snake_case_id"` |
| Missing `alias` | Hard to identify in UI | Add descriptive `alias` |
| Missing `mode` | Defaults to `single`, may miss triggers | Add explicit `mode:` — use `restart` for automations with delays |
| Old syntax (`trigger:`, `platform:`, `service:`) | Deprecated | Migrate to `triggers:`, `trigger:`, `actions:`, `action:` |
| Using `device_id` | Not portable, not readable | Replace with `entity_id` or `area_id` |
| Hardcoded delays | Can't adjust from UI | Use `input_number` helper |
| No `description` | Purpose unclear | Add `description` explaining what and why |
| Duplicate on/off automations | Two automations for one thing | Combine with trigger IDs and `choose` |
| Alias format | Inconsistent naming | Use `Location — Action` format (e.g., "Living Room — light on motion") |

### Step 6: Scripts and scenes quality

```bash
./haos cmd cat /config/scripts.yaml
./haos cmd cat /config/scenes.yaml
```

Check for:

- **Scripts**: have `alias`, `description`, `mode`, `icon`; key (entity_id part) is snake_case
- **Scenes**: have descriptive `name` following `Location — description` format
- **Old syntax**: `service:` instead of `action:` in scripts
- **Hardcoded values**: brightness, temperature values that should be helpers

### Step 7: Configuration structure

```bash
./haos cmd ls -la /config/*.yaml
./haos cmd cat /config/configuration.yaml
```

Check for:

- **File organization** — is configuration split into files (`!include`) or everything in one large `configuration.yaml`?
- **Secrets usage** — are passwords/tokens/coordinates hardcoded or using `!secret`?
- **Packages** — for large installations, are packages used for thematic grouping?
- **Deprecated entries** — old integrations configured via YAML that should be in UI
- **Unused includes** — files referenced by `!include` that are empty or don't exist

```bash
./haos cmd cat /config/secrets.yaml 2>/dev/null | wc -l
```

Only check if secrets.yaml exists and is being used — **NEVER read or display its contents**.

### Step 8: Template sensors

```bash
./haos cmd cat /config/templates.yaml 2>/dev/null
```

Check for:

- **Missing `unique_id`** — prevents editing in UI and changing entity_id
- **Missing `device_class`** and `unit_of_measurement` — worse graphs and icons
- **Not filtering `unknown`/`unavailable`** — breaks calculations
- **State-based templates** where trigger-based would be more efficient

### Step 9: Recorder and database

```bash
./haos cmd du -sh /config/home-assistant_v2.db 2>/dev/null
./haos cmd cat /config/configuration.yaml
```

Check for:

- **Database size** — flag if above 1 GB
- **Recorder configuration** — is `recorder:` configured to limit tracked entities?
- **Missing `exclude`/`include`** — by default HA records everything, which bloats the database
- **Purge settings** — `purge_keep_days` should be set (default 10 is often too much for SD cards)

### Step 10: Integrations and devices

```bash
./haos ws config/integration/list
./haos ws config/device_registry/list --jq '[.[] | select(.disabled_by != null) | {id, name, disabled_by}]'
./haos ws config/entity_registry/list --jq '[.[] | select(.disabled_by != null) | {entity_id, disabled_by}]'
```

Check for:

- **Disabled entities/devices** — why are they disabled? Clean up or re-enable
- **Orphaned entities** — entities from integrations that no longer exist
- **Duplicate integrations** — same device added twice

## Examples

### Example report output

Present findings as a structured report:

```
## System Review Report

### System Health
✅ Core running, version X.Y.Z
⚠️ OS update available (X.Y → X.Z)
❌ Disk usage at 85%

### Entity Naming (X entities checked)
❌ 15 entities with auto-generated names (sensor.0x00158d...)
⚠️ 8 entities with inconsistent naming pattern
✅ 42 entities follow naming convention

### Areas & Organization
❌ 5 devices without area assignment
⚠️ "Outdoor" area has no floor
✅ 12 areas properly organized across 3 floors

### Automations (X automations checked)
❌ 3 automations missing id
⚠️ 5 automations using old syntax
⚠️ 2 pairs of automations that could be combined

### Configuration
⚠️ No recorder configuration — database may grow large
✅ Secrets file in use

### Prioritized Action List
1. [Problem] Fix 5 devices without areas — affects voice assistant targeting
2. [Problem] Add id to 3 automations — enables debugging
3. [Warning] Rename 15 auto-generated entities — improves readability
4. [Warning] Configure recorder excludes — prevents database bloat
5. [Suggestion] Add labels for functional grouping
6. [Suggestion] Set up automation categories
```

Adapt the report structure to what you actually find — skip sections where everything is OK (just note "✅ All good"), focus on sections with issues.

### Useful jq filters for large installations

```bash
# Entities with default names (contain hex addresses or numbers)
./haos ws config/entity_registry/list --jq '[.[] | select(.entity_id | test("0x[0-9a-f]|_[0-9]+$")) | .entity_id]'

# Entities without area (via their device)
./haos ws config/device_registry/list --jq '[.[] | select(.area_id == null) | {name, id}]'

# Automations without id (use Python for YAML parsing)
./haos cmd grep -c "^- id:" /config/automations.yaml
./haos cmd grep -c "^- alias:" /config/automations.yaml
# If counts differ → some automations lack id
```

## Troubleshooting

### User asks to fix issues found during review

Do NOT batch-fix everything at once. Prioritize:

1. **Security issues first** — exposed secrets, missing authentication
2. **Functionality issues** — broken automations, missing areas for voice control
3. **Organization issues** — naming, labels, categories
4. **Optimization** — recorder, database, templates

For each fix, confirm with the user before making changes. Apply fixes one category at a time, validating after each batch.

### Review takes too long on large installations

Focus on the most impactful checks first:

1. System health (Step 1) — quick, catches critical issues
2. Automation quality (Step 5) — most common source of problems
3. Area assignments (Step 3) — affects voice assistant and dashboards
4. Entity naming (Step 2) — improves overall usability

Skip detailed template and recorder analysis unless specifically requested.
