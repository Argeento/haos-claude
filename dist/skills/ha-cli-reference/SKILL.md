---
name: ha-cli-reference
description: Reference for Home Assistant CLI commands via the ha command-line tool. Use when user asks to "restart HA", "update Core", "check logs", "manage addons", "create backup", "reboot", "check network", "install addon", "update OS", or any task involving ha CLI commands for diagnostics, core management, addon management, backups, system/host/OS, or network configuration.
---

# Home Assistant CLI Reference

## Instructions

### Diagnostics (safe, read-only)

These commands are always safe to run without user confirmation:

```bash
ha info                               # General system overview
ha core info                          # Core version, IP, status
ha core logs                          # Core logs
ha core logs --follow                 # Live logs
ha core check                         # Validate configuration.yaml
ha supervisor info                    # Supervisor version
ha supervisor logs                    # Supervisor logs
ha os info                            # HAOS version, boot slot, board
ha host info                          # Hostname, kernel, disk free/used
ha hardware info                      # USB, serial, disks, GPIO
ha network info                       # Interfaces, IP, DNS, gateway
ha dns info                           # DNS configuration
ha resolution info                    # Problems and fix suggestions
ha backups list                       # List backups
ha addons                             # List addons with statuses
ha addons info <slug>                 # Details of a specific addon
ha addons logs <slug>                 # Addon logs
```

The `--raw-json` flag returns JSON instead of a table — useful for parsing.

### Core Management

**Requires user confirmation.** Always run `ha core check` before restarting.

```bash
ha core restart                       # Restart after config change
ha core restart --safe-mode           # Restart without custom integrations
ha core update                        # Update to latest stable
ha core update --version X.Y.Z       # Update to specific version
ha core stop                          # Stop Core
ha core start                         # Start Core
ha core rebuild                       # Rebuild container
```

### Addon Management

**Requires user confirmation** for start/stop/restart/install/uninstall.

```bash
ha addons install <slug>              # Install
ha addons uninstall <slug>            # Uninstall
ha addons start <slug>                # Start
ha addons stop <slug>                 # Stop
ha addons restart <slug>              # Restart
ha addons update <slug>               # Update
ha addons rebuild <slug>              # Rebuild
ha addons options <slug> --options='{"key":"val"}'  # Change options
```

### Backups

**Requires user confirmation** for creating/restoring backups.

```bash
ha backups list                       # List
ha backups new --name <name>          # New full backup
ha backups new --name <n> --folders homeassistant  # HA config only
ha backups restore <slug>             # Restore (⚠️ overwrites!)
ha backups remove <slug>              # Remove backup
ha backups reload                     # Refresh list
```

### System / Host / OS

**Requires user confirmation.** Always backup before updates.

```bash
ha host reboot                        # Reboot machine
ha host shutdown                      # Shutdown
ha os update                          # Update HAOS
ha supervisor update                  # Update Supervisor
ha supervisor reload                  # Reload config
ha supervisor restart                 # Restart Supervisor
ha supervisor repair                  # Repair Docker overlay
```

### Network

**Requires user confirmation.** Risk of locking yourself out — prepare a plan B.

```bash
ha network info                       # Current configuration
ha network update <iface> --ipv4-method static --ipv4-address X.X.X.X/24 --ipv4-gateway X.X.X.1
ha network update <iface> --ipv4-method auto   # Switch back to DHCP
```

## Examples

### Check system health

```bash
ha core check                         # Validate config
ha resolution info                    # Known problems
ha host info                          # Disk space
ha core logs | tail -50               # Recent Core logs
```

### Safe addon restart workflow

```bash
ha addons info <slug>                 # Check current status
ha addons logs <slug> | tail -30      # Check logs first
ha addons restart <slug>              # Restart
ha addons logs <slug> | tail -10      # Verify it started
```

### Safe update workflow

```bash
ha backups new --name "before-update" # Backup first
ha core update                        # Then update
ha core logs | tail -30               # Check for errors
```

## Troubleshooting

### Command returns "error" or no output

Cause: Core or Supervisor might be unresponsive.
Solution: Try `ha supervisor info` first. If it fails too, the Supervisor itself may need a restart: `ha supervisor restart`.

### "Unknown command" error

Cause: Typo or wrong subcommand.
Solution: Run the base command without arguments (e.g. `ha core`, `ha addons`) to see available subcommands.

### Addon slug not found

Cause: Using the wrong slug name.
Solution: Run `ha addons` to list all installed addons with their correct slugs.
