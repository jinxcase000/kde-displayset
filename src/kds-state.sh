#!/usr/bin/env bash
# kds-state.sh — KDE Displayset state detection library
# Part of kde-displayset: https://github.com/jinxcase000/kde-displayset
# License: GPL-3.0
#
# Source this file — do not execute directly.
# Provides: kds_get_state, kds_read_hv, kds_set_hdr, kds_set_vrr, kds_apply
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
# kds_read_hv
#   Reads current HDR and VRR in a single kscreen-doctor call.
#   Prints two words: "<hdr> <vrr>", each "on" or "off".
#     HDR: "HDR: enabled" => on
#     VRR: "Vrr: Always" or "Vrr: Automatic" => on; "Vrr: Never" => off
# ---------------------------------------------------------------------------
kds_read_hv() {
    local block h v
    block=$(kscreen-doctor --outputs 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g')
    if printf '%s\n' "$block" | grep -qE "^[[:space:]]+HDR: enabled"; then h="on"; else h="off"; fi
    if printf '%s\n' "$block" | grep -i "Vrr:" | grep -qiE "Always|Automatic"; then v="on"; else v="off"; fi
    printf '%s %s\n' "$h" "$v"
}

# ---------------------------------------------------------------------------
# kds_get_state
#   Reads current HDR and VRR state for KDS_OUTPUT.
#   Sets KDS_HDR_CURRENT and KDS_VRR_CURRENT to "on" or "off".
# ---------------------------------------------------------------------------
kds_get_state() {
    kds_detect_output || return 1
    read -r KDS_HDR_CURRENT KDS_VRR_CURRENT < <(kds_read_hv)
    export KDS_HDR_CURRENT KDS_VRR_CURRENT
}

# ---------------------------------------------------------------------------
# kds_set_hdr <on|off>
#   Applies HDR alone (its own kscreen-doctor call) and verifies by read-back.
# ---------------------------------------------------------------------------
kds_set_hdr() {
    local state="$1" arg want out nh nv
    kds_detect_output || return 1
    case "$state" in
        on)  arg="hdr.enable";  want="on"  ;;
        off) arg="hdr.disable"; want="off" ;;
        *) echo "[kds] ERROR: kds_set_hdr requires 'on' or 'off', got: $state" >&2; return 1 ;;
    esac
    out=$(kscreen-doctor "output.${KDS_OUTPUT}.${arg}" 2>&1)
    read -r nh nv < <(kds_read_hv)
    if [[ "$nh" == "$want" ]]; then
        echo "[kds] HDR set to ${want} on ${KDS_OUTPUT}"
        return 0
    fi
    echo "[kds] ERROR: HDR set to ${want} did not take on ${KDS_OUTPUT} (now: ${nh}). kscreen-doctor: ${out:-<no output>}" >&2
    return 1
}

# ---------------------------------------------------------------------------
# kds_set_vrr <on|off>
#   Applies VRR alone (its own kscreen-doctor call) and verifies by read-back.
#   "on" = Always mode; "off" = Never mode.
# ---------------------------------------------------------------------------
kds_set_vrr() {
    local state="$1" arg want out nh nv
    kds_detect_output || return 1
    case "$state" in
        on)  arg="vrrpolicy.always"; want="on"  ;;
        off) arg="vrrpolicy.never";  want="off" ;;
        *) echo "[kds] ERROR: kds_set_vrr requires 'on' or 'off', got: $state" >&2; return 1 ;;
    esac
    out=$(kscreen-doctor "output.${KDS_OUTPUT}.${arg}" 2>&1)
    read -r nh nv < <(kds_read_hv)
    if [[ "$nv" == "$want" ]]; then
        echo "[kds] VRR set to ${want} (${arg}) on ${KDS_OUTPUT}"
        return 0
    fi
    echo "[kds] ERROR: VRR set to ${want} did not take on ${KDS_OUTPUT} (now: ${nv}). kscreen-doctor: ${out:-<no output>}" >&2
    return 1
}

# ---------------------------------------------------------------------------
# kds_apply <hdr:on|off|skip> <vrr:on|off|skip>
#   COMBINED mode: applies HDR and/or VRR in a SINGLE atomic kscreen-doctor
#   call (one display re-negotiation instead of two), then verifies with one
#   read-back. Any requested setting that did not take is retried on its own
#   via kds_set_hdr/kds_set_vrr, so a single failing setting can't silently
#   leave the other unapplied. 'skip' leaves a setting untouched.
#   Returns 0 if all requested settings ended in the wanted state, else 1.
# ---------------------------------------------------------------------------
kds_apply() {
    local hdr="$1" vrr="$2"
    kds_detect_output || return 1

    local args=() labels=()
    case "$hdr" in
        on)   args+=("output.${KDS_OUTPUT}.hdr.enable");  labels+=("HDR=on")  ;;
        off)  args+=("output.${KDS_OUTPUT}.hdr.disable"); labels+=("HDR=off") ;;
        skip) ;;
        *) echo "[kds] ERROR: kds_apply HDR arg must be on/off/skip, got: $hdr" >&2; return 1 ;;
    esac
    case "$vrr" in
        on)   args+=("output.${KDS_OUTPUT}.vrrpolicy.always"); labels+=("VRR=on")  ;;
        off)  args+=("output.${KDS_OUTPUT}.vrrpolicy.never");  labels+=("VRR=off") ;;
        skip) ;;
        *) echo "[kds] ERROR: kds_apply VRR arg must be on/off/skip, got: $vrr" >&2; return 1 ;;
    esac

    if [[ ${#args[@]} -eq 0 ]]; then
        return 0
    fi

    local out
    out=$(kscreen-doctor "${args[@]}" 2>&1)
    echo "[kds] Applied ${labels[*]} in one call on ${KDS_OUTPUT}"

    local nh nv rc=0
    read -r nh nv < <(kds_read_hv)
    if [[ "$hdr" != "skip" && "$nh" != "$hdr" ]]; then
        echo "[kds] WARN: HDR=${hdr} did not take (now: ${nh}); retrying on its own" >&2
        kds_set_hdr "$hdr" || rc=1
    fi
    if [[ "$vrr" != "skip" && "$nv" != "$vrr" ]]; then
        echo "[kds] WARN: VRR=${vrr} did not take (now: ${nv}); retrying on its own" >&2
        kds_set_vrr "$vrr" || rc=1
    fi
    return $rc
}
