# haos-claude

Skills and system prompt for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) on Home Assistant OS.

Makes Claude aware of the HAOS environment, safety boundaries, CLI commands, APIs, and best practices — so you can manage your smart home from the terminal without worrying about breaking things.

## What's included

| Skill                      | Description                                                             |
|----------------------------|-------------------------------------------------------------------------|
| **ha-cli-reference**       | `ha` command-line tool — safe commands, core/addon management, backups  |
| **ha-api-reference**       | Supervisor API and Core REST API — endpoints, auth, curl examples       |
| **ha-automations**         | Creating and editing automations in YAML (2024.10+ syntax)              |
| **ha-scenes-scripts**      | Scenes, scripts, and input helpers                                      |
| **ha-naming-organization** | Entity naming, areas, labels, file organization, packages               |
| **ha-troubleshooting**     | Diagnosing common problems — startup failures, disk space, DNS, backups |

Plus a global `CLAUDE.md` that teaches Claude about the SSH addon container, forbidden operations, and safe work principles.

## Install

SSH into your Home Assistant and run:

```bash
curl -sL https://raw.githubusercontent.com/Argeento/haos-claude/main/install.sh | bash
```

The installer will ask you what language Claude should use, then download everything to `~/.claude/`.

## Requirements

- [Home Assistant OS](https://www.home-assistant.io/installation/) with the [SSH & Web Terminal](https://github.com/hassio-addons/addon-ssh) addon
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed in the SSH addon

## After installation

Just run `claude` in the SSH terminal. All skills are loaded automatically.

```txt
~ $ claude

> diagnose why my Zigbee devices are offline
> create an automation that turns off all lights at midnight
> show me which addons are using the most resources
```

## Update

Claude will automatically check for updates at the start of each session and suggest updating when a new version is available. You can also update manually:

```bash
curl -sL https://raw.githubusercontent.com/Argeento/haos-claude/main/update.sh | bash
```

Your language preference is preserved between updates.

## Reinstall

To start fresh (re-select language, etc.):

```bash
curl -sL https://raw.githubusercontent.com/Argeento/haos-claude/main/install.sh | bash
```
