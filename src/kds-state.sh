#!/usr/bin/env bash
# kds-state.sh — KDE Displayset state detection library
# Part of kde-displayset: https://github.com/jinxcase000/kde-displayset
# License: GPL-3.0
#
# Source this file — do not execute directly.
# Provides: kds_get_state, kds_set_hdr, kds_set_vrr
# Exports:  KDS_OUTPUT, KDS_HDR_CURRENT, KDS_VRR_CURRENT

# ---------------------------------------------------------------------------
# kds_detect_output
#   Detects the first connected output name from kscreen-doctor.
#   Sets KDS_OUTPUT. Can be overridden by setting KDS_OUTPUT before sourcing.
# ---------------------------------------------------------------------------
kds_detect_output() {
    if [[ -n "${KDS_OUTPUT:-}" ]]; then
        return 0
    fi

KDS_OUTPUT=$(kscreen-doctor --outputs 2>/dev/null | awk 'NR==1 { print $3 }')
    export KDS_OUTPUT
}

# ---------------------------------------------------------------------------
# kds_get_state
#   Reads current HDR and VRR state for KDS_OUTPUT.
#   Sets KDS_HDR_CURRENT and KDS_VRR_CURRENT to "on" or "off".
# ---------------------------------------------------------------------------
kds_get_state() {
    kds_detect_output || return 1

    local output_block
    output_block=$(kscreen-doctor --outputs 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g')

    # HDR: look for "HDR: enabled" in the output block
    if echo "$output_block" | grep -qE "^\s+HDR: enabled"; then
        KDS_HDR_CURRENT="on"
    else
        KDS_HDR_CURRENT="off"
    fi

    # VRR: "Vrr: Always" or "Vrr: Automatic" = on; "Vrr: Never" = off
    local vrr_line
    vrr_line=$(echo "$output_block" | grep "Vrr:")
    if echo "$vrr_line" | grep -qiE "Always|Automatic"; then
        KDS_VRR_CURRENT="on"
    else
        KDS_VRR_CURRENT="off"
    fi

    export KDS_HDR_CURRENT KDS_VRR_CURRENT
}

# ---------------------------------------------------------------------------
# kds_set_hdr <on|off>
#   Applies HDR state to KDS_OUTPUT via kscreen-doctor.
# ---------------------------------------------------------------------------
kds_set_hdr() {
    local state="$1"
    kds_detect_output || return 1

    local action want
    case "$state" in
        on)  action="hdr.enable";  want="on"  ;;
        off) action="hdr.disable"; want="off" ;;
        *)
            echo "[kds] ERROR: kds_set_hdr requires 'on' or 'off', got: $state" >&2
            return 1
            ;;
    esac

    # Apply, capturing kscreen-doctor output (it exits 0 even on parse errors).
    local out
    out=$(kscreen-doctor "output.${KDS_OUTPUT}.${action}" 2>&1)

    # Verify by reading back (local read; does not touch snapshot vars).
    local now
    if kscreen-doctor --outputs 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | grep -qE "^\s+HDR: enabled"; then
        now="on"
    else
        now="off"
    fi

    if [[ "$now" == "$want" ]]; then
        echo "[kds] HDR set to ${want} on ${KDS_OUTPUT}"
        return 0
    fi
    echo "[kds] ERROR: HDR set to ${want} did not take on ${KDS_OUTPUT} (now: ${now}). kscreen-doctor: ${out:-<no output>}" >&2
    return 1
}

# ---------------------------------------------------------------------------
# kds_set_vrr <on|off>
#   Applies VRR (adaptive sync) state to KDS_OUTPUT via kscreen-doctor.
#   "on" = Always mode; "off" = Never mode.
# ---------------------------------------------------------------------------
kds_set_vrr() {
    local state="$1"
    kds_detect_output || return 1

    local action want
    case "$state" in
        on)  action="vrrpolicy.always"; want="on"  ;;
        off) action="vrrpolicy.never";  want="off" ;;
        *)
            echo "[kds] ERROR: kds_set_vrr requires 'on' or 'off', got: $state" >&2
            return 1
            ;;
    esac

    # Apply, capturing kscreen-doctor output (it exits 0 even on parse errors).
    local out
    out=$(kscreen-doctor "output.${KDS_OUTPUT}.${action}" 2>&1)

    # Verify by reading back (local read; does not touch snapshot vars).
    local now
    if kscreen-doctor --outputs 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | grep -i "Vrr:" | grep -qiE "Always|Automatic"; then
        now="on"
    else
        now="off"
    fi

    if [[ "$now" == "$want" ]]; then
        echo "[kds] VRR set to ${want} (${action}) on ${KDS_OUTPUT}"
        return 0
    fi
    echo "[kds] ERROR: VRR set to ${want} did not take on ${KDS_OUTPUT} (now: ${now}). kscreen-doctor: ${out:-<no output>}" >&2
    return 1
}
