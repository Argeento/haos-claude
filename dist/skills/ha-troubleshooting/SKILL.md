---
name: ha-troubleshooting
description: Diagnoses and resolves common Home Assistant problems. Use when user reports "HA won't start", "addon not working", "out of disk space", "Supervisor broken", "need to restore backup", "system not responding", "error in logs", or any troubleshooting and emergency recovery task on HAOS.
---

# Home Assistant Troubleshooting

## Instructions

### Step 1: Identify the problem category

Before taking any action, gather diagnostic information:

```bash
ha core info                          # Is Core running?
ha supervisor info                    # Is Supervisor healthy?
ha host info                          # Disk space? Kernel?
ha resolution info                    # Known problems + suggested fixes
ha core logs | tail -50               # Recent Core errors
```

### Step 2: Follow the appropriate procedure below

---

### HA won't start after config change

```bash
ha core logs | tail -50               # What crashed?
ha core check                         # Validate configuration
ha core restart --safe-mode           # Restart without custom integrations
# → fix configuration → ha core restart
```

If safe mode works, the issue is in a custom integration or YAML config. Check logs for the specific error, fix it, then restart normally.

### Addon not working

```bash
ha addons info <slug>                 # Current status, version
ha addons logs <slug> | tail -50      # Logs — look for errors
ha addons restart <slug>              # Restart
ha addons rebuild <slug>              # Rebuild container (if restart didn't help)
```

If rebuild doesn't help, try uninstall + reinstall (warn user: addon config may be lost).

### Out of disk space

```bash
du -sh /config/* 2>/dev/null | sort -rh | head -20   # Largest files in config
du -sh /backup/* 2>/dev/null | sort -rh               # Backup sizes
ha backups list                                        # Old backups to delete?
```

Common culprits:
- Old backups (`ha backups remove <slug>`)
- Large `home-assistant_v2.db` (consider adjusting `recorder` settings)
- Log files or custom component caches

### Supervisor broken

```bash
ha supervisor info                    # Check status
ha supervisor repair                  # Repair Docker overlay
ha supervisor restart                 # Restart Supervisor
```

If Supervisor is completely unresponsive, a host reboot may be needed: `ha host reboot` (requires user confirmation).

### Restore from backup

```bash
ha backups list                       # Find the right backup
ha backups restore <slug>             # ⚠️ Overwrites current configuration
```

**Always confirm with the user before restoring** — this overwrites the active configuration.

### Integration or entity unavailable

```bash
ha core logs | tail -100              # Check for integration errors
# Look for "Unable to set up" or "unavailable" messages
```

Common causes:
- Network device offline — check `ping <device_ip>`
- API key expired — check integration settings in UI
- Integration updated with breaking changes — check HA release notes

### DNS resolution failing

```bash
ha dns info                           # DNS config
ha dns logs | tail -30                # DNS addon logs
ping 8.8.8.8                          # Can reach internet by IP?
nslookup google.com                   # Can resolve names?
```

If DNS addon (AdGuard/Pi-hole) was stopped, the network loses its resolver. Restart the DNS addon or reconfigure DNS settings.

## Troubleshooting

### Problem persists after following the steps above

1. Check `ha resolution info` for system-detected issues and suggested fixes
2. Review full Core logs: `ha core logs` (not just tail)
3. Try safe mode: `ha core restart --safe-mode`
4. As last resort: restore from a known-good backup

### Can't SSH into the system anymore

Cause: Network config change locked you out, or SSH addon crashed.
Solution: Use physical access (HDMI + keyboard) if available, or restore via the HA observer UI at `http://<HA_IP>:4357`.
