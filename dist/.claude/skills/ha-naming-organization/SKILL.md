---
name: ha-naming-organization
description: Applies Home Assistant naming conventions, entity organization, and configuration best practices. Use when user asks to "name entities", "organize config", "set up areas", "create labels", "structure YAML files", "rename devices", "set up packages", "organize automations", or needs help with HA configuration file structure, secrets management, or template sensors.
---

# HA Naming, Organization and Configuration Best Practices

## Instructions

### Step 1: Name entities correctly

Format: `<domain>.<location>_<device>_<function>`

```
light.living_room_ceiling
light.living_room_floor_lamp
sensor.bathroom_temperature
sensor.bathroom_humidity
binary_sensor.kitchen_motion
switch.garage_gate
cover.bedroom_blinds
climate.living_room_ac
```

Rules:

- **Lowercase only** + underscores. No uppercase, spaces, or special characters in entity_id
- **Location first** — makes sorting, filtering, and grouping easier
- **Descriptive names** — `sensor.living_room_temperature` > `sensor.temp1`
- **Consistency** — same pattern across the entire installation
- **Don't repeat domain in name** — `light.living_room_ceiling`, NOT `light.living_room_ceiling_light`
- **entity_id ≠ friendly_name** — entity_id is the technical identifier, friendly_name is what the user sees

### Step 2: Set friendly names and device names

Friendly name (display name):

- Can contain special characters, uppercase, spaces
- Format: `Location Description` — e.g. "Living Room Ceiling", "Bathroom Temperature"
- For voice assistant: natural names — "Living room lamp", "Bedroom blinds"
- Aliases: add alternative names if using voice (Settings → Entities → Aliases)

Device names — changing the device name propagates to entities:

- Name the **device** by location: "Living Room Ceiling", "Bathroom Motion Sensor"
- Entities will automatically get sensible entity_ids: `light.living_room_ceiling`, `binary_sensor.bathroom_motion_sensor_motion`

### Step 3: Rename entities and devices via API

Both `entity_id` and `friendly_name` can be changed through the entity registry API:

```bash
# Change entity_id
./haos ws config/entity_registry/update '{"entity_id":"sensor.temp1","new_entity_id":"sensor.living_room_temperature"}'

# Change friendly_name (displayed in UI)
./haos ws config/entity_registry/update '{"entity_id":"sensor.living_room_temperature","name":"Living Room Temperature"}'

# Change both at once
./haos ws config/entity_registry/update '{"entity_id":"sensor.temp1","new_entity_id":"sensor.living_room_temperature","name":"Living Room Temperature"}'
```

To rename a device (propagates to its entities):

```bash
./haos ws config/device_registry/update '{"device_id":"abc123","name_by_user":"Living Room Ceiling"}'
```

**Batch renaming workflow:**

1. List entities to rename: `./haos ws config/entity_registry/list --jq '[.[] | select(.entity_id | startswith("sensor.")) | {entity_id, name, device_id}]'`
2. Rename each entity with `config/entity_registry/update`
3. Verify: `./haos ws config/entity_registry/get '{"entity_id":"sensor.new_name"}'`
4. **Update all references** — changing `entity_id` does NOT auto-update:
   - **Dashboards**: `./haos cmd cat /config/.storage/lovelace_resources` and `./haos cmd cat /config/.storage/lovelace.lovelace_*` — search for old entity_ids
   - **Automations**: `./haos cmd cat /config/automations.yaml` — search and replace old entity_ids
   - **Scripts/Scenes**: `./haos cmd cat /config/scripts.yaml`, `./haos cmd cat /config/scenes.yaml`
   - Build a mapping of old→new entity_ids BEFORE renaming, then use it to update all references after

### Step 4: Name automations, scripts, and scenes consistently

Automations — alias format: `Location — Action description`

```yaml
alias: "Living Room — light on motion in evening"
alias: "Kitchen — fan after cooking"
alias: "Home — night mode at 23:00"
alias: "Alert — smoke detector"
alias: "System — restart device after offline"
```

Prefix categories:

| Prefix       | When                                          |
| ------------ | --------------------------------------------- |
| `Location —` | Local automation (living room, kitchen)       |
| `Home —`     | Global automation (night mode, arriving home) |
| `Alert —`    | Notifications, alarms                         |
| `System —`   | Technical automations (monitoring, restart)   |

Automation id format:

```yaml
id: "living_room_light_on_motion_evening"
id: "home_night_mode"
id: "alert_smoke_detector"
```

Scripts:

```yaml
# Key = entity_id (snake_case)
living_room_wakeup:
  alias: "Living Room — wakeup"
voice_greeting:
  alias: "Voice greeting"
```

Scenes:

```yaml
- name: "Living Room — movie night"
- name: "Living Room — bright day"
- name: "Bedroom — goodnight"
```

### Step 4: Organize areas, floors, labels, and categories

**Areas** — physical rooms. Each device assigned to one zone.

```
Ground Floor:
  - Living Room
  - Kitchen
  - Bathroom (ground floor)
  - Hallway
  - Garage

Upper Floor:
  - Bedroom
  - Kids Room
  - Bathroom (upper floor)
  - Office

Outdoor:
  - Garden
  - Patio
  - Driveway
```

Rules:

- Zones = physical rooms, not logical groups
- Each device has exactly 1 zone
- Zones assigned to floors
- A switch in the hallway controlling the garden? → Zone = Hallway (where it physically is), controls entities in Garden

**Floors** — logical grouping of zones:

- Basement (level: -1)
- Ground Floor (level: 0)
- Upper Floor (level: 1)
- Attic (level: 2)

**Labels** — multi-dimensional tagging, an entity can have many labels:

```
# Functional
night_lights          — lights active in night mode
critical              — devices requiring monitoring
battery               — battery-powered devices
energy_hungry         — high energy consumption

# Technical
zigbee                — Zigbee devices
wifi                  — WiFi devices
mqtt                  — MQTT devices

# Control
voice                 — exposed to voice assistant
main_dashboard        — shown on main dashboard
```

Labels since HA 2025.12 can be used as targets in automations:

```yaml
actions:
  - action: light.turn_off
    target:
      label_id: night_lights
```

**Categories** — for automations, scripts, scenes (grouping in UI):

```
Lighting
Climate
Security
Notifications
System
Multimedia
```

### Step 6: Choose a configuration file organization method

**Method 1: Simple !include** (recommended to start)

```yaml
# configuration.yaml
homeassistant:
  name: "Home"
  unit_system: metric
  time_zone: "Europe/Warsaw"

automation: !include automations.yaml
scene: !include scenes.yaml
script: !include scripts.yaml

input_boolean: !include input_boolean.yaml
input_number: !include input_number.yaml
input_select: !include input_select.yaml

template: !include templates.yaml
```

**Method 2: Include from directories** (many automations)

```yaml
# configuration.yaml
automation: !include automations.yaml                    # UI-managed
automation manual: !include_dir_merge_list automations/  # Manually written

script: !include_dir_merge_named scripts/
```

Structure:

```
/config/
├── configuration.yaml
├── automations.yaml        ← managed by UI
├── automations/            ← manually written
│   ├── living_room.yaml
│   ├── kitchen.yaml
│   └── system.yaml
├── scripts/
│   ├── lighting.yaml
│   └── notifications.yaml
├── scenes.yaml
├── templates.yaml
├── input_boolean.yaml
└── secrets.yaml
```

**Method 3: Packages** (advanced, best organization)

Packages group EVERYTHING related to one function in a single file:

```yaml
# configuration.yaml
homeassistant:
  packages: !include_dir_merge_named packages/
```

```yaml
# packages/living_room_lighting.yaml
input_boolean:
  living_room_movie_mode:
    name: "Living Room — movie mode"
    icon: "mdi:movie"

input_number:
  living_room_default_brightness:
    name: "Living Room — default brightness"
    min: 10
    max: 100
    step: 5
    unit_of_measurement: "%"

scene:
  - name: "Living Room — movie night"
    entities:
      light.living_room_ceiling:
        state: "on"
        brightness_pct: 30

automation:
  - alias: "Living Room — light on motion"
    triggers:
      - trigger: state
        entity_id: binary_sensor.living_room_motion
        to: "on"
    actions:
      - action: light.turn_on
        target:
          entity_id: light.living_room_ceiling
        data:
          brightness_pct: "{{ states('input_number.living_room_default_brightness') | int }}"
```

Advantages of packages:

- Everything in one place — helper + automation + scene
- Easy to transfer between installations
- Clear thematic organization

### Step 7: Manage secrets properly

```yaml
# secrets.yaml
wifi_password: "MySuperPassword123"
mqtt_user: "homeassistant"
mqtt_password: "secret_password"
latitude: 51.960
longitude: 20.163
telegram_bot_token: "123456:ABCdef..."
pushover_api_key: "abc123..."
```

```yaml
# configuration.yaml — usage
homeassistant:
  latitude: !secret latitude
  longitude: !secret longitude
```

What to put in secrets:

- Passwords, API tokens, keys
- Geographic coordinates (home location!)
- Internal and external IP addresses
- Family member names (if privacy matters)
- Camera URLs, tunnel URLs

## Examples

### Template sensors

```yaml
# templates.yaml
- sensor:
    - name: "Number of lights on"
      unique_id: number_of_lights_on
      icon: "mdi:lightbulb-group"
      state: >
        {{ states.light
           | selectattr('state', 'eq', 'on')
           | list | count }}

    - name: "Average home temperature"
      unique_id: average_home_temperature
      unit_of_measurement: "°C"
      device_class: temperature
      state: >
        {% set sensors = [
          states('sensor.living_room_temperature'),
          states('sensor.bedroom_temperature'),
          states('sensor.kitchen_temperature')
        ] | reject('in', ['unknown', 'unavailable']) | map('float') | list %}
        {{ (sensors | sum / sensors | count) | round(1) if sensors else 'unknown' }}

- binary_sensor:
    - name: "Someone home"
      unique_id: someone_home
      device_class: presence
      state: >
        {{ states.person
           | selectattr('state', 'eq', 'home')
           | list | count > 0 }}
```

Template sensor rules:

- **Always `unique_id`** — enables editing in UI, changing entity_id
- **Always `device_class`** and `unit_of_measurement` where appropriate — better graphs, icons
- **Filter `unknown`/`unavailable`** — don't break calculations
- **Trigger-based templates** for MQTT/event data — more efficient than state-based

## Troubleshooting

### Entity names are inconsistent or hard to find

Cause: No naming convention applied.
Solution: Follow the `<domain>.<location>_<device>_<function>` pattern. Rename entity_ids via `config/entity_registry/update` with `new_entity_id` (see Step 3). Alternatively, rename the device with `config/device_registry/update` — new entities will inherit the device name.

### Dashboards/automations broken after renaming entity_ids

Cause: Changing `entity_id` via `config/entity_registry/update` does NOT auto-update references in dashboards, automations, scripts, or scenes.
Solution: After renaming, search and update all references (see Step 3, point 4). Always build an old→new mapping before batch renaming so you can find-and-replace across all YAML files and dashboard configs.

### Automations missing debug traces in UI

Cause: Missing `id` field on automations.
Solution: Always include `id: "snake_case_id"` on every automation.

### Secrets exposed in YAML

Cause: Hardcoding passwords, tokens, or coordinates directly in configuration files.
Solution: Move all sensitive values to `secrets.yaml` and reference with `!secret key_name`.

### Template sensor returns "unknown" or breaks graphs

Cause: Not filtering out `unknown`/`unavailable` states before calculations.
Solution: Always filter: `| reject('in', ['unknown', 'unavailable']) | map('float') | list`.

### Configuration too large / hard to maintain

Cause: Everything in one `configuration.yaml`.
Solution: Use `!include` for separate files, or packages for thematic grouping. One change at a time → test → commit.

### General best practices checklist

- `./haos cmd ha core check` BEFORE every restart
- `mode: restart` on automations with delay/wait
- Trigger-based templates > state-based (fewer calculations)
- Limit `recorder` to needed entities on SD card / low disk space
- Regular backup: `./haos cmd ha backups new --name "weekly-$(date +%Y%m%d)"`
- Don't expose everything to voice assistant — only what you actually use
- Areas correctly assigned — Assist targets by area
