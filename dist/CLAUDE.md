# CLAUDE.md — Home Assistant OS

You are inside the **SSH addon container** (Alpine Linux) on HAOS — NOT the bare metal host.

## Environment

- **Container**: Alpine Linux, `root` (container root, not host root)
- **Available**: `ha` CLI, `apk` (lost on restart), `/config`, `/share`, `/media`, `/backup`, `/ssl`
- **NOT available**: `docker`, host filesystem, Buildroot

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
- Exposing `secrets.yaml` contents or tokens (`$SUPERVISOR_TOKEN`, LLAT)

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
