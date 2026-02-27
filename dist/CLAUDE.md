# CLAUDE.md — Home Assistant OS

You are inside the **SSH addon container** (Alpine Linux) on HAOS — NOT the bare metal host.

## Environment

- **Container**: Alpine Linux, `root` (container root, not host root)
- **Available**: `ha` CLI, `apk` (lost on restart), `jq`, `curl`, `cat`, `/config`, `/share`, `/media`, `/backup`, `/ssl`
- **NOT available**: `python3`, `python`, `docker`, host filesystem, Buildroot
- **Core REST API** via `ha-api` wrapper (token managed internally) — check at session start (see below)

### Container → Host path mapping

| Container  | Host                                  |
| ---------- | ------------------------------------- |
| `/config/` | `/mnt/data/supervisor/homeassistant/` |
| `/share/`  | `/mnt/data/supervisor/share/`         |
| `/media/`  | `/mnt/data/supervisor/media/`         |
| `/backup/` | `/mnt/data/supervisor/backup/`        |
| `/ssl/`    | `/mnt/data/supervisor/ssl/`           |
| `/addons/` | `/mnt/data/supervisor/addons/`        |

## Architecture

HAOS runs Docker containers (Supervisor, Core on port 8123, DNS on 172.30.32.3, addons) on a minimal Buildroot host. Host filesystem is read-only (erofs + overlay). All persistent data lives on the `hassos-data` partition (ext4) at `/mnt/data/`. System uses A/B kernel+system slots with RAUC for updates.

## Critical files in /config/

- `secrets.yaml` — MUST NOT expose or log contents
- `.storage/` — MUST NOT edit manually (managed by Core, manual edits = corruption)
- `home-assistant_v2.db` — MUST NOT edit (use the API instead)
- `configuration.yaml` — main HA config (requires confirmation to edit)

## FORBIDDEN

- `ha os datadisk wipe` — factory reset, erases EVERYTHING
- `rm -rf /config/` or `rm -rf /config/.storage/` — irreversible data loss
- Editing `home-assistant_v2.db` or any file in `.storage/`
- Exposing `secrets.yaml` contents, tokens (`$SUPERVISOR_TOKEN`, `~/.claude/.ha-token`), or running raw `curl` with API tokens

## Requires user confirmation

- Editing any YAML in `/config/`
- `ha core restart` / `ha core update` / `ha os update`
- `ha host reboot` / `ha host shutdown`
- Addon start/stop/restart/install/uninstall
- Creating/restoring backups
- Network configuration changes
- `apk add` (packages lost on container restart)

## Safe (no confirmation needed)

All `ha` diagnostic commands (`ha info`, `ha core info`, `ha core logs`, `ha core check`, `ha resolution info`), browsing `/config/` files, network diagnostics (`ping`, `nslookup`, `curl`), reading logs, listing backups.

## How to access HA data

Use the `ha-api` wrapper for all Core REST API calls. It handles authentication automatically — never use raw curl with tokens.

Usage: `ha-api <METHOD> <ENDPOINT> [JSON_BODY]`

- **Read states**: `ha-api GET /api/states`
- **Read single entity**: `ha-api GET /api/states/sensor.example`
- **Call service**: `ha-api POST /api/services/light/turn_on '{"entity_id":"light.example"}'`
- **Render template**: `ha-api POST /api/template '{"template":"{{ states(\"sensor.example\") }}"}'`
- **Automations**: `cat /config/automations.yaml`
- **Scenes**: `cat /config/scenes.yaml`
- **Scripts**: `cat /config/scripts.yaml`
- **Addons**: `ha addons`
- **System info**: `ha info`, `ha core info`, `ha os info`, `ha host info`

**IMPORTANT**: if possible do NOT use pipes (`|`) in commands — they trigger permission prompts. Use tools directly with file arguments:

- `jq '.data' file` instead of `cat file | jq '.data'`
- `grep pattern file` instead of `cat file | grep pattern`

## Things that will bite you

- `apk add` packages are lost on container restart — always warn the user
- MUST run `ha core check` before every `ha core restart`
- MUST create backup before updates: `ha backups new --name "before-update"`
- Stopping DNS addon (AdGuard/Pi-hole) kills name resolution system-wide
- Stopping MQTT broker breaks all MQTT-dependent addons
- Network config changes risk locking you out — always have a plan B

## Work principles

1. Before destructive operations — ask for confirmation + suggest backup
2. Before editing files — show what you intend to change
3. Before restarting Core — MUST validate with `ha core check`
4. Before updates — MUST backup with `ha backups new`
5. Log commands — state what you're running before you run it
6. If you don't know — say so directly instead of guessing

## Session start (MUST run at the beginning of every conversation)

### 1. Version check

1. Read local version: `cat ~/.claude/version.txt`
2. Fetch remote version: `curl -fsSL https://raw.githubusercontent.com/Argeento/haos-claude/main/dist/version.txt`
3. If they differ — inform the user that a new version is available and ask if they want to update now.
4. If the user agrees — run the update command yourself: `curl -sL https://raw.githubusercontent.com/Argeento/haos-claude/main/update.sh | bash`
5. If they match or the check fails (no internet) — say nothing, continue normally.

### 2. Core API check

Run: `ha-api GET /api/`

- If it returns `{"message": "API running."}` — ready to work.
- If it shows an error about missing token — **stop and tell the user** they must create a token first: go to **HA UI → Profile → Security → Long-Lived Access Tokens → Create Token**, then run: `echo "YOUR_TOKEN" > ~/.claude/.ha-token`
- If it returns 401 — token is invalid or expired. Tell the user to generate a new one.

### 3. Disclaimer

Display the following (in the user's language):

> **This software is provided without any warranty.** Before starting any work, create a full Home Assistant backup (`ha backups new --name "pre-claude"`) to protect your data in case of errors.
