#!/usr/bin/env bash
# shellcheck disable=SC2034  # Variables are used by scripts that source this file
# config_reader.sh — Read norrath-native.yaml configuration
#
# Sources this file to get config values as shell variables.
# Falls back to sensible defaults if no config file exists.
#
# Usage: source scripts/config_reader.sh

# Defaults
NN_PREFIX="${HOME}/.wine-eq"
NN_RESOLUTION="1920x1080"
NN_DISPLAY="x11"
NN_INSTANCES=1
NN_STAGGER_DELAY=5
NN_PROFILE="high"

# EQ Settings defaults (high profile)
NN_MAX_FPS=60
NN_MAX_BG_FPS=30
NN_CLIP_PLANE=15
NN_LOD_BIAS=10
NN_POST_EFFECTS="FALSE"
NN_MULTI_PASS_LIGHTING="FALSE"
NN_VERTEX_SHADERS="TRUE"
NN_SPELL_PARTICLES="1.000000"
NN_ENV_PARTICLES="1.000000"
NN_ACTOR_PARTICLES="1.000000"
NN_SOUND="1"
NN_MUSIC_VOLUME=10
NN_SOUND_VOLUME=10
NN_SHOW_NAMES=4
NN_CHAT_FONT_SIZE=3
NN_TRACK_PLAYERS=1
NN_ALLOW_RESIZE=1
NN_MAXIMIZED=1
NN_ALWAYS_ON_TOP=0

# Locate config file (check repo root, then home dir)
_nn_find_config() {
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local repo_root="${script_dir}/.."

    if [[ -f "${repo_root}/norrath-native.yaml" ]]; then
        printf '%s' "${repo_root}/norrath-native.yaml"
    elif [[ -f "${HOME}/.config/norrath-native/config.yaml" ]]; then
        printf '%s' "${HOME}/.config/norrath-native/config.yaml"
    fi
}

# Simple YAML value reader (no dependencies, handles basic key: value)
_nn_yaml_get() {
    local file="$1" key="$2"
    local line
    line="$(grep -E "^${key}:" "${file}" 2>/dev/null || true)"
    if [[ -z "${line}" ]]; then
        return 0
    fi
    printf '%s' "${line}" | head -1 | sed "s/^${key}:[[:space:]]*//" | sed 's/[[:space:]]*#.*//' | sed "s/^['\"]//;s/['\"]$//"
}

# Apply profile presets
_nn_apply_profile() {
    case "${NN_PROFILE}" in
        high)
            NN_MAX_FPS=60; NN_MAX_BG_FPS=30
            NN_CLIP_PLANE=15; NN_LOD_BIAS=10
            NN_POST_EFFECTS="FALSE"; NN_MULTI_PASS_LIGHTING="FALSE"
            NN_SPELL_PARTICLES="1.000000"
            NN_ENV_PARTICLES="1.000000"
            NN_ACTOR_PARTICLES="1.000000"
            ;;
        balanced)
            NN_MAX_FPS=45; NN_MAX_BG_FPS=15
            NN_CLIP_PLANE=10; NN_LOD_BIAS=7
            NN_POST_EFFECTS="FALSE"; NN_MULTI_PASS_LIGHTING="FALSE"
            NN_SPELL_PARTICLES="0.500000"
            NN_ENV_PARTICLES="0.500000"
            NN_ACTOR_PARTICLES="0.500000"
            ;;
        low)
            NN_MAX_FPS=30; NN_MAX_BG_FPS=10
            NN_CLIP_PLANE=5; NN_LOD_BIAS=3
            NN_POST_EFFECTS="FALSE"; NN_MULTI_PASS_LIGHTING="FALSE"
            NN_SPELL_PARTICLES="0.250000"
            NN_ENV_PARTICLES="0.000000"
            NN_ACTOR_PARTICLES="0.250000"
            ;;
        minimal)
            NN_MAX_FPS=15; NN_MAX_BG_FPS=5
            NN_CLIP_PLANE=2; NN_LOD_BIAS=1
            NN_POST_EFFECTS="FALSE"; NN_MULTI_PASS_LIGHTING="FALSE"
            NN_SPELL_PARTICLES="0.000000"
            NN_ENV_PARTICLES="0.000000"
            NN_ACTOR_PARTICLES="0.000000"
            NN_SOUND="0"
            ;;
    esac
}

# Read config file and override defaults
_nn_read_config() {
    local config_file
    config_file="$(_nn_find_config)"

    if [[ -z "${config_file}" ]]; then
        return 0
    fi

    # Helper to safely set a variable from YAML
    _nn_set() {
        local key="$1" varname="$2"
        local val
        val="$(_nn_yaml_get "${config_file}" "${key}")"
        if [[ -n "${val}" ]]; then
            eval "${varname}='${val}'"
        fi
    }

    # Core settings
    _nn_set "prefix" "NN_PREFIX"
    NN_PREFIX="${NN_PREFIX/#\~/$HOME}"
    _nn_set "resolution" "NN_RESOLUTION"
    _nn_set "display" "NN_DISPLAY"
    _nn_set "instances" "NN_INSTANCES"
    _nn_set "stagger_delay" "NN_STAGGER_DELAY"
    _nn_set "profile" "NN_PROFILE"

    # Apply profile first, then individual overrides
    _nn_apply_profile

    # Individual setting overrides (take precedence over profile)
    _nn_set "max_fps" "NN_MAX_FPS"
    _nn_set "max_bg_fps" "NN_MAX_BG_FPS"
    _nn_set "clip_plane" "NN_CLIP_PLANE"
    _nn_set "lod_bias" "NN_LOD_BIAS"

    # Boolean conversions
    local val
    val="$(_nn_yaml_get "${config_file}" "post_effects")"
    if [[ "${val}" == "true" ]]; then NN_POST_EFFECTS="TRUE"; fi
    if [[ "${val}" == "false" ]]; then NN_POST_EFFECTS="FALSE"; fi

    val="$(_nn_yaml_get "${config_file}" "multi_pass_lighting")"
    if [[ "${val}" == "true" ]]; then NN_MULTI_PASS_LIGHTING="TRUE"; fi
    if [[ "${val}" == "false" ]]; then NN_MULTI_PASS_LIGHTING="FALSE"; fi

    val="$(_nn_yaml_get "${config_file}" "sound")"
    if [[ "${val}" == "true" ]]; then NN_SOUND="1"; fi
    if [[ "${val}" == "false" ]]; then NN_SOUND="0"; fi
}

# Run on source
_nn_read_config
