# haos-claude

Skills and system prompt for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) to manage Home Assistant OS.

Claude runs **locally on your PC** and connects to HAOS via SSH and the REST API — so your config, tokens, and Claude settings persist between reboots without any hacks.

## What's included

| Skill                      | Description                                                             |
|----------------------------|-------------------------------------------------------------------------|
| **ha-cli-reference**       | `ha` command-line tool — safe commands, core/addon management, backups  |
| **ha-api-reference**       | Supervisor API and Core REST API — endpoints, auth, curl examples       |
| **ha-automations**         | Creating and editing automations in YAML (2024.10+ syntax)              |
| **ha-scenes-scripts**      | Scenes, scripts, and input helpers                                      |
| **ha-naming-organization** | Entity naming, areas, labels, file organization, packages               |
| **ha-troubleshooting**     | Diagnosing common problems — startup failures, disk space, DNS, backups |

Plus a global `CLAUDE.md` that teaches Claude about safety boundaries, forbidden operations, and how to communicate with HAOS through the `haos` wrapper.

## How it works

A single wrapper script handles all communication with Home Assistant:

- **`haos cmd <command>`** — runs any command on HAOS via SSH (e.g., `haos cmd ha info`, `haos cmd cat /config/automations.yaml`)
- **`haos put <local> <remote>`** — uploads a local file to HAOS via SSH
- **`haos api <METHOD> <ENDPOINT> [BODY]`** — calls the HA Core REST API over HTTP (e.g., `haos api GET /api/states`)

Config (SSH host, HA URL, token) is stored in `~/.claude/.env`.

## Requirements

- [Home Assistant OS](https://www.home-assistant.io/installation/) with the [SSH & Web Terminal](https://github.com/hassio-addons/addon-ssh) addon (key-based auth)
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed on your PC
- A [Long-Lived Access Token](https://developers.home-assistant.io/docs/auth_api/#long-lived-access-token) from Home Assistant

## Install

Run on your **local PC** (not on HAOS):

```bash
curl -sL https://raw.githubusercontent.com/Argeento/haos-claude/main/install.sh | bash
```

The installer will:

1. Ask what language Claude should use
2. Download all files to `~/.claude/`
3. Create a config file at `~/.claude/.env` with default values

After installation, edit `~/.claude/.env` with your connection details (SSH host, HA URL, Long-Lived Access Token).

## After installation

Run `haos start` to launch Claude with automatic session checks.

```txt
~ $ haos start

> diagnose why my Zigbee devices are offline
> create an automation that turns off all lights at midnight
> show me which addons are using the most resources
```

## Update

Claude will automatically check for updates at the start of each session and suggest updating when a new version is available. You can also update manually:

```bash
curl -sL https://raw.githubusercontent.com/Argeento/haos-claude/main/update.sh | bash
```

Your language preference and connection config are preserved between updates.

## Reinstall

To start fresh (change language, re-download files). Your `.env` config is preserved:

```bash
curl -sL https://raw.githubusercontent.com/Argeento/haos-claude/main/install.sh | bash
```
