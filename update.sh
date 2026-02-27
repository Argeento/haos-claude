#!/usr/bin/env bash
set -euo pipefail

# ── Constants ──────────────────────────────────────────────
REPO="Argeento/haos-claude"
BRANCH="main"
BASE_URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}/dist"
DEST="$(pwd)"

# Files to download (paths match dist/ structure)
FILES=(
  "CLAUDE.md"
  ".claude/settings.json"
  ".claude/skills/ha-api-reference/SKILL.md"
  ".claude/skills/ha-automations/SKILL.md"
  ".claude/skills/ha-cli-reference/SKILL.md"
  ".claude/skills/ha-naming-organization/SKILL.md"
  ".claude/skills/ha-scenes-scripts/SKILL.md"
  ".claude/skills/ha-troubleshooting/SKILL.md"
  "haos"
  "version.txt"
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
printf '  \033[1mhaos-claude updater\033[0m\n'
printf '  github.com/%s\n' "${REPO}"
printf '\n'

# ── Prerequisites ──────────────────────────────────────────
command -v curl >/dev/null 2>&1 || fail "curl is required but not found."

if [ ! -f "${DEST}/.env" ]; then
  fail "Config not found at .env. Run the installer first (from this directory)."
fi

# ── Read language from .env ────────────────────────────────
source "${DEST}/.env"
LANGUAGE="${HAOS_LANGUAGE:-English}"
info "Language: ${LANGUAGE}"

# ── Download files ─────────────────────────────────────────
info "Downloading files..."
errors=0

for file in "${FILES[@]}"; do
  download "${BASE_URL}/${file}" "${DEST}/${file}" "${file}" || errors=$((errors + 1))
done

[ "${errors}" -gt 0 ] && fail "Failed to download ${errors} file(s). Check your internet connection."

# ── Make haos executable ─────────────────────────────────
chmod +x "${DEST}/haos"

# ── Re-inject language into CLAUDE.md ──────────────────────
if [ "${LANGUAGE}" != "English" ]; then
  claude_md="${DEST}/CLAUDE.md"
  lang_line="**Always communicate with the user in ${LANGUAGE}.**"
  tmp_content="$(cat "${claude_md}")"
  printf '%s\n\n%s\n' "${lang_line}" "${tmp_content}" > "${claude_md}"
  ok "Language instruction restored in CLAUDE.md"
fi

# ── Summary ────────────────────────────────────────────────
new_version="$(cat "${DEST}/version.txt")"
printf '\n'
printf '  \033[1;32m✓ Update complete!\033[0m (v%s)\n' "${new_version}"
printf '\n'
