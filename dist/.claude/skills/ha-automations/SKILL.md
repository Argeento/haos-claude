---
name: ha-automations
description: Create and edit Home Assistant automations in YAML using the new syntax (HA 2024.10+). Use for any task with triggers, conditions, actions — motion triggers, notifications, time-based logic, execution modes, trigger IDs, templates.
---

# Home Assistant Automations

## Instructions

### Step 1: Use the new YAML syntax (HA 2024.10+)

Always use **plural form** keywords. The old syntax still works but the new one is recommended:

```yaml
# ✅ NEW syntax (2024.10+)
- alias: "Automation name"
  description: "Description of what it does"
  triggers:            # NOT trigger:
    - trigger: state   # NOT platform:
      entity_id: ...
  conditions:          # NOT condition:
    - condition: state
      ...
  actions:             # NOT action:
    - action: light.turn_on   # NOT service:
      target:
        entity_id: ...
```

### Step 2: Include all required elements

```yaml
- id: "unique_id_lowercase_snake_case"  # Required for UI and debug traces
  alias: "Human-readable name"          # Required
  description: "What it does and why"   # Recommended
  mode: single                          # Recommended — see Mode section
  triggers:
    - trigger: ...
  conditions: []                        # Empty = no conditions
  actions:
    - action: ...
```

### Step 3: Choose the right execution mode

Determines what happens when an automation triggers again while still running:

| Mode               | Behavior                            | When to use                                               |
| ------------------ | ----------------------------------- | --------------------------------------------------------- |
| `single` (default) | Ignores new triggers while running  | Most automations                                          |
| `restart`          | Cancels current run and starts over | Timers, delays (e.g. "turn off light 5 min after motion") |
| `queued`           | Queues new executions               | Sequences that must complete fully                        |
| `parallel`         | Runs in parallel                    | Independent notifications                                 |

```yaml
- alias: "Turn off light after no motion"
  mode: restart          # ← restart because each motion resets the timer
  max: 10                # Max parallel/queued runs (queued/parallel only)
  triggers:
    - trigger: state
      entity_id: binary_sensor.living_room_motion
      to: "off"
      for: "00:05:00"
  actions:
    - action: light.turn_off
      target:
        area_id: living_room
```

### Step 4: Use trigger IDs for multi-trigger automations

Instead of multiple automations for one event (on/off), use `id` on triggers and `choose` in actions:

```yaml
- alias: "Garage lighting on motion"
  mode: restart
  triggers:
    - trigger: state
      entity_id: binary_sensor.garage_motion
      to: "on"
      id: "motion_detected"
    - trigger: state
      entity_id: binary_sensor.garage_motion
      to: "off"
      for: "00:10:00"
      id: "motion_cleared"
  actions:
    - choose:
        - conditions:
            - condition: trigger
              id: "motion_detected"
          sequence:
            - action: light.turn_on
              target:
                entity_id: light.garage
        - conditions:
            - condition: trigger
              id: "motion_cleared"
          sequence:
            - action: light.turn_off
              target:
                entity_id: light.garage
```

### Step 5: Choose the right targeting method

Since HA 2025.12 you can trigger by area and label. In actions too:

```yaml
# Targeting by area
actions:
  - action: light.turn_off
    target:
      area_id: living_room

# Targeting by label
actions:
  - action: light.turn_off
    target:
      label_id: night_lights

# Targeting by entity (classic)
actions:
  - action: light.turn_on
    target:
      entity_id:
        - light.living_room_ceiling
        - light.living_room_lamp
    data:
      brightness_pct: 80
```

### Step 6: Use templates and variables where needed

The `trigger` variable is available in conditions and actions:

```yaml
- alias: "State change notification"
  triggers:
    - trigger: state
      entity_id:
        - binary_sensor.front_door
        - binary_sensor.patio_door
  actions:
    - action: notify.mobile_app
      data:
        title: "Door"
        message: >
          {{ trigger.to_state.attributes.friendly_name }}
          changed state to {{ trigger.to_state.state }}
```

Local variables for reuse:

```yaml
- alias: "Automation with variables"
  variables:
    notification_title: "Smart Home"
    delay_time: 5
  triggers:
    - trigger: state
      entity_id: binary_sensor.door
      to: "on"
  actions:
    - delay:
        minutes: "{{ delay_time }}"
    - action: notify.mobile_app
      data:
        title: "{{ notification_title }}"
        message: "Door open for {{ delay_time }} minutes"
```

### Step 7: Validate and deploy

1. Before saving — **always validate** YAML: `./haos cmd ha core check`
2. After editing `automations.yaml` — **reload**:
   - `./haos cmd ha core restart` (full restart) or
   - Via API: `./haos api POST /api/services/automation/reload` (faster, no Core restart)
3. Before major changes — **backup**: `./haos cmd ha backups new --name "before-changes"`

## Examples

### Motion-activated light with timeout (restart mode)

```yaml
- alias: "Bathroom — light on motion"
  mode: restart
  triggers:
    - trigger: state
      entity_id: binary_sensor.bathroom_motion
      to: "on"
  conditions:
    - condition: numeric_state
      entity_id: sensor.bathroom_illuminance
      below: 30
  actions:
    - action: light.turn_on
      target:
        entity_id: light.bathroom
    - wait_for_trigger:
        - trigger: state
          entity_id: binary_sensor.bathroom_motion
          to: "off"
          for: "00:05:00"
    - action: light.turn_off
      target:
        entity_id: light.bathroom
```

### Notification when device unavailable

```yaml
- alias: "Alert — device offline"
  triggers:
    - trigger: state
      entity_id:
        - light.living_room_ceiling
        - switch.kitchen_kettle
      to: "unavailable"
      for: "00:10:00"
  actions:
    - action: notify.mobile_app
      data:
        title: "⚠️ Device offline"
        message: >
          {{ trigger.to_state.attributes.friendly_name }}
          has been unavailable for 10 minutes.
```

### If/elif/else with choose

```yaml
- alias: "Lighting based on time of day"
  triggers:
    - trigger: state
      entity_id: binary_sensor.living_room_motion
      to: "on"
  actions:
    - choose:
        - conditions:
            - condition: time
              before: "09:00:00"
          sequence:
            - action: scene.turn_on
              target:
                entity_id: scene.living_room_morning
        - conditions:
            - condition: sun
              after: sunset
          sequence:
            - action: scene.turn_on
              target:
                entity_id: scene.living_room_evening
      default:
        - action: light.turn_on
          target:
            area_id: living_room
          data:
            brightness_pct: 100
```

### Conditional trigger enable/disable

```yaml
- alias: "Alarm — smoke detector"
  triggers:
    - trigger: state
      entity_id: binary_sensor.smoke
      to: "on"
    # This trigger is disabled — enable manually when needed
    - trigger: state
      entity_id: binary_sensor.co
      to: "on"
      enabled: false
  actions:
    - action: notify.mobile_app
      data:
        title: "🔥 ALARM"
        message: "Smoke detected!"
```

## Troubleshooting

### Automation can't be debugged in UI

Cause: Missing `id` field.
Solution: Always include `id: "unique_snake_case_id"` — without it, no debug traces appear in the UI.

### New trigger is ignored while automation is running

Cause: Using `mode: single` (default) on an automation with `delay` or `wait_for_trigger`.
Solution: Use `mode: restart` — so each new trigger cancels the current run and starts over.

### Old syntax still in use

Cause: Using `trigger:` / `platform:` / `action:` / `service:` instead of new plural forms.
Solution: Migrate to new syntax — `triggers:` / `trigger:` (inside list) / `actions:` / `action:`.

```yaml
# ❌ Old syntax
trigger:
  - platform: state
action:
  - service: light.turn_on

# ✅ New syntax
triggers:
  - trigger: state
actions:
  - action: light.turn_on
```

### Two separate automations for on/off of the same device

Cause: Creating separate automations for "turn on" and "turn off" events.
Solution: Combine into one automation with trigger IDs and `choose` (see Step 4).

### Hardcoded delays that can't be adjusted from UI

Cause: Using literal `delay: "00:05:00"` instead of a helper.
Solution: Use `input_number` helper: `delay: "{{ states('input_number.timeout') | int }}"`.

### device_id used instead of entity_id

Cause: Using `device_id: abc123def456` — not portable and not human-readable.
Solution: Use `entity_id` or `area_id` — more readable and easier to maintain.
