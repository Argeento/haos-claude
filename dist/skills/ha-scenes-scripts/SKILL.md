---
name: ha-scenes-scripts
description: Creates and edits Home Assistant scenes, scripts, and input helpers in YAML. Use when user asks to "create scene", "add script", "set up scene", "make a wakeup routine", "create input helper", "add input_boolean", "add input_number", "snapshot scene", "reusable action", or any task involving HA scenes, scripts with fields/parameters, or input helpers for dashboard control.
---

# Home Assistant Scenes, Scripts, and Input Helpers

## Instructions

### Step 1: Define scenes as device state snapshots

A scene is a saved set of entity states. Activating a scene transitions all listed entities to their saved states at once.

```yaml
# scenes.yaml
- name: "Living Room — movie night"
  icon: "mdi:movie-open"
  entities:
    light.living_room_ceiling:
      state: "on"
      brightness: 80
      color_temp_kelvin: 2700
    light.living_room_lamp:
      state: "on"
      brightness: 40
    media_player.living_room_tv:
      state: "on"
      source: "HDMI 1"
    cover.living_room_blinds:
      state: "closed"

- name: "Living Room — bright day"
  entities:
    light.living_room_ceiling:
      state: "on"
      brightness: 255
      color_temp_kelvin: 5000
    light.living_room_lamp: "off"
    cover.living_room_blinds:
      state: "open"
```

Include in configuration:

```yaml
# configuration.yaml
scene: !include scenes.yaml
```

Use in automations:

```yaml
actions:
  - action: scene.turn_on
    target:
      entity_id: scene.living_room_movie_night
```

### Step 2: Use snapshots for dynamic save/restore

Save current states before a change so you can restore them later:

```yaml
actions:
  # Save current states
  - action: scene.create
    data:
      scene_id: before_movie
      snapshot_entities:
        - light.living_room_ceiling
        - light.living_room_lamp
  # Activate movie scene
  - action: scene.turn_on
    target:
      entity_id: scene.living_room_movie_night
```

Restore: `action: scene.turn_on` → `entity_id: scene.before_movie`

### Step 3: Create scripts for reusable action sequences

A script is a named sequence of actions that can be called from automations, buttons, or the dashboard.

```yaml
# scripts.yaml (merge_named — each script is a dictionary key)
living_room_wakeup:
  alias: "Wakeup — living room"
  icon: "mdi:weather-sunset-up"
  description: "Gradual brightening of living room in the morning"
  mode: restart
  fields:
    brightness_target:
      description: "Target brightness"
      required: false
      default: 255
      selector:
        number:
          min: 1
          max: 255
    transition_seconds:
      description: "Transition time in seconds"
      required: false
      default: 120
      selector:
        number:
          min: 10
          max: 600
  sequence:
    - action: light.turn_on
      target:
        entity_id: light.living_room_ceiling
      data:
        brightness: "{{ brightness_target | default(255) }}"
        color_temp_kelvin: 4000
        transition: "{{ transition_seconds | default(120) }}"
    - delay:
        seconds: "{{ transition_seconds | default(120) }}"
    - action: cover.open_cover
      target:
        entity_id: cover.living_room_blinds
```

Include in configuration:

```yaml
# configuration.yaml
script: !include scripts.yaml

# Or from a directory:
script: !include_dir_merge_named scripts/
```

### Step 4: Call scripts with or without parameters

```yaml
# From an automation — with parameters
actions:
  - action: script.living_room_wakeup
    data:
      brightness_target: 200
      transition_seconds: 60

# From an automation — without parameters (uses defaults)
actions:
  - action: script.living_room_wakeup
```

### Step 5: Choose the right execution mode

Same as automations — `single`, `restart`, `queued`, `parallel`:

```yaml
voice_notification:
  alias: "Voice notification"
  mode: queued       # Queue notifications, don't lose any
  max: 5
  fields:
    message:
      description: "Text to read aloud"
      required: true
      selector:
        text:
  sequence:
    - action: tts.speak
      target:
        entity_id: tts.google
      data:
        media_player_entity_id: media_player.living_room
        message: "{{ message }}"
    - delay: 2  # Pause between notifications
```

### Step 6: Choose between scenes and scripts

| You want to...                          | Use                                  |
| --------------------------------------- | ------------------------------------ |
| Set device states at once               | Scene                                |
| A sequence with delays, conditions      | Script                               |
| Reusable logic with parameters          | Script with `fields`                 |
| Dynamically save/restore states         | Scene with `scene.create` (snapshot) |
| Fade-in, transition, lighting sequences | Script                               |

### Step 7: Create input helpers for user-configurable parameters

Helpers allow users to control automation behavior from the dashboard, without editing YAML.

```yaml
# configuration.yaml or separate files

input_boolean:
  night_mode:
    name: "Night mode"
    icon: "mdi:weather-night"
  guest_mode:
    name: "Guest mode"
    icon: "mdi:account-group"

input_number:
  bathroom_light_timeout:
    name: "Bathroom light timeout (min)"
    min: 1
    max: 30
    step: 1
    unit_of_measurement: "min"
    icon: "mdi:timer-outline"

input_select:
  home_mode:
    name: "Home mode"
    options:
      - "Home"
      - "Away"
      - "Night"
      - "Guest"
    icon: "mdi:home-variant"

input_datetime:
  morning_alarm:
    name: "Alarm time"
    has_time: true
    has_date: false

input_text:
  welcome_message:
    name: "Welcome message"
    max: 255
```

## Examples

### Using helpers in automations

```yaml
- alias: "Bathroom light — timeout from helper"
  mode: restart
  triggers:
    - trigger: state
      entity_id: binary_sensor.bathroom_motion
      to: "off"
  conditions:
    # Check if night mode is off
    - condition: state
      entity_id: input_boolean.night_mode
      state: "off"
  actions:
    - delay:
        minutes: "{{ states('input_number.bathroom_light_timeout') | int }}"
    - action: light.turn_off
      target:
        entity_id: light.bathroom

- alias: "Morning alarm"
  triggers:
    - trigger: time
      at: input_datetime.morning_alarm
  actions:
    - action: script.living_room_wakeup
```

## Troubleshooting

### Scene mixes entities from different rooms

Cause: Combining entities from multiple rooms in one scene.
Solution: One scene = one room (or zone). Don't mix rooms — create separate scenes per room.

### Scene contains automation logic (delays, conditions)

Cause: Trying to use a scene for complex sequences.
Solution: A scene is only STATE. For sequences with delays, conditions, or transitions, use a script instead.

### Script parameters not working

Cause: Missing `fields` definition or incorrect field name reference.
Solution: Define all parameters in `fields` with `description`, `selector`, and optionally `default`. Reference them in `sequence` with `{{ field_name | default(fallback) }}`.

### Helper name is cryptic (e.g. input_boolean.mode_1)

Cause: Not using descriptive names.
Solution: Name clearly: `input_boolean.vacation_mode_active` > `input_boolean.mode_1`. Add `icon` for dashboard visibility. Set sensible `min`/`max`/`step` for `input_number`.

### Script runs multiple times unexpectedly

Cause: Wrong execution mode for the use case.
Solution: Choose the right mode — `single` (ignore new calls), `restart` (cancel + restart), `queued` (run in order), `parallel` (run simultaneously). Set `max` for queued/parallel.
