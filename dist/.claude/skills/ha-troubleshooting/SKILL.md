---
name: ha-troubleshooting
description: Diagnoses and resolves common Home Assistant problems. Use when user reports "HA won't start", "addon not working", "out of disk space", "Supervisor broken", "need to restore backup", "system not responding", "error in logs", or any troubleshooting and emergency recovery task on HAOS.
---

# Home Assistant Troubleshooting

## Instructions

### Step 1: Identify the problem category

Before taking any action, gather diagnostic information:

```bash
./haos cmd ha core info                          # Is Core running?
./haos cmd ha supervisor info                    # Is Supervisor healthy?
./haos cmd ha host info                          # Disk space? Kernel?
./haos cmd ha resolution info                    # Known problems + suggested fixes
./haos cmd ha core logs | tail -50               # Recent Core errors
```

### Step 2: Follow the appropriate procedure below

---

### HA won't start after config change

```bash
./haos cmd ha core logs | tail -50               # What crashed?
./haos cmd ha core check                         # Validate configuration
./haos cmd ha core restart --safe-mode           # Restart without custom integrations
# → fix configuration → ./haos cmd ha core restart
```

If safe mode works, the issue is in a custom integration or YAML config. Check logs for the specific error, fix it, then restart normally.

### Addon not working

```bash
./haos cmd ha addons info <slug>                 # Current status, version
./haos cmd ha addons logs <slug> | tail -50      # Logs — look for errors
./haos cmd ha addons restart <slug>              # Restart
./haos cmd ha addons rebuild <slug>              # Rebuild container (if restart didn't help)
```

If rebuild doesn't help, try uninstall + reinstall (warn user: addon config may be lost).

### Out of disk space

```bash
./haos cmd du -sh /config/* 2>/dev/null | sort -rh | head -20   # Largest files in config
./haos cmd du -sh /backup/* 2>/dev/null | sort -rh               # Backup sizes
./haos cmd ha backups list                                        # Old backups to delete?
```

Common culprits:
- Old backups (`./haos cmd ha backups remove <slug>`)
- Large `home-assistant_v2.db` (consider adjusting `recorder` settings)
- Log files or custom component caches

### Supervisor broken

```bash
./haos cmd ha supervisor info                    # Check status
./haos cmd ha supervisor repair                  # Repair Docker overlay
./haos cmd ha supervisor restart                 # Restart Supervisor
```

If Supervisor is completely unresponsive, a host reboot may be needed: `./haos cmd ha host reboot` (requires user confirmation).

### Restore from backup

```bash
./haos cmd ha backups list                       # Find the right backup
./haos cmd ha backups restore <slug>             # ⚠️ Overwrites current configuration
```

**Always confirm with the user before restoring** — this overwrites the active configuration.

### Integration or entity unavailable

```bash
./haos cmd ha core logs | tail -100              # Check for integration errors
# Look for "Unable to set up" or "unavailable" messages
```

Common causes:
- Network device offline — check `./haos cmd ping <device_ip>`
- API key expired — check integration settings in UI
- Integration updated with breaking changes — check HA release notes

### DNS resolution failing

```bash
./haos cmd ha dns info                           # DNS config
./haos cmd ha dns logs | tail -30                # DNS addon logs
./haos cmd ping 8.8.8.8                          # Can reach internet by IP?
./haos cmd nslookup google.com                   # Can resolve names?
```

If DNS addon (AdGuard/Pi-hole) was stopped, the network loses its resolver. Restart the DNS addon or reconfigure DNS settings.

## Troubleshooting

### Problem persists after following the steps above

1. Check `./haos cmd ha resolution info` for system-detected issues and suggested fixes
2. Review full Core logs: `./haos cmd ha core logs` (not just tail)
3. Try safe mode: `./haos cmd ha core restart --safe-mode`
4. As last resort: restore from a known-good backup

### Can't SSH into the system anymore

Cause: Network config change locked you out, or SSH addon crashed.
Solution: Use physical access (HDMI + keyboard) if available, or restore via the HA observer UI at `http://<HA_IP>:4357`.
