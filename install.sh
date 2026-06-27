#!/usr/bin/env bash
#
# PPT Master — one-shot installer for the Claude Code skill (macOS / Linux)
#
# Usage:
#   git clone https://github.com/msjh172-ship-it/ppt-master.git
#   cd ppt-master
#   ./install.sh
#
# What it does:
#   1. Copies skills/ppt-master into ~/.claude/skills/ppt-master
#   2. Creates an isolated Python venv at ~/.claude/skills/ppt-master/.venv
#   3. Installs the Python dependencies into that venv
#
# It does NOT touch your system Python, and it never copies your .env / API keys.
# Windows users: see docs/windows-installation.md instead.

set -euo pipefail

SKILL_NAME="ppt-master"
SKILLS_DIR="${HOME}/.claude/skills"
DEST="${SKILLS_DIR}/${SKILL_NAME}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="${SCRIPT_DIR}/skills/${SKILL_NAME}"

echo "==> PPT Master installer"

# --- locate Python 3 ---------------------------------------------------------
PY="$(command -v python3 || true)"
if [ -z "${PY}" ]; then
  echo "ERROR: python3 not found. Install Python 3.10+ first." >&2
  exit 1
fi
echo "    Python: $(${PY} --version 2>&1)"

# --- sanity check source -----------------------------------------------------
if [ ! -d "${SRC}" ]; then
  echo "ERROR: skill source not found at ${SRC}" >&2
  echo "       Run this script from the repo root (the folder containing ./skills/ppt-master)." >&2
  exit 1
fi

# --- copy skill files --------------------------------------------------------
echo "==> Copying skill files -> ${DEST}"
mkdir -p "${SKILLS_DIR}"
if command -v rsync >/dev/null 2>&1; then
  rsync -a --exclude='.venv' --exclude='__pycache__' --exclude='*.pyc' --exclude='.env' \
    "${SRC}/" "${DEST}/"
else
  mkdir -p "${DEST}"
  cp -R "${SRC}/." "${DEST}/"
  rm -rf "${DEST}/.venv" 2>/dev/null || true
fi

# --- create venv + install deps ---------------------------------------------
echo "==> Creating virtual environment"
"${PY}" -m venv "${DEST}/.venv"

echo "==> Installing dependencies (this can take a few minutes)"
"${DEST}/.venv/bin/python" -m pip install --upgrade pip
"${DEST}/.venv/bin/python" -m pip install -r "${DEST}/requirements.txt"

# --- verify ------------------------------------------------------------------
echo "==> Verifying key packages"
"${DEST}/.venv/bin/python" - <<'PY'
import importlib.util
mods = ["pptx", "fitz", "PIL", "flask", "edge_tts", "requests",
        "bs4", "svglib", "reportlab", "openpyxl", "numpy"]
missing = [m for m in mods if importlib.util.find_spec(m) is None]
print("    OK — all key packages importable" if not missing
      else "    MISSING: " + ", ".join(missing))
PY

cat <<EOF

Done.
  Skill installed at : ${DEST}
  venv interpreter   : ${DEST}/.venv/bin/python

Next steps:
  - Restart Claude Code so it picks up the 'ppt-master' skill.
  - (Optional) For cloud image / TTS backends, create ${DEST}/.env
    using ${DEST}/.env.example as a template.
EOF
