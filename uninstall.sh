#!/usr/bin/env bash
# uninstall.sh — kde-displayset uninstaller
# License: GPL-3.0

set -euo pipefail

BIN_DIR="${HOME}/.local/bin"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/kde-displayset"

echo "[kde-displayset] Uninstalling..."

rm -f "${BIN_DIR}/kds-launch"
rm -f "${BIN_DIR}/kds-state.sh"

echo "[kde-displayset] Removed scripts from ${BIN_DIR}"
echo ""
echo "[kde-displayset] Your config directory has NOT been removed:"
echo "  ${CONFIG_DIR}"
echo ""
echo "  To remove it manually:"
echo "    rm -rf ${CONFIG_DIR}"
echo ""
echo "[kde-displayset] Uninstall complete."
