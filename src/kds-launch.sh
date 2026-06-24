#!/usr/bin/env bash
# kds-launch — KDE Displayset launcher
# Part of kde-displayset: https://github.com/jinxcase000/kde-displayset
# License: GPL-3.0
#
# Usage:
#   kds-launch %command%                  # Steam/Heroic: auto-detect config
#   kds-launch=myapp %command%            # Steam/Heroic: force a named config
#   kds-launch vlc                        # Standalone app: load vlc.conf or NAME=vlc
#   kds-launch --list
#   kds-launch --status
#   kds-launch --help

set -euo pipefail

KDS_VERSION="1.1.0"
KDS_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/kde-displayset"
KDS_STATE_LIB="$(dirname "$(realpath "$0")")/kds-state.sh"

if [[ ! -f "$KDS_STATE_LIB" ]]; then
    echo "[kds] ERROR: Cannot find kds-state.sh. Re-run install.sh." >&2
    exit 1
fi

source "$KDS_STATE_LIB"

# ---------------------------------------------------------------------------
# Launcher env var map
# Add new launchers here as they are discovered.
# Format: LAUNCHER_NAME:ENV_VAR
# ---------------------------------------------------------------------------
declare -A LAUNCHER_ENV_MAP=(
    [steam]="SteamAppId"
    [heroic]="HEROIC_APP_NAME"
)

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------
usage() {
    cat <<EOF
kde-displayset v${KDS_VERSION}

Usage:
  kds-launch %command%              Auto-detect config from launcher env vars, pass through command
  kds-launch=myapp %command%        Force a named config, pass through command
  kds-launch vlc                    Standalone app: find vlc.conf or NAME=vlc, run COMMAND from config
  kds-launch --list                 List all configs
  kds-launch --status               Show current HDR and VRR state
  kds-launch --help                 Show this help

  Append --dry-run to any launch invocation to preview without applying changes.

Steam launch options examples:
  kds-launch %command%
  kds-launch=stalker2 %command%
EOF
}

# ---------------------------------------------------------------------------
# --list: show all configs with NAME if set, filename otherwise
# ---------------------------------------------------------------------------
list_configs() {
    echo "[kds] Available configs in ${KDS_CONFIG_DIR}:"
    local found=0
    for f in "$KDS_CONFIG_DIR"/*.conf; do
        [[ -f "$f" ]] || continue
        local fname
        fname="$(basename "${f%.conf}")"
        # Try to extract NAME field
        local name_field
        name_field=$(grep -m1 "^NAME=" "$f" 2>/dev/null | cut -d= -f2- | tr -d '"' || true)
        local launcher
        launcher=$(grep -m1 "^LAUNCHER=" "$f" 2>/dev/null | cut -d= -f2- | tr -d '"' || true)
        local lid
        lid=$(grep -m1 "^LAUNCHER_ID=" "$f" 2>/dev/null | cut -d= -f2- | tr -d '"' || true)
        local display="${name_field:-$fname}"
        local meta=""
        [[ -n "$launcher" ]] && meta="${launcher}"
        [[ -n "$lid" ]]      && meta="${meta}:${lid}"
        [[ -n "$meta" ]]     && meta=" (${meta})"
        echo "  ${fname}  —  ${display}${meta}"
        found=1
    done
    [[ $found -eq 0 ]] && echo "  (none found — copy example.conf to get started)"
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
# Config lookup
# Returns config file path in CONFIG_FILE, or empty string if not found.
# ---------------------------------------------------------------------------
CONFIG_FILE=""

find_config_by_name() {
    local name="$1"
    local candidate="${KDS_CONFIG_DIR}/${name}.conf"
    if [[ -f "$candidate" ]]; then
        CONFIG_FILE="$candidate"
        return 0
    fi
    # Scan NAME fields
    for f in "$KDS_CONFIG_DIR"/*.conf; do
        [[ -f "$f" ]] || continue
        local name_field
        name_field=$(grep -m1 "^NAME=" "$f" 2>/dev/null | cut -d= -f2- | tr -d '"' || true)
        if [[ "${name_field,,}" == "${name,,}" ]]; then
            CONFIG_FILE="$f"
            return 0
        fi
    done
    return 1
}

find_config_by_launcher() {
    # 1. Filename match against known launcher env vars
    for launcher in "${!LAUNCHER_ENV_MAP[@]}"; do
        local env_var="${LAUNCHER_ENV_MAP[$launcher]}"
        local env_val="${!env_var:-}"
        [[ -z "$env_val" ]] && continue
        local candidate="${KDS_CONFIG_DIR}/${env_val}.conf"
        if [[ -f "$candidate" ]]; then
            CONFIG_FILE="$candidate"
            echo "[kds] Auto-detected config by filename: $(basename "$candidate") (${launcher}:${env_val})"
            return 0
        fi
    done

    # 2. Scan LAUNCHER + LAUNCHER_ID fields in all configs
    for f in "$KDS_CONFIG_DIR"/*.conf; do
        [[ -f "$f" ]] || continue
        local file_launcher
        file_launcher=$(grep -m1 "^LAUNCHER=" "$f" 2>/dev/null | cut -d= -f2- | tr -d '"' || true)
        local file_lid
        file_lid=$(grep -m1 "^LAUNCHER_ID=" "$f" 2>/dev/null | cut -d= -f2- | tr -d '"' || true)
        [[ -z "$file_launcher" || -z "$file_lid" ]] && continue
        local env_var="${LAUNCHER_ENV_MAP[$file_launcher]:-}"
        [[ -z "$env_var" ]] && continue
        local env_val="${!env_var:-}"
        [[ -z "$env_val" ]] && continue
        if [[ "$file_lid" == "$env_val" ]]; then
            CONFIG_FILE="$f"
            echo "[kds] Auto-detected config by LAUNCHER_ID: $(basename "$f") (${file_launcher}:${file_lid})"
            return 0
        fi
    done

    return 1
}

# ---------------------------------------------------------------------------
# Load and validate a config file
# ---------------------------------------------------------------------------
load_config() {
    # Defaults
    NAME=""
    LAUNCHER=""
    LAUNCHER_ID=""
    ENTRY_HDR="passthrough"
    ENTRY_VRR="passthrough"
    EXIT_HDR="restore"
    EXIT_VRR="restore"
    COMMAND=""

    source "$CONFIG_FILE"
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
DRY_RUN=0
FORCED_NAME=""
PASSTHROUGH_CMD=()
MODE=""   # "auto" | "forced" | "standalone"

# Check for --dry-run anywhere in args
CLEAN_ARGS=()
for arg in "$@"; do
    [[ "$arg" == "--dry-run" ]] && DRY_RUN=1 || CLEAN_ARGS+=("$arg")
done
set -- "${CLEAN_ARGS[@]:-}"

FIRST="${1:-}"

case "$FIRST" in
    --help|-h)  usage; exit 0 ;;
    --list)     list_configs; exit 0 ;;
    --status)   show_status; exit 0 ;;
    "")         usage; exit 0 ;;
esac

# kds-launch=name syntax: $0 will contain the =name part
SELF="$(basename "$0")"
if [[ "$SELF" == kds-launch=* ]]; then
    FORCED_NAME="${SELF#kds-launch=}"
    MODE="forced"
    PASSTHROUGH_CMD=("$@")
elif [[ "$FIRST" == /* || "$FIRST" == ./* || "$FIRST" == *" "* ]] || \
     ( [[ $# -gt 1 ]] && [[ "$2" == /* || "$2" == env || "$2" == /usr/* ]] ); then
    # Looks like %command% was passed (first arg is a path or env)
    MODE="auto"
    PASSTHROUGH_CMD=("$@")
else
    # Standalone: kds-launch vlc
    MODE="standalone"
    FORCED_NAME="$FIRST"
    shift || true
    PASSTHROUGH_CMD=("$@")
fi

# ---------------------------------------------------------------------------
# Find the config
# ---------------------------------------------------------------------------
case "$MODE" in
    forced)
        if ! find_config_by_name "$FORCED_NAME"; then
            echo "[kds] ERROR: No config found for '${FORCED_NAME}'" >&2
            echo "[kds] Run 'kds-launch --list' to see available configs." >&2
            exit 1
        fi
        echo "[kds] Using forced config: $(basename "$CONFIG_FILE")"
        ;;
    auto)
        if ! find_config_by_launcher; then
            echo "[kds] No matching config found — passing through command untouched."
            exec "${PASSTHROUGH_CMD[@]}"
        fi
        ;;
    standalone)
        if ! find_config_by_name "$FORCED_NAME"; then
            echo "[kds] ERROR: No config found for '${FORCED_NAME}'" >&2
            echo "[kds] Run 'kds-launch --list' to see available configs." >&2
            exit 1
        fi
        echo "[kds] Using config: $(basename "$CONFIG_FILE")"
        ;;
esac

load_config

# ---------------------------------------------------------------------------
# Determine the command to run
# ---------------------------------------------------------------------------
if [[ ${#PASSTHROUGH_CMD[@]} -gt 0 ]]; then
    # Steam/Heroic: %command% was passed in, use it
    RUN_CMD=("${PASSTHROUGH_CMD[@]}")
elif [[ -n "$COMMAND" ]]; then
    # Standalone: use COMMAND from config
    RUN_CMD=("bash" "-c" "$COMMAND")
else
    echo "[kds] ERROR: No command to run. Set COMMAND in config or use with %command%." >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Snapshot current state
# ---------------------------------------------------------------------------
kds_get_state || exit 1

SNAPSHOT_HDR="$KDS_HDR_CURRENT"
SNAPSHOT_VRR="$KDS_VRR_CURRENT"

DISPLAY_NAME="${NAME:-$(basename "${CONFIG_FILE%.conf}")}"
echo "[kds] Config: ${DISPLAY_NAME}"
echo "[kds] Current state  — HDR: ${SNAPSHOT_HDR}  VRR: ${SNAPSHOT_VRR}"
echo "[kds] Entry settings — HDR: ${ENTRY_HDR}  VRR: ${ENTRY_VRR}"
echo "[kds] Exit settings  — HDR: ${EXIT_HDR}  VRR: ${EXIT_VRR}"

# Resolve 'restore' values now, against the snapshot
[[ "$EXIT_HDR" == "restore" ]] && EXIT_HDR="$SNAPSHOT_HDR"
[[ "$EXIT_VRR" == "restore" ]] && EXIT_VRR="$SNAPSHOT_VRR"

# ---------------------------------------------------------------------------
# Apply entry state
# ---------------------------------------------------------------------------
apply_entry() {
    if [[ "$ENTRY_HDR" == "passthrough" || "$ENTRY_HDR" == "$SNAPSHOT_HDR" ]]; then
        echo "[kds] HDR: no change needed (${ENTRY_HDR})"
    elif [[ $DRY_RUN -eq 1 ]]; then
        echo "[kds] DRY-RUN: would set HDR to ${ENTRY_HDR}"
    else
        kds_set_hdr "$ENTRY_HDR"
    fi

    if [[ "$ENTRY_VRR" == "passthrough" || "$ENTRY_VRR" == "$SNAPSHOT_VRR" ]]; then
        echo "[kds] VRR: no change needed (${ENTRY_VRR})"
    elif [[ $DRY_RUN -eq 1 ]]; then
        echo "[kds] DRY-RUN: would set VRR to ${ENTRY_VRR}"
    else
        kds_set_vrr "$ENTRY_VRR"
    fi
}

# ---------------------------------------------------------------------------
# Apply exit state
# ---------------------------------------------------------------------------
apply_exit() {
    echo "[kds] Applying exit state — HDR: ${EXIT_HDR}  VRR: ${EXIT_VRR}"
    if [[ $DRY_RUN -eq 1 ]]; then
        echo "[kds] DRY-RUN: would set HDR to ${EXIT_HDR}"
        echo "[kds] DRY-RUN: would set VRR to ${EXIT_VRR}"
    else
        kds_set_hdr "$EXIT_HDR"
        kds_set_vrr "$EXIT_VRR"
    fi
    echo "[kds] Done."
}

trap apply_exit EXIT

# ---------------------------------------------------------------------------
# Dry run exit
# ---------------------------------------------------------------------------
if [[ $DRY_RUN -eq 1 ]]; then
    apply_entry
    echo "[kds] DRY-RUN: would run: ${RUN_CMD[*]}"
    echo "[kds] DRY-RUN: on exit — HDR: ${EXIT_HDR}  VRR: ${EXIT_VRR}"
    trap - EXIT
    exit 0
fi

# ---------------------------------------------------------------------------
# Launch
# ---------------------------------------------------------------------------
apply_entry
echo "[kds] Launching..."
exec "${RUN_CMD[@]}"
