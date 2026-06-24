#!/usr/bin/env bash
# install.sh — kde-displayset installer
# Installs scripts to ~/.local/bin/ and configs to ~/.config/kde-displayset/
# License: GPL-3.0

set -euo pipefail

BIN_DIR="${HOME}/.local/bin"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/kde-displayset"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "[kde-displayset] Installing..."

# Create directories
mkdir -p "$BIN_DIR"
mkdir -p "$CONFIG_DIR"

# Install scripts
install -m 755 "${SCRIPT_DIR}/src/kds-launch.sh" "${BIN_DIR}/kds-launch"
install -m 644 "${SCRIPT_DIR}/src/kds-state.sh"  "${BIN_DIR}/kds-state.sh"

# Install example config (always refreshed — it's a reference, not a user config)
install -m 644 "${SCRIPT_DIR}/configs/example.conf" "${CONFIG_DIR}/example.conf"
echo "[kde-displayset] Example config refreshed at ${CONFIG_DIR}/example.conf"

echo ""
echo "[kde-displayset] Installed:"
echo "  ${BIN_DIR}/kds-launch    (main launcher)"
echo "  ${BIN_DIR}/kds-state.sh  (state library)"
echo "  ${CONFIG_DIR}/           (config directory)"
echo ""

# Check if ~/.local/bin is on PATH
if ! echo "$PATH" | grep -q "${BIN_DIR}"; then
    echo "[kde-displayset] WARNING: ${BIN_DIR} is not in your PATH."
    echo "  Add this to your shell config (~/.bashrc, ~/.config/fish/config.fish, etc.):"
    echo ""
    echo "    fish:  fish_add_path ~/.local/bin"
    echo "    bash:  export PATH=\"\$HOME/.local/bin:\$PATH\""
    echo ""
fi

# Check kscreen-doctor is available
if ! command -v kscreen-doctor &>/dev/null; then
    echo "[kde-displayset] WARNING: kscreen-doctor not found."
    echo "  Install it with: sudo pacman -S kscreen"
    echo ""
fi

echo "[kde-displayset] Done. Run 'kds-launch --help' to get started."
