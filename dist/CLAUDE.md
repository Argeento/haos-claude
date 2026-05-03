# CLAUDE.md — Home Assistant OS

You are running **locally** on the user's PC, connected to Home Assistant OS (HAOS). Use the `./haos` wrapper for ALL interactions — never raw `ssh`, `scp`, `curl`, or WebSocket scripts.

## The wrapper

- **`./haos cmd <command>`** — SSH (e.g., `./haos cmd ha info`, `./haos cmd cat /config/automations.yaml`)
- **`./haos put <local> <remote>`** — SCP local file to HAOS
- **`./haos api <METHOD> <ENDPOINT> [BODY]`** — HA Core REST API
- **`./haos ws <TYPE> [JSON_DATA]`** — HA WebSocket API

Both `./haos api` and `./haos ws` accept `--jq '<filter>'` or `--py <script>` for JSON processing — see the `ha-api-reference` skill for syntax. For REST/services/templates/history use `api`; for registries (devices, entities, areas, floors, labels, integrations, lovelace) use `ws`. For CLI details see `ha-cli-reference`; for dashboards see `ha-dashboards`.

When a task is impossible via any API, tell the user what to do in the HA UI. Do NOT attempt workarounds.

## Local environment

- Only `./haos` commands are auto-allowed. **No shell pipes (`|`) or redirects (`>`)** — they will be blocked.
- Temp files go to `./tmp/` (next to `haos`), never `/tmp/` or global paths.
- **Never write scripts that call `./haos` via subprocess** — breaks on Windows and bypasses permissions. For batch ops, call `./haos` sequentially via the Bash tool.
- `jq` and `python` are local only — NOT available on HAOS.
- Config is in `~/.claude/.env`. **Never read or expose it** — it contains tokens.

## HAOS facts you may need

- HAOS is Buildroot host (read-only) running Docker containers (Supervisor, Core on :8123, addons). Persistent data lives at `/mnt/data/`.
- The SSH addon container is Alpine with `ha`, `jq`, `curl`, `cat`. Python is NOT on HAOS.

## Response style

- Be concise. No preamble, no recap of the user's request, no trailing summary of what you just did.
- State commands before running them in one short sentence — not paragraphs.
- For lists (entities, devices, automations) prefer compact tables or one-line items, not bullet-per-attribute breakdowns. Default to ≤20 items unless asked for more.
- Don't repeat data the user can already see in the previous tool output.

## FORBIDDEN

- `./haos cmd ha os datadisk wipe` — factory reset
- `./haos cmd rm -rf /config/` or anything under `/config/.storage/` — irreversible
- Editing `home-assistant_v2.db` or any file in `.storage/` (managed by Core, manual edits = corruption)
- Exposing `secrets.yaml`, `~/.claude/.env`, or any tokens
- Installing packages on the user's PC (`pip install`, `npm install`, etc.)

## Requires user confirmation

- Editing any YAML on HAOS or `configuration.yaml`
- `ha core restart` / `ha core update` / `ha os update` / `ha host reboot` / `ha host shutdown`
- Addon install/uninstall/start/stop
- Creating/restoring backups
- Network changes
- Deleting entities/devices/integrations via `./haos ws`

Diagnostics, reads, `GET` calls, listing — all safe, no confirmation needed.

## Work principles

1. Before destructive ops — ask + suggest a backup
2. Before editing — show the diff/intent
3. Before `ha core restart` — `./haos cmd ha core check` first
4. Before updates — `./haos cmd ha backups new` first
5. If you don't know — say so, don't guess
