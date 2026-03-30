#!/usr/bin/env bash
# Claude Code Statusline - A beautiful, configurable statusline for Claude Code
# https://github.com/pottekkat/claude-code-statusline
#
# ── Icon Reference (edit these to customize) ──────────────────────────────────
# All NerdFont icons are defined below. To change an icon, replace the character
# between the quotes. Find icons at https://www.nerdfonts.com/cheat-sheet
#
# To use this without NerdFonts, set "nerdfonts": false in your config file at:
#   ~/.claude/statusline-config.json

set -euo pipefail

# ── Configuration ──────────────────────────────────────────────────────────────
CONFIG_FILE="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/statusline-config.json"
SETTINGS_FILE="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json"
CACHE_DIR="/tmp/claude"
CACHE_TTL=60

# ── Default config (overridden by config file) ────────────────────────────────
USE_NERDFONTS=true
SEGMENTS="agent,worktree,model,context,git,directory,duration,cost,lines,tokens,effort,style,rate_5h,rate_7d,extra"
CONTEXT_STYLE="bar"    # "bar" | "percent" | "tokens"
RATE_STYLE="bar"       # "bar" | "inline"

# ══════════════════════════════════════════════════════════════════════════════
# ICONS - Edit these to customize your statusline appearance
# ══════════════════════════════════════════════════════════════════════════════

# ── NerdFont Icons (used when nerdfonts=true) ─────────────────────────────────
# Find more icons at https://www.nerdfonts.com/cheat-sheet
NF_ICON_MODEL="󱚡"             # Robot face         — model name
NF_ICON_CONTEXT="󰍛"           # Memory chip        — context window usage
NF_ICON_GIT=""                # Git branch         — git branch name
NF_ICON_FOLDER=""              # Folder             — current directory
NF_ICON_CLOCK="󰥔"             # Clock              — session duration
NF_ICON_COST=""              # Dollar             — session cost
NF_ICON_CHANGES="󰦒"           # Swap vertical      — lines added/removed
NF_ICON_EFFORT=""             # Lightning bolt     — thinking effort
NF_ICON_AGENT="󰛦"             # Robot outline      — agent name
NF_ICON_WORKTREE="󰘬"          # Source branch      — worktree
NF_ICON_VERSION=""             # Code brackets      — claude code version
NF_ICON_STYLE="󰏘"             # Paint brush        — output style
NF_ICON_TOKENS="󰆙"            # Counter            — token counts
NF_ICON_RATE="󰔟"              # Hourglass          — rate limits
NF_ICON_DIRTY="*"              # Dirty indicator    — uncommitted changes
NF_ICON_BAR_FULL="█"           # Progress bar fill
NF_ICON_BAR_EMPTY="░"          # Progress bar empty

# ── Text Fallbacks (used when nerdfonts=false) ────────────────────────────────
TXT_ICON_MODEL=""
TXT_ICON_CONTEXT="Ctx"
TXT_ICON_GIT=""
TXT_ICON_FOLDER=""
TXT_ICON_CLOCK=""
TXT_ICON_COST="$"
TXT_ICON_CHANGES=""
TXT_ICON_EFFORT=""
TXT_ICON_AGENT="Agent:"
TXT_ICON_WORKTREE="Worktree:"
TXT_ICON_VERSION="v"
TXT_ICON_STYLE="Style:"
TXT_ICON_TOKENS="Tokens:"
TXT_ICON_RATE=""
TXT_ICON_DIRTY="*"
TXT_ICON_BAR_FULL="#"
TXT_ICON_BAR_EMPTY="."

# ══════════════════════════════════════════════════════════════════════════════

# ── Load config ───────────────────────────────────────────────────────────────
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        local cfg
        cfg=$(cat "$CONFIG_FILE" 2>/dev/null) || return 0
        USE_NERDFONTS=$(echo "$cfg" | jq -r 'if has("nerdfonts") then .nerdfonts else true end')
        SEGMENTS=$(echo "$cfg" | jq -r '.segments // "agent,worktree,model,context,git,directory,duration,cost,lines,tokens,effort,style,rate_5h,rate_7d,extra"')
        CONTEXT_STYLE=$(echo "$cfg" | jq -r '.context_style // "bar"')
        RATE_STYLE=$(echo "$cfg" | jq -r '.rate_style // "bar"')
    fi
}

# ── Read input ────────────────────────────────────────────────────────────────
INPUT=$(cat)
if [[ -z "$INPUT" ]]; then
    echo "Claude Code"
    exit 0
fi

load_config

# ── ANSI helpers ──────────────────────────────────────────────────────────────
reset="\033[0m"
bold="\033[1m"
dim="\033[2m"

red="\033[31m"
green="\033[32m"
yellow="\033[33m"
blue="\033[34m"
magenta="\033[35m"
cyan="\033[36m"
white="\033[37m"

br_black="\033[90m"
br_red="\033[91m"
br_green="\033[92m"
br_yellow="\033[93m"
br_blue="\033[94m"
br_magenta="\033[95m"
br_cyan="\033[96m"
br_white="\033[97m"

# ── Resolve active icons ─────────────────────────────────────────────────────
setup_icons() {
    if [[ "$USE_NERDFONTS" == "true" ]]; then
        ICON_MODEL="$NF_ICON_MODEL"
        ICON_CONTEXT="$NF_ICON_CONTEXT"
        ICON_GIT="$NF_ICON_GIT"
        ICON_FOLDER="$NF_ICON_FOLDER"
        ICON_CLOCK="$NF_ICON_CLOCK"
        ICON_COST="$NF_ICON_COST"
        ICON_CHANGES="$NF_ICON_CHANGES"
        ICON_EFFORT="$NF_ICON_EFFORT"
        ICON_AGENT="$NF_ICON_AGENT"
        ICON_WORKTREE="$NF_ICON_WORKTREE"
        ICON_VERSION="$NF_ICON_VERSION"
        ICON_STYLE="$NF_ICON_STYLE"
        ICON_TOKENS="$NF_ICON_TOKENS"
        ICON_RATE="$NF_ICON_RATE"
        ICON_DIRTY="$NF_ICON_DIRTY"
        ICON_BAR_FULL="$NF_ICON_BAR_FULL"
        ICON_BAR_EMPTY="$NF_ICON_BAR_EMPTY"
    else
        ICON_MODEL="$TXT_ICON_MODEL"
        ICON_CONTEXT="$TXT_ICON_CONTEXT"
        ICON_GIT="$TXT_ICON_GIT"
        ICON_FOLDER="$TXT_ICON_FOLDER"
        ICON_CLOCK="$TXT_ICON_CLOCK"
        ICON_COST="$TXT_ICON_COST"
        ICON_CHANGES="$TXT_ICON_CHANGES"
        ICON_EFFORT="$TXT_ICON_EFFORT"
        ICON_AGENT="$TXT_ICON_AGENT"
        ICON_WORKTREE="$TXT_ICON_WORKTREE"
        ICON_VERSION="$TXT_ICON_VERSION"
        ICON_STYLE="$TXT_ICON_STYLE"
        ICON_TOKENS="$TXT_ICON_TOKENS"
        ICON_RATE="$TXT_ICON_RATE"
        ICON_DIRTY="$TXT_ICON_DIRTY"
        ICON_BAR_FULL="$TXT_ICON_BAR_FULL"
        ICON_BAR_EMPTY="$TXT_ICON_BAR_EMPTY"
    fi
}

# ── JSON helpers ──────────────────────────────────────────────────────────────
jval() {
    echo "$INPUT" | jq -r "$1 // empty" 2>/dev/null
}

jval_num() {
    local v
    v=$(echo "$INPUT" | jq -r "$1 // 0" 2>/dev/null)
    echo "${v:-0}"
}

# ── Icon with trailing space helper ───────────────────────────────────────────
# Adds a trailing space only if the icon is non-empty
icon() {
    local i="$1"
    if [[ -n "$i" ]]; then
        printf "%s " "$i"
    fi
}

# ── Progress bar ──────────────────────────────────────────────────────────────
progress_bar() {
    local pct=$1 width=${2:-8} color=${3:-$green}
    local filled=$(( pct * width / 100 ))
    if (( pct > 0 && filled == 0 )); then filled=1; fi
    local empty=$(( width - filled ))
    printf "${color}"
    for ((i=0; i<filled; i++)); do printf "${ICON_BAR_FULL}"; done
    printf "${br_black}"
    for ((i=0; i<empty; i++)); do printf "${ICON_BAR_EMPTY}"; done
    printf "${reset}"
}

mini_bar() {
    local pct=$1 color=${2:-$green}
    local width=5
    local filled=$(( pct * width / 100 ))
    if (( pct > 0 && filled == 0 )); then filled=1; fi
    local empty=$(( width - filled ))
    printf "${color}"
    for ((i=0; i<filled; i++)); do printf "${ICON_BAR_FULL}"; done
    printf "${br_black}"
    for ((i=0; i<empty; i++)); do printf "${ICON_BAR_EMPTY}"; done
    printf "${reset}"
}

# ── Color by percentage (low=good, high=bad) ──────────────────────────────────
color_by_pct() {
    local pct=$1
    if (( pct < 50 )); then echo -n "$green"
    elif (( pct < 70 )); then echo -n "$yellow"
    elif (( pct < 90 )); then echo -n "$br_yellow"
    else echo -n "$red"
    fi
}

# ── Format tokens ─────────────────────────────────────────────────────────────
fmt_tokens() {
    local n=$1
    if (( n >= 1000000 )); then
        printf "%.1fM" "$(echo "scale=1; $n / 1000000" | bc)"
    elif (( n >= 1000 )); then
        printf "%.1fk" "$(echo "scale=1; $n / 1000" | bc)"
    else
        printf "%d" "$n"
    fi
}

# ── Format duration ───────────────────────────────────────────────────────────
fmt_duration() {
    local ms=$1
    local secs=$(( ms / 1000 ))
    if (( secs < 60 )); then
        printf "%ds" "$secs"
    elif (( secs < 3600 )); then
        printf "%dm%ds" $(( secs / 60 )) $(( secs % 60 ))
    else
        printf "%dh%dm" $(( secs / 3600 )) $(( (secs % 3600) / 60 ))
    fi
}

# ── Format reset time ────────────────────────────────────────────────────────
fmt_reset_time() {
    local epoch=$1
    if [[ -z "$epoch" || "$epoch" == "null" || "$epoch" == "0" ]]; then return; fi
    if date -j -f "%s" "$epoch" "+%l:%M %p" 2>/dev/null | sed 's/^ //'; then return; fi
    date -d "@$epoch" "+%l:%M %p" 2>/dev/null | sed 's/^ //' || true
}

fmt_reset_date_full() {
    local epoch=$1
    if [[ -z "$epoch" || "$epoch" == "null" || "$epoch" == "0" ]]; then return; fi
    if date -j -f "%s" "$epoch" "+%B %-d" 2>/dev/null; then return; fi
    date -d "@$epoch" "+%B %-d" 2>/dev/null || true
}

# ── OAuth token resolution ────────────────────────────────────────────────────
get_oauth_token() {
    if [[ -n "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]]; then
        echo "$CLAUDE_CODE_OAUTH_TOKEN"; return
    fi

    local config_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
    local service_suffix=""
    if [[ -n "${CLAUDE_CONFIG_DIR:-}" ]]; then
        service_suffix="-$(echo -n "$CLAUDE_CONFIG_DIR" | shasum -a 256 | cut -d' ' -f1)"
    fi

    if command -v security &>/dev/null; then
        local token
        token=$(security find-generic-password -s "Claude Code-credentials${service_suffix}" -w 2>/dev/null) || true
        if [[ -n "$token" ]]; then
            echo "$token" | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null && return
        fi
    fi

    local cred_file="$config_dir/.credentials.json"
    if [[ -f "$cred_file" ]]; then
        jq -r '.claudeAiOauth.accessToken // empty' "$cred_file" 2>/dev/null && return
    fi

    if command -v secret-tool &>/dev/null; then
        local token
        token=$(secret-tool lookup service "Claude Code-credentials${service_suffix}" 2>/dev/null) || true
        if [[ -n "$token" ]]; then
            echo "$token" | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null && return
        fi
    fi
}

# ── Fetch usage data (cached) ────────────────────────────────────────────────
fetch_usage() {
    mkdir -p "$CACHE_DIR"
    local config_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
    local cache_hash
    cache_hash=$(echo -n "$config_dir" | shasum -a 256 | cut -d' ' -f1 | head -c 8)
    local cache_file="$CACHE_DIR/statusline-cache-${cache_hash}.json"

    if [[ -f "$cache_file" ]]; then
        local cache_age=999
        if stat -f "%m" "$cache_file" &>/dev/null; then
            cache_age=$(( $(date +%s) - $(stat -f "%m" "$cache_file") ))
        elif stat -c "%Y" "$cache_file" &>/dev/null; then
            cache_age=$(( $(date +%s) - $(stat -c "%Y" "$cache_file") ))
        fi
        if (( cache_age < CACHE_TTL )); then
            cat "$cache_file"; return
        fi
    fi

    local token
    token=$(get_oauth_token)
    if [[ -z "$token" ]]; then echo "{}"; return; fi

    local response
    response=$(curl -sf --max-time 5 \
        -H "Authorization: Bearer $token" \
        -H "anthropic-beta: oauth-2025-04-20" \
        "https://api.anthropic.com/api/oauth/usage" 2>/dev/null) || response="{}"

    echo "$response" > "$cache_file"
    echo "$response"
}

# ── has_segment ───────────────────────────────────────────────────────────────
has_segment() {
    [[ ",$SEGMENTS," == *",$1,"* ]]
}

# ══════════════════════════════════════════════════════════════════════════════
# MAIN
# ══════════════════════════════════════════════════════════════════════════════
main() {
    setup_icons

    # ── Extract all data from Claude Code JSON ────────────────────────────────
    local MODEL_NAME MODEL_ID CWD CTX_SIZE CTX_PCT
    local CTX_INPUT CTX_CACHE_CREATE CTX_CACHE_READ TOTAL_INPUT TOTAL_OUTPUT
    local COST DURATION_MS API_DURATION_MS LINES_ADD LINES_DEL
    local RATE_5H_PCT RATE_5H_RESET RATE_7D_PCT RATE_7D_RESET
    local VERSION OUTPUT_STYLE AGENT_NAME WORKTREE_NAME WORKTREE_BRANCH

    MODEL_NAME=$(jval '.model.display_name')
    MODEL_ID=$(jval '.model.id')
    CWD=$(jval '.workspace.current_dir // .cwd')
    CTX_SIZE=$(jval_num '.context_window.context_window_size')
    CTX_PCT=$(jval_num '.context_window.used_percentage')
    CTX_INPUT=$(jval_num '.context_window.current_usage.input_tokens')
    CTX_CACHE_CREATE=$(jval_num '.context_window.current_usage.cache_creation_input_tokens')
    CTX_CACHE_READ=$(jval_num '.context_window.current_usage.cache_read_input_tokens')
    TOTAL_INPUT=$(jval_num '.context_window.total_input_tokens')
    TOTAL_OUTPUT=$(jval_num '.context_window.total_output_tokens')
    COST=$(jval '.cost.total_cost_usd')
    DURATION_MS=$(jval_num '.cost.total_duration_ms')
    API_DURATION_MS=$(jval_num '.cost.total_api_duration_ms')
    LINES_ADD=$(jval_num '.cost.total_lines_added')
    LINES_DEL=$(jval_num '.cost.total_lines_removed')
    RATE_5H_PCT=$(jval '.rate_limits.five_hour.used_percentage')
    RATE_5H_RESET=$(jval '.rate_limits.five_hour.resets_at')
    RATE_7D_PCT=$(jval '.rate_limits.seven_day.used_percentage')
    RATE_7D_RESET=$(jval '.rate_limits.seven_day.resets_at')
    VERSION=$(jval '.version')
    OUTPUT_STYLE=$(jval '.output_style.name')
    AGENT_NAME=$(jval '.agent.name')
    WORKTREE_NAME=$(jval '.worktree.name')
    WORKTREE_BRANCH=$(jval '.worktree.branch')

    # ── Effort level (from env or settings.json) ──────────────────────────────
    local EFFORT=""
    if [[ -n "${CLAUDE_CODE_EFFORT_LEVEL:-}" ]]; then
        EFFORT="$CLAUDE_CODE_EFFORT_LEVEL"
    elif [[ -f "$SETTINGS_FILE" ]]; then
        EFFORT=$(jq -r '.effortLevel // empty' "$SETTINGS_FILE" 2>/dev/null) || true
    fi

    # ── Auto-compact window (effective context limit) ─────────────────────────
    local AUTO_COMPACT_WINDOW=""
    if [[ -f "$SETTINGS_FILE" ]]; then
        AUTO_COMPACT_WINDOW=$(jq -r '.env.CLAUDE_CODE_AUTO_COMPACT_WINDOW // empty' "$SETTINGS_FILE" 2>/dev/null) || true
    fi
    # Also check project-level settings
    if [[ -n "$CWD" && -f "$CWD/.claude/settings.json" ]]; then
        local proj_acw
        proj_acw=$(jq -r '.env.CLAUDE_CODE_AUTO_COMPACT_WINDOW // empty' "$CWD/.claude/settings.json" 2>/dev/null) || true
        if [[ -n "$proj_acw" ]]; then
            AUTO_COMPACT_WINDOW="$proj_acw"
        fi
    fi

    # ── Git info ──────────────────────────────────────────────────────────────
    local GIT_BRANCH="" GIT_DIRTY="" GIT_AHEAD=0 GIT_BEHIND=0
    if [[ -n "$CWD" ]] && command -v git &>/dev/null; then
        GIT_BRANCH=$(git -C "$CWD" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null) || true
        if [[ -n "$GIT_BRANCH" ]]; then
            if [[ -n $(git -C "$CWD" --no-optional-locks status --porcelain 2>/dev/null) ]]; then
                GIT_DIRTY="true"
            fi
            local counts
            counts=$(git -C "$CWD" --no-optional-locks rev-list --left-right --count HEAD...@{upstream} 2>/dev/null) || true
            if [[ -n "$counts" ]]; then
                GIT_AHEAD=$(echo "$counts" | cut -f1)
                GIT_BEHIND=$(echo "$counts" | cut -f2)
            fi
        fi
    fi

    # ── Directory name ────────────────────────────────────────────────────────
    local DIR_NAME=""
    if [[ -n "$CWD" ]]; then DIR_NAME=$(basename "$CWD"); fi

    # ── Helpers ────────────────────────────────────────────────────────────────
    local LINE=""
    _append() {
        if [[ -n "$LINE" ]]; then LINE+="  "; fi
        LINE+="$1"
    }
    _flush() {
        if [[ -n "$LINE" ]]; then printf "%b\n" "$LINE"; fi
        LINE=""
    }

    # ══ LINE 1: Model, context, git, directory ════════════════════════════════

    # Agent
    if has_segment "agent" && [[ -n "$AGENT_NAME" ]]; then
        _append "${white}$(icon "$ICON_AGENT")${br_magenta}${AGENT_NAME}${reset}"
    fi

    # Worktree
    if has_segment "worktree" && [[ -n "$WORKTREE_NAME" ]]; then
        local wt="${WORKTREE_NAME}"
        if [[ -n "$WORKTREE_BRANCH" ]]; then wt+=" (${WORKTREE_BRANCH})"; fi
        _append "${white}$(icon "$ICON_WORKTREE")${br_cyan}${wt}${reset}"
    fi

    # Model + context window size
    if has_segment "model" && [[ -n "$MODEL_NAME" ]]; then
        local model_color="$br_blue"
        case "$MODEL_ID" in
            *opus*)   model_color="$br_magenta";;
            *sonnet*) model_color="$br_blue";;
            *haiku*)  model_color="$br_green";;
        esac

        local clean_name="${MODEL_NAME/ (1M context)/}"
        local model_text="$(icon "$ICON_MODEL")${clean_name}"

        local ctx_label=""
        if [[ -n "$AUTO_COMPACT_WINDOW" && "$AUTO_COMPACT_WINDOW" != "0" ]]; then
            local acw_k=$(( AUTO_COMPACT_WINDOW / 1000 ))
            if (( CTX_SIZE >= 1000000 )); then
                ctx_label="${acw_k}K/1M"
            elif (( CTX_SIZE > 0 )); then
                ctx_label="${acw_k}K/$(( CTX_SIZE / 1000 ))K"
            else
                ctx_label="${acw_k}K"
            fi
        elif (( CTX_SIZE >= 1000000 )); then
            ctx_label="1M"
        elif (( CTX_SIZE > 0 )); then
            ctx_label="$(( CTX_SIZE / 1000 ))K"
        fi

        if [[ -n "$ctx_label" ]]; then
            model_text+=" ${white}(${ctx_label})${reset}${model_color}"
        fi

        _append "${bold}${model_color}${model_text}${reset}"
    fi

    # Context usage
    if has_segment "context"; then
        local pct=${CTX_PCT:-0}
        pct=${pct%.*}

        # Recalculate % against auto-compact window if set
        if [[ -n "$AUTO_COMPACT_WINDOW" && "$AUTO_COMPACT_WINDOW" != "0" && "$CTX_SIZE" -gt 0 ]]; then
            local used_tokens_approx=$(( pct * CTX_SIZE / 100 ))
            pct=$(( used_tokens_approx * 100 / AUTO_COMPACT_WINDOW ))
            if (( pct > 100 )); then pct=100; fi
        fi

        local ctx_color
        ctx_color=$(color_by_pct "$pct")

        case "$CONTEXT_STYLE" in
            bar)
                _append "${white}$(icon "$ICON_CONTEXT")${ctx_color}${pct}%${reset} $(progress_bar "$pct" 8 "$ctx_color")"
                ;;
            percent)
                _append "${white}$(icon "$ICON_CONTEXT")${ctx_color}${pct}%${reset}"
                ;;
            tokens)
                local used_tokens=$(( CTX_INPUT + CTX_CACHE_CREATE + CTX_CACHE_READ ))
                _append "${white}$(icon "$ICON_CONTEXT")${ctx_color}$(fmt_tokens $used_tokens)/$(fmt_tokens $CTX_SIZE)${reset}"
                ;;
        esac
    fi

    # Git
    if has_segment "git" && [[ -n "$GIT_BRANCH" ]]; then
        local git_text="${white}$(icon "$ICON_GIT")${green}${GIT_BRANCH}${reset}"
        if [[ "$GIT_DIRTY" == "true" ]]; then
            git_text+="${yellow}${ICON_DIRTY}${reset}"
        fi
        if (( GIT_AHEAD > 0 )); then
            git_text+=" ${br_green}↑${GIT_AHEAD}${reset}"
        fi
        if (( GIT_BEHIND > 0 )); then
            git_text+=" ${br_red}↓${GIT_BEHIND}${reset}"
        fi
        _append "$git_text"
    fi

    # Directory
    if has_segment "directory" && [[ -n "$DIR_NAME" ]]; then
        _append "${white}$(icon "$ICON_FOLDER")${cyan}${DIR_NAME}${reset}"
    fi

    _flush

    # ══ LINE 2: Session stats ═════════════════════════════════════════════════

    # Duration
    if has_segment "duration" && (( DURATION_MS > 0 )); then
        local dur_text="${white}$(icon "$ICON_CLOCK")$(fmt_duration $DURATION_MS)${reset}"
        if has_segment "api_time" && (( API_DURATION_MS > 0 )); then
            local api_pct=$(( API_DURATION_MS * 100 / DURATION_MS ))
            dur_text+=" ${white}(API ${api_pct}%)${reset}"
        fi
        _append "$dur_text"
    fi

    # Cost
    if has_segment "cost" && [[ -n "$COST" && "$COST" != "0" ]]; then
        local fmt_cost
        fmt_cost=$(printf "%.2f" "$COST" 2>/dev/null || echo "$COST")
        _append "${br_yellow}\$${fmt_cost}${reset}"
    fi

    # Lines changed
    if has_segment "lines" && (( LINES_ADD > 0 || LINES_DEL > 0 )); then
        local lines_text=""
        if (( LINES_ADD > 0 )); then
            lines_text+="${green}+${LINES_ADD}${reset}"
        fi
        if (( LINES_DEL > 0 )); then
            if (( LINES_ADD > 0 )); then lines_text+=" "; fi
            lines_text+="${red}-${LINES_DEL}${reset}"
        fi
        _append "$lines_text"
    fi

    # Tokens
    if has_segment "tokens" && (( TOTAL_INPUT > 0 )); then
        _append "${white}$(icon "$ICON_TOKENS")${green}$(fmt_tokens $TOTAL_INPUT) ↑${reset}  ${br_yellow}$(fmt_tokens $TOTAL_OUTPUT) ↓${reset}"
    fi

    # Effort (only show when non-default)
    if has_segment "effort" && [[ -n "$EFFORT" && "$EFFORT" != "default" ]]; then
        case "$EFFORT" in
            high)   _append "${white}$(icon "$ICON_EFFORT")${magenta}High effort${reset}";;
            low)    _append "${white}$(icon "$ICON_EFFORT")Low effort${reset}";;
            medium) _append "${white}$(icon "$ICON_EFFORT")Medium effort${reset}";;
        esac
    fi

    # Version
    if has_segment "version" && [[ -n "$VERSION" ]]; then
        _append "${white}$(icon "$ICON_VERSION")${VERSION}${reset}"
    fi

    # Output style
    if has_segment "style" && [[ -n "$OUTPUT_STYLE" && "$OUTPUT_STYLE" != "default" ]]; then
        _append "${white}$(icon "$ICON_STYLE")${OUTPUT_STYLE}${reset}"
    fi

    _flush

    # ══ LINE 3: Rate limits + extra usage ═════════════════════════════════════

    if has_segment "rate_5h" || has_segment "rate_7d" || has_segment "extra"; then
        local USAGE_DATA=""
        if [[ -z "$RATE_5H_PCT" && -z "$RATE_7D_PCT" ]]; then
            USAGE_DATA=$(fetch_usage)
        fi

        # 5-hour rate limit
        if has_segment "rate_5h"; then
            local pct_5h="" reset_5h=""

            if [[ -n "$RATE_5H_PCT" ]]; then
                pct_5h="${RATE_5H_PCT%.*}"
                reset_5h=$(fmt_reset_time "$RATE_5H_RESET")
            elif [[ -n "$USAGE_DATA" ]]; then
                pct_5h=$(echo "$USAGE_DATA" | jq -r '.five_hour.utilization // empty' 2>/dev/null)
                pct_5h="${pct_5h%.*}"
                local api_reset
                api_reset=$(echo "$USAGE_DATA" | jq -r '.five_hour.resets_at // empty' 2>/dev/null)
                if [[ -n "$api_reset" ]]; then
                    if date -j -f "%Y-%m-%dT%H:%M:%S" "${api_reset%%.*}" "+%s" &>/dev/null; then
                        reset_5h=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${api_reset%%.*}" "+%l:%M %p" 2>/dev/null | sed 's/^ //')
                    else
                        reset_5h=$(date -d "$api_reset" "+%l:%M %p" 2>/dev/null | sed 's/^ //')
                    fi
                fi
            fi

            if [[ -n "$pct_5h" ]]; then
                local rate_color
                rate_color=$(color_by_pct "$pct_5h")
                local rt="${white}$(icon "$ICON_RATE")5 Hour:${reset} ${rate_color}${pct_5h}%${reset}"
                if [[ "$RATE_STYLE" == "bar" ]]; then
                    rt+=" $(mini_bar "$pct_5h" "$rate_color")"
                fi
                if [[ -n "$reset_5h" ]]; then
                    rt+=" ${white}Resets ${reset_5h}${reset}"
                fi
                _append "$rt"
            fi
        fi

        # 7-day rate limit
        if has_segment "rate_7d"; then
            local pct_7d="" reset_7d=""

            if [[ -n "$RATE_7D_PCT" ]]; then
                pct_7d="${RATE_7D_PCT%.*}"
                reset_7d=$(fmt_reset_date_full "$RATE_7D_RESET")
            elif [[ -n "$USAGE_DATA" ]]; then
                pct_7d=$(echo "$USAGE_DATA" | jq -r '.seven_day.utilization // empty' 2>/dev/null)
                pct_7d="${pct_7d%.*}"
                local api_reset
                api_reset=$(echo "$USAGE_DATA" | jq -r '.seven_day.resets_at // empty' 2>/dev/null)
                if [[ -n "$api_reset" ]]; then
                    if date -j -f "%Y-%m-%dT%H:%M:%S" "${api_reset%%.*}" "+%s" &>/dev/null; then
                        reset_7d=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${api_reset%%.*}" "+%B %-d" 2>/dev/null)
                    else
                        reset_7d=$(date -d "$api_reset" "+%B %-d" 2>/dev/null)
                    fi
                fi
            fi

            if [[ -n "$pct_7d" ]]; then
                local rate_color
                rate_color=$(color_by_pct "$pct_7d")
                local rt="${white}7 Day:${reset} ${rate_color}${pct_7d}%${reset}"
                if [[ "$RATE_STYLE" == "bar" ]]; then
                    rt+=" $(mini_bar "$pct_7d" "$rate_color")"
                fi
                if [[ -n "$reset_7d" ]]; then
                    rt+=" ${white}Resets ${reset_7d}${reset}"
                fi
                _append "$rt"
            fi
        fi

        # Extra usage
        if has_segment "extra"; then
            if [[ -z "$USAGE_DATA" ]]; then USAGE_DATA=$(fetch_usage); fi
            if [[ -n "$USAGE_DATA" ]]; then
                local extra_enabled
                extra_enabled=$(echo "$USAGE_DATA" | jq -r '.extra_usage.is_enabled // empty' 2>/dev/null)
                if [[ "$extra_enabled" == "true" ]]; then
                    local used_cents limit_cents used_dollars limit_dollars
                    used_cents=$(echo "$USAGE_DATA" | jq -r '.extra_usage.used_credits // 0' 2>/dev/null)
                    limit_cents=$(echo "$USAGE_DATA" | jq -r '.extra_usage.monthly_limit // 0' 2>/dev/null)
                    used_dollars=$(printf "%.2f" "$(echo "scale=2; ${used_cents:-0} / 100" | bc)")
                    limit_dollars=$(printf "%.2f" "$(echo "scale=2; ${limit_cents:-0} / 100" | bc)")
                    _append "${white}Extra:${reset} ${br_yellow}\$${used_dollars}${reset}${white}/\$${limit_dollars}${reset}"
                fi
            fi
        fi

        _flush
    fi

}

main
