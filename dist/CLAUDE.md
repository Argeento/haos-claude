# CLAUDE.md — Home Assistant OS

You are running **locally** on the user's PC, connected to Home Assistant OS (HAOS) via SSH and HTTP API.

**You MUST use the `haos` wrapper for ALL interactions with Home Assistant.** Never use raw `ssh`, `scp`, or `curl` to communicate with HAOS — always go through `./haos cmd`, `./haos put`, or `./haos api`.

## How to interact with HAOS

One wrapper handles all communication:

- **`./haos cmd <command>`** — runs any command on HAOS via SSH (e.g., `./haos cmd ha info`, `./haos cmd cat /config/automations.yaml`)
- **`./haos put <local> <remote>`** — copies a local file to HAOS via SCP (e.g., `./haos put /tmp/automations.yaml /config/automations.yaml`)
- **`./haos api <METHOD> <ENDPOINT> [BODY]`** — calls HA Core REST API over HTTP (e.g., `./haos api GET /api/states`)

Config is stored in `~/.claude/.env`. **NEVER read or expose this file** — it contains tokens.

## Architecture

HAOS runs Docker containers (Supervisor, Core on port 8123, DNS on 172.30.32.3, addons) on a minimal Buildroot host. Host filesystem is read-only (erofs + overlay). All persistent data lives on the `hassos-data` partition (ext4) at `/mnt/data/`. System uses A/B kernel+system slots with RAUC for updates.

The SSH addon container runs Alpine Linux with the `ha` CLI, `jq`, `curl`, and `cat` available. Python is NOT available.

## Critical files on HAOS (/config/)

- `secrets.yaml` — MUST NOT expose or log contents
- `.storage/` — MUST NOT edit manually (managed by Core, manual edits = corruption)
- `home-assistant_v2.db` — MUST NOT edit (use the API instead)
- `configuration.yaml` — main HA config (requires confirmation to edit)

## FORBIDDEN

- `./haos cmd ha os datadisk wipe` — factory reset, erases EVERYTHING
- `./haos cmd rm -rf /config/` or `./haos cmd rm -rf /config/.storage/` — irreversible data loss
- Editing `home-assistant_v2.db` or any file in `.storage/`
- Exposing `secrets.yaml` contents, `~/.claude/.env`, or any tokens

## Requires user confirmation

- Editing any YAML on HAOS
- `./haos cmd ha core restart` / `./haos cmd ha core update` / `./haos cmd ha os update`
- `./haos cmd ha host reboot` / `./haos cmd ha host shutdown`
- Addon start/stop/restart/install/uninstall
- Creating/restoring backups
- Network configuration changes

## Safe (no confirmation needed)

All diagnostic commands: `./haos cmd ha info`, `./haos cmd ha core info`, `./haos cmd ha core logs`, `./haos cmd ha core check`, `./haos cmd ha resolution info`. Reading files via `./haos cmd cat /config/...`. Reading logs. Listing backups. API read operations via `./haos api GET ...`.

## How to access HA data

### REST API (read + write)

- **Read states**: `./haos api GET /api/states`
- **Read single entity**: `./haos api GET /api/states/sensor.example`
- **Call service**: `./haos api POST /api/services/light/turn_on '{"entity_id":"light.example"}'`
- **Render template**: `./haos api POST /api/template '{"template":"{{ states(\"sensor.example\") }}"}'`

### Files and CLI (via SSH)

- **Automations**: `./haos cmd cat /config/automations.yaml`
- **Scenes**: `./haos cmd cat /config/scenes.yaml`
- **Scripts**: `./haos cmd cat /config/scripts.yaml`
- **Addons**: `./haos cmd ha addons`
- **System info**: `./haos cmd ha info`, `./haos cmd ha core info`, `./haos cmd ha os info`, `./haos cmd ha host info`

## Editing files on HAOS

To write files on the remote HAOS system, save locally first, then copy via SCP:

```bash
# 1. Write the new content to a local temp file
# 2. Copy to HAOS
./haos put /tmp/automations.yaml /config/automations.yaml
```

Workflow:

1. Read: `./haos cmd cat /config/automations.yaml`
2. Prepare new content and save to a local temp file (e.g., `/tmp/automations.yaml`)
3. Write: `./haos put /tmp/automations.yaml /config/automations.yaml`
4. Validate: `./haos cmd ha core check`
5. Apply — prefer reload over restart:
   - **Automations**: `./haos api POST /api/services/automation/reload`
   - **Scenes**: `./haos api POST /api/services/scene/reload`
   - **Scripts**: `./haos api POST /api/services/script/reload`
   - **Groups**: `./haos api POST /api/services/group/reload`
   - **Input helpers**: `./haos api POST /api/services/input_boolean/reload` (same for input_number, input_select, etc.)
   - **Full Core restart** (`./haos cmd ha core restart`) — only if reload is not sufficient (e.g., changes to `configuration.yaml`, new integrations)

## Things that will bite you

- MUST run `./haos cmd ha core check` before every `./haos cmd ha core restart`
- MUST create backup before updates: `./haos cmd ha backups new --name "before-update"`
- Stopping DNS addon (AdGuard/Pi-hole) kills name resolution system-wide
- Stopping MQTT broker breaks all MQTT-dependent addons
- Network config changes risk locking you out — always have a plan B
- If SSH hangs, check connectivity: `./haos cmd echo ok`

## Work principles

1. Before destructive operations — ask for confirmation + suggest backup
2. Before editing files — show what you intend to change
3. Before restarting Core — MUST validate with `./haos cmd ha core check`
4. Before updates — MUST backup with `./haos cmd ha backups new`
5. Log commands — state what you're running before you run it
6. If you don't know — say so directly instead of guessing

## Session start (MUST run at the beginning of every conversation)

1. Display the following disclaimer (in the user's language):
   > **This software is provided without any warranty.** Before starting any work, create a full Home Assistant backup (`./haos cmd ha backups new --name "pre-claude"`) to protect your data in case of errors.
2. Greet the user and ask how you can help with their Home Assistant.
