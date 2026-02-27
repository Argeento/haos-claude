---
name: ha-cli-reference
description: Reference for Home Assistant CLI commands via the ha command-line tool. Use when user asks to "restart HA", "update Core", "check logs", "manage addons", "create backup", "reboot", "check network", "install addon", "update OS", or any task involving ha CLI commands for diagnostics, core management, addon management, backups, system/host/OS, or network configuration.
---

# Home Assistant CLI Reference

## Instructions

### Diagnostics (safe, read-only)

These commands are always safe to run without user confirmation:

```bash
./haos cmd ha info                               # General system overview
./haos cmd ha core info                          # Core version, IP, status
./haos cmd ha core logs                          # Core logs
./haos cmd ha core logs --follow                 # Live logs
./haos cmd ha core check                         # Validate configuration.yaml
./haos cmd ha supervisor info                    # Supervisor version
./haos cmd ha supervisor logs                    # Supervisor logs
./haos cmd ha os info                            # HAOS version, boot slot, board
./haos cmd ha host info                          # Hostname, kernel, disk free/used
./haos cmd ha hardware info                      # USB, serial, disks, GPIO
./haos cmd ha network info                       # Interfaces, IP, DNS, gateway
./haos cmd ha dns info                           # DNS configuration
./haos cmd ha resolution info                    # Problems and fix suggestions
./haos cmd ha backups list                       # List backups
./haos cmd ha addons                             # List addons with statuses
./haos cmd ha addons info <slug>                 # Details of a specific addon
./haos cmd ha addons logs <slug>                 # Addon logs
```

The `--raw-json` flag returns JSON instead of a table — useful for parsing.

### Core Management

**Requires user confirmation.** Always run `./haos cmd ha core check` before restarting.

```bash
./haos cmd ha core restart                       # Restart after config change
./haos cmd ha core restart --safe-mode           # Restart without custom integrations
./haos cmd ha core update                        # Update to latest stable
./haos cmd ha core update --version X.Y.Z       # Update to specific version
./haos cmd ha core stop                          # Stop Core
./haos cmd ha core start                         # Start Core
./haos cmd ha core rebuild                       # Rebuild container
```

### Addon Management

**Requires user confirmation** for start/stop/restart/install/uninstall.

```bash
./haos cmd ha addons install <slug>              # Install
./haos cmd ha addons uninstall <slug>            # Uninstall
./haos cmd ha addons start <slug>                # Start
./haos cmd ha addons stop <slug>                 # Stop
./haos cmd ha addons restart <slug>              # Restart
./haos cmd ha addons update <slug>               # Update
./haos cmd ha addons rebuild <slug>              # Rebuild
./haos cmd ha addons options <slug> --options='{"key":"val"}'  # Change options
```

### Backups

**Requires user confirmation** for creating/restoring backups.

```bash
./haos cmd ha backups list                       # List
./haos cmd ha backups new --name <name>          # New full backup
./haos cmd ha backups new --name <n> --folders homeassistant  # HA config only
./haos cmd ha backups restore <slug>             # Restore (⚠️ overwrites!)
./haos cmd ha backups remove <slug>              # Remove backup
./haos cmd ha backups reload                     # Refresh list
```

### System / Host / OS

**Requires user confirmation.** Always backup before updates.

```bash
./haos cmd ha host reboot                        # Reboot machine
./haos cmd ha host shutdown                      # Shutdown
./haos cmd ha os update                          # Update HAOS
./haos cmd ha supervisor update                  # Update Supervisor
./haos cmd ha supervisor reload                  # Reload config
./haos cmd ha supervisor restart                 # Restart Supervisor
./haos cmd ha supervisor repair                  # Repair Docker overlay
```

### Network

**Requires user confirmation.** Risk of locking yourself out — prepare a plan B.

```bash
./haos cmd ha network info                       # Current configuration
./haos cmd ha network update <iface> --ipv4-method static --ipv4-address X.X.X.X/24 --ipv4-gateway X.X.X.1
./haos cmd ha network update <iface> --ipv4-method auto   # Switch back to DHCP
```

## Examples

### Check system health

```bash
./haos cmd ha core check                         # Validate config
./haos cmd ha resolution info                    # Known problems
./haos cmd ha host info                          # Disk space
./haos cmd ha core logs | tail -50               # Recent Core logs
```

### Safe addon restart workflow

```bash
./haos cmd ha addons info <slug>                 # Check current status
./haos cmd ha addons logs <slug> | tail -30      # Check logs first
./haos cmd ha addons restart <slug>              # Restart
./haos cmd ha addons logs <slug> | tail -10      # Verify it started
```

### Safe update workflow

```bash
./haos cmd ha backups new --name "before-update" # Backup first
./haos cmd ha core update                        # Then update
./haos cmd ha core logs | tail -30               # Check for errors
```

## Troubleshooting

### Command returns "error" or no output

Cause: Core or Supervisor might be unresponsive.
Solution: Try `./haos cmd ha supervisor info` first. If it fails too, the Supervisor itself may need a restart: `./haos cmd ha supervisor restart`.

### "Unknown command" error

Cause: Typo or wrong subcommand.
Solution: Run the base command without arguments (e.g. `./haos cmd ha core`, `./haos cmd ha addons`) to see available subcommands.

### Addon slug not found

Cause: Using the wrong slug name.
Solution: Run `./haos cmd ha addons` to list all installed addons with their correct slugs.
