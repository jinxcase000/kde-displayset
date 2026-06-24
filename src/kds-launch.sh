#!/usr/bin/env bash
# kds-launch — KDE Displayset launcher
# Part of kde-displayset: https://github.com/jinxcase000/kde-displayset
# License: GPL-3.0
#
# Usage:
#   kds-launch <config-name>
#   kds-launch <config-name> --dry-run
#
# Config files live at: ~/.config/kde-displayset/<config-name>.conf
# See: ~/.config/kde-displayset/example.conf for full documentation.

set -euo pipefail

KDS_VERSION="1.0.0"
KDS_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/kde-displayset"
KDS_STATE_LIB="$(dirname "$(realpath "$0")")/kds-state.sh"

# ---------------------------------------------------------------------------
# Resolve kds-state.sh — handles both dev (src/) and installed (~/.local/bin)
# ---------------------------------------------------------------------------
if [[ ! -f "$KDS_STATE_LIB" ]]; then
    KDS_STATE_LIB="$(dirname "$(realpath "$0")")/kds-state.sh"
fi
if [[ ! -f "$KDS_STATE_LIB" ]]; then
    echo "[kds] ERROR: Cannot find kds-state.sh. Re-run install.sh." >&2
    exit 1
fi

source "$KDS_STATE_LIB"

# ---------------------------------------------------------------------------
# Usage / help
# ---------------------------------------------------------------------------
usage() {
    cat <<EOF
kde-displayset launcher v${KDS_VERSION}

Usage:
  kds-launch <config-name> [--dry-run]
  kds-launch --list
  kds-launch --status
  kds-launch --help

Options:
  <config-name>   Name of config file (without .conf) in ~/.config/kde-displayset/
  --dry-run       Show what would happen without applying any changes or launching
  --list          List all available config files
  --status        Show current HDR and VRR state
  --help          Show this help

Examples:
  kds-launch stalker2
  kds-launch vlc --dry-run
  kds-launch --status
EOF
}

# ---------------------------------------------------------------------------
# --list
# ---------------------------------------------------------------------------
list_configs() {
    echo "[kds] Available configs in ${KDS_CONFIG_DIR}:"
    local found=0
    for f in "$KDS_CONFIG_DIR"/*.conf; do
        [[ -f "$f" ]] || continue
        echo "  $(basename "${f%.conf}")"
        found=1
    done
    [[ $found -eq 0 ]] && echo "  (none found — create one from the example.conf)"
}

# ---------------------------------------------------------------------------
# --status
# ---------------------------------------------------------------------------
show_status() {
    kds_get_state || exit 1
    echo "[kds] Output:  ${KDS_OUTPUT}"
    echo "[kds] HDR:     ${KDS_HDR_CURRENT}"
    echo "[kds] VRR:     ${KDS_VRR_CURRENT}"
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
DRY_RUN=0
CONFIG_NAME=""

case "${1:-}" in
    --help|-h) usage; exit 0 ;;
    --list)    list_configs; exit 0 ;;
    --status)  show_status; exit 0 ;;
    "")        usage; exit 1 ;;
    *)         CONFIG_NAME="$1" ;;
esac

[[ "${2:-}" == "--dry-run" ]] && DRY_RUN=1

# ---------------------------------------------------------------------------
# Load config
# ---------------------------------------------------------------------------
CONFIG_FILE="${KDS_CONFIG_DIR}/${CONFIG_NAME}.conf"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "[kds] ERROR: Config not found: ${CONFIG_FILE}" >&2
    echo "[kds] Run 'kds-launch --list' to see available configs." >&2
    exit 1
fi

# Config defaults
ENTRY_HDR="passthrough"
ENTRY_VRR="passthrough"
EXIT_HDR="restore"
EXIT_VRR="restore"
COMMAND=""

source "$CONFIG_FILE"

if [[ -z "$COMMAND" ]]; then
    echo "[kds] ERROR: COMMAND is not set in ${CONFIG_FILE}" >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Snapshot current state
# ---------------------------------------------------------------------------
kds_get_state || exit 1

SNAPSHOT_HDR="$KDS_HDR_CURRENT"
SNAPSHOT_VRR="$KDS_VRR_CURRENT"

echo "[kds] Current state — HDR: ${SNAPSHOT_HDR}  VRR: ${SNAPSHOT_VRR}"
echo "[kds] Config '${CONFIG_NAME}' — Entry HDR: ${ENTRY_HDR}  Entry VRR: ${ENTRY_VRR}  Exit HDR: ${EXIT_HDR}  Exit VRR: ${EXIT_VRR}"

# ---------------------------------------------------------------------------
# Resolve exit state (substitute 'restore' with snapshot values)
# ---------------------------------------------------------------------------
[[ "$EXIT_HDR" == "restore" ]] && EXIT_HDR="$SNAPSHOT_HDR"
[[ "$EXIT_VRR" == "restore" ]] && EXIT_VRR="$SNAPSHOT_VRR"

# ---------------------------------------------------------------------------
# Apply entry state
# ---------------------------------------------------------------------------
apply_entry() {
    if [[ "$ENTRY_HDR" != "passthrough" && "$ENTRY_HDR" != "$SNAPSHOT_HDR" ]]; then
        if [[ $DRY_RUN -eq 1 ]]; then
            echo "[kds] DRY-RUN: would set HDR to ${ENTRY_HDR}"
        else
            kds_set_hdr "$ENTRY_HDR"
        fi
    else
        echo "[kds] HDR: no change needed (${ENTRY_HDR})"
    fi

    if [[ "$ENTRY_VRR" != "passthrough" && "$ENTRY_VRR" != "$SNAPSHOT_VRR" ]]; then
        if [[ $DRY_RUN -eq 1 ]]; then
            echo "[kds] DRY-RUN: would set VRR to ${ENTRY_VRR}"
        else
            kds_set_vrr "$ENTRY_VRR"
        fi
    else
        echo "[kds] VRR: no change needed (${ENTRY_VRR})"
    fi
}

# ---------------------------------------------------------------------------
# Apply exit state
# ---------------------------------------------------------------------------
apply_exit() {
    echo "[kds] App exited. Restoring display state..."

    if [[ "$EXIT_HDR" != "$ENTRY_HDR" ]] || [[ "$EXIT_HDR" != "$(kds_get_state; echo $KDS_HDR_CURRENT)" ]]; then
        if [[ $DRY_RUN -eq 1 ]]; then
            echo "[kds] DRY-RUN: would set HDR to ${EXIT_HDR}"
        else
            kds_set_hdr "$EXIT_HDR"
        fi
    fi

    if [[ "$EXIT_VRR" != "$ENTRY_VRR" ]] || [[ "$EXIT_VRR" != "$(kds_get_state; echo $KDS_VRR_CURRENT)" ]]; then
        if [[ $DRY_RUN -eq 1 ]]; then
            echo "[kds] DRY-RUN: would set VRR to ${EXIT_VRR}"
        else
            kds_set_vrr "$EXIT_VRR"
        fi
    fi

    echo "[kds] Done."
}

# Register exit handler
trap apply_exit EXIT

# ---------------------------------------------------------------------------
# Launch
# ---------------------------------------------------------------------------
apply_entry

if [[ $DRY_RUN -eq 1 ]]; then
    echo "[kds] DRY-RUN: would launch: ${COMMAND}"
    echo "[kds] DRY-RUN: on exit would set — HDR: ${EXIT_HDR}  VRR: ${EXIT_VRR}"
    trap - EXIT
    exit 0
fi

echo "[kds] Launching: ${COMMAND}"
eval "$COMMAND"
