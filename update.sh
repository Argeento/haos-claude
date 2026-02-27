#!/usr/bin/env bash
set -euo pipefail

# ── Constants ──────────────────────────────────────────────
REPO="Argeento/haos-claude"
BRANCH="main"
BASE_URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}/dist"
DEST="$HOME/.claude"

FILES=(
  "version.txt"
  "settings.json"
  "CLAUDE.md"
  "ha-api"
  "skills/ha-api-reference/SKILL.md"
  "skills/ha-automations/SKILL.md"
  "skills/ha-cli-reference/SKILL.md"
  "skills/ha-naming-organization/SKILL.md"
  "skills/ha-scenes-scripts/SKILL.md"
  "skills/ha-troubleshooting/SKILL.md"
)

# ── Helpers ────────────────────────────────────────────────
info()  { printf '\033[1;34m[INFO]\033[0m %s\n' "$1"; }
ok()    { printf '\033[1;32m[ OK ]\033[0m %s\n' "$1"; }
warn()  { printf '\033[1;33m[WARN]\033[0m %s\n' "$1"; }
fail()  { printf '\033[1;31m[ERROR]\033[0m %s\n' "$1" >&2; exit 1; }

# ── Header ─────────────────────────────────────────────────
printf '\n'
printf '  \033[1mhaos-claude updater\033[0m\n'
printf '  github.com/%s\n' "${REPO}"
printf '\n'

# ── Prerequisites ──────────────────────────────────────────
command -v curl >/dev/null 2>&1 || fail "curl is required but not found."

# ── Read saved language ────────────────────────────────────
LANGUAGE="English"
if [ -f "${DEST}/.haos-language" ]; then
  LANGUAGE="$(cat "${DEST}/.haos-language")"
  info "Language: ${LANGUAGE} (from previous installation)"
else
  warn "No saved language found. Defaulting to English."
fi

# ── Create directories ─────────────────────────────────────
for file in "${FILES[@]}"; do
  mkdir -p "${DEST}/$(dirname "${file}")"
done

# ── Download files ─────────────────────────────────────────
info "Downloading files..."
errors=0

for file in "${FILES[@]}"; do
  url="${BASE_URL}/${file}"
  dest_path="${DEST}/${file}"

  if curl -fsSL --retry 3 --retry-delay 2 -o "${dest_path}" "${url}"; then
    ok "  ${file}"
  else
    warn "  Failed: ${file}"
    errors=$((errors + 1))
  fi
done

[ "${errors}" -gt 0 ] && fail "Failed to download ${errors} file(s). Check your internet connection."

# ── Install ha-api wrapper ────────────────────────────────
chmod +x "${DEST}/ha-api"
ln -sf "${DEST}/ha-api" /usr/local/bin/ha-api 2>/dev/null || true

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
