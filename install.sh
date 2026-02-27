#!/usr/bin/env bash
set -euo pipefail

# ── Constants ──────────────────────────────────────────────
REPO="Argeento/haos-claude"
BRANCH="main"
BASE_URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}/dist"
DEST="$HOME/.claude"

# Files that go into ~/.claude/
CLAUDE_FILES=(
  ".claude/CLAUDE.md"
  ".claude/settings.json"
  ".claude/skills/ha-api-reference/SKILL.md"
  ".claude/skills/ha-automations/SKILL.md"
  ".claude/skills/ha-cli-reference/SKILL.md"
  ".claude/skills/ha-naming-organization/SKILL.md"
  ".claude/skills/ha-scenes-scripts/SKILL.md"
  ".claude/skills/ha-troubleshooting/SKILL.md"
)

# Scripts that go into PATH
BIN_FILES=(
  "haos"
)

# ── Helpers ────────────────────────────────────────────────
info()  { printf '\033[1;34m[INFO]\033[0m %s\n' "$1"; }
ok()    { printf '\033[1;32m[ OK ]\033[0m %s\n' "$1"; }
warn()  { printf '\033[1;33m[WARN]\033[0m %s\n' "$1"; }
fail()  { printf '\033[1;31m[ERROR]\033[0m %s\n' "$1" >&2; exit 1; }

download() {
  local url="$1" dest_path="$2" label="$3"
  mkdir -p "$(dirname "${dest_path}")"
  if curl -fsSL --retry 3 --retry-delay 2 -o "${dest_path}" "${url}"; then
    ok "  ${label}"
    return 0
  else
    warn "  Failed: ${label}"
    return 1
  fi
}

# ── Header ─────────────────────────────────────────────────
printf '\n'
printf '  \033[1mhaos-claude installer\033[0m\n'
printf '  github.com/%s\n' "${REPO}"
printf '\n'

# ── Prerequisites ──────────────────────────────────────────
command -v curl >/dev/null 2>&1 || fail "curl is required but not found."
command -v ssh  >/dev/null 2>&1 || fail "ssh is required but not found."

# ── Create .env with defaults ─────────────────────────────
mkdir -p "${DEST}"

if [ -f "${DEST}/.env" ]; then
  info "Config already exists at ${DEST}/.env — keeping it."
else
  cat > "${DEST}/.env" <<'ENVFILE'
# haos-claude config
# Edit this file with your Home Assistant connection details

# Language for Claude to communicate in (e.g., English, Polski, Deutsch, Français, Español)
HAOS_LANGUAGE="English"

# SSH connection (SSH & Web Terminal addon with key-based auth)
HAOS_SSH_HOST="root@homeassistant.local"
HAOS_SSH_PORT="22"

# Home Assistant REST API
# URL of your Home Assistant instance
HA_URL="http://homeassistant.local:8123"

# Long-Lived Access Token
# Create one in HA UI: Profile → Security → Long-Lived Access Tokens
# http://homeassistant.local:8123/profile/security
HA_TOKEN="paste-your-token-here"
ENVFILE
  chmod 600 "${DEST}/.env"
  ok "Config created at ${DEST}/.env"
fi

# ── Download files ─────────────────────────────────────────
printf '\n'
info "Downloading files..."
errors=0

# version.txt → ~/.claude/version.txt
download "${BASE_URL}/version.txt" "${DEST}/version.txt" "version.txt" || errors=$((errors + 1))

# .claude/* files → ~/.claude/*
for file in "${CLAUDE_FILES[@]}"; do
  dest_name="${file#.claude/}"
  download "${BASE_URL}/${file}" "${DEST}/${dest_name}" "${dest_name}" || errors=$((errors + 1))
done

# Bin scripts → ~/.claude/ (then symlinked to PATH)
for file in "${BIN_FILES[@]}"; do
  download "${BASE_URL}/${file}" "${DEST}/${file}" "${file}" || errors=$((errors + 1))
done

[ "${errors}" -gt 0 ] && fail "Failed to download ${errors} file(s). Check your internet connection."

# ── Install wrappers ──────────────────────────────────────
chmod +x "${DEST}/haos"
ok "Wrapper installed: ${DEST}/haos"

# ── Inject language into CLAUDE.md ─────────────────────────
source "${DEST}/.env"
LANGUAGE="${HAOS_LANGUAGE:-English}"
if [ "${LANGUAGE}" != "English" ]; then
  claude_md="${DEST}/CLAUDE.md"
  lang_line="**Always communicate with the user in ${LANGUAGE}.**"
  tmp_content="$(cat "${claude_md}")"
  printf '%s\n\n%s\n' "${lang_line}" "${tmp_content}" > "${claude_md}"
  ok "Language instruction added to CLAUDE.md"
fi

# ── Summary ────────────────────────────────────────────────
version="$(cat "${DEST}/version.txt")"
printf '\n'
printf '  \033[1;32m✓ Installation complete!\033[0m (v%s)\n' "${version}"
printf '\n'
printf '  Location:  %s\n' "${DEST}"
printf '  Config:    %s/.env\n' "${DEST}"

# ── Next steps ────────────────────────────────────────────
printf '\n'
printf '  \033[1mNext steps:\033[0m\n'
printf '\n'
printf '  1. Edit \033[1m%s/.env\033[0m with your settings:\n' "${DEST}"
printf '     - Language, SSH host and port\n'
printf '     - Home Assistant URL\n'
printf '     - Long-Lived Access Token (HA UI → Profile → Security)\n'
printf '\n'
printf '  2. Run \033[38;2;217;119;6mhaos start\033[0m to launch Claude\n'

if ! command -v claude >/dev/null 2>&1; then
  printf '\n'
  warn "Claude Code is not installed."
  printf '  Install it first: \033[4mhttps://docs.anthropic.com/en/docs/claude-code/overview\033[0m\n'
fi
printf '\n'
