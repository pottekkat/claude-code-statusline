#!/usr/bin/env bash
# Claude Code Statusline - Interactive Installer
# https://github.com/pottekkat/claude-code-statusline

set -euo pipefail

# ── Colors ────────────────────────────────────────────────────────────────────
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
MAGENTA="\033[35m"
CYAN="\033[36m"
WHITE="\033[37m"
DIM="\033[2m"
BOLD="\033[1m"
RESET="\033[0m"
BR_BLACK="\033[90m"

# ── Config ────────────────────────────────────────────────────────────────────
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATUSLINE_SRC="$SCRIPT_DIR/statusline.sh"
STATUSLINE_DEST="$CLAUDE_DIR/statusline.sh"
CONFIG_DEST="$CLAUDE_DIR/statusline-config.json"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"

# ── Helpers ───────────────────────────────────────────────────────────────────
info()    { printf "${BLUE}  info${RESET} %s\n" "$1"; }
success() { printf "${GREEN}    ok${RESET} %s\n" "$1"; }
warn()    { printf "${YELLOW}  warn${RESET} %s\n" "$1"; }
error()   { printf "${RED} error${RESET} %s\n" "$1"; }

prompt_yn() {
    local msg="$1" default="${2:-y}"
    local yn
    if [[ "$default" == "y" ]]; then
        printf "${CYAN}     ?${RESET} %s ${DIM}[Y/n]${RESET} " "$msg"
    else
        printf "${CYAN}     ?${RESET} %s ${DIM}[y/N]${RESET} " "$msg"
    fi
    read -r yn
    yn="${yn:-$default}"
    [[ "$yn" =~ ^[Yy] ]]
}

prompt_choice() {
    local msg="$1"
    shift
    local options=("$@")
    printf "\n${CYAN}     ?${RESET} %s\n" "$msg"
    for i in "${!options[@]}"; do
        printf "       ${DIM}%d)${RESET} %s\n" $((i+1)) "${options[$i]}"
    done
    printf "       ${DIM}Choose [1-%d]:${RESET} " "${#options[@]}"
    local choice
    read -r choice
    echo "${choice:-1}"
}

# ── Header ────────────────────────────────────────────────────────────────────
print_header() {
    printf "\n"
    printf "${BOLD}${MAGENTA}  Claude Code Statusline${RESET}\n"
    printf "${DIM}  A beautiful, configurable statusline for Claude Code${RESET}\n"
    printf "\n"
}

# ── Uninstall ─────────────────────────────────────────────────────────────────
uninstall() {
    print_header
    info "Uninstalling Claude Code Statusline..."

    if [[ -f "$STATUSLINE_DEST" ]]; then
        rm "$STATUSLINE_DEST"
        success "Removed $STATUSLINE_DEST"
    fi

    if [[ -f "$CONFIG_DEST" ]]; then
        rm "$CONFIG_DEST"
        success "Removed $CONFIG_DEST"
    fi

    # Remove statusLine from settings.json
    if [[ -f "$SETTINGS_FILE" ]]; then
        local tmp
        tmp=$(jq 'del(.statusLine)' "$SETTINGS_FILE" 2>/dev/null) || true
        if [[ -n "$tmp" ]]; then
            echo "$tmp" > "$SETTINGS_FILE"
            success "Removed statusLine from settings.json"
        fi
    fi

    # Restore backup if exists
    if [[ -f "$STATUSLINE_DEST.bak" ]]; then
        if prompt_yn "Restore previous statusline from backup?"; then
            mv "$STATUSLINE_DEST.bak" "$STATUSLINE_DEST"
            success "Restored backup"
        fi
    fi

    printf "\n${GREEN}  Uninstalled successfully.${RESET}\n\n"
    exit 0
}

# ── Detect NerdFonts ──────────────────────────────────────────────────────────
detect_nerdfonts() {
    # Try rendering a NerdFont character and checking terminal width
    # This isn't 100% reliable, so we'll also ask the user
    local has_nf=false

    # Check common NerdFont installations
    if fc-list 2>/dev/null | grep -qi "nerd\|NF\|Nerd Font"; then
        has_nf=true
    elif [[ "$(uname)" == "Darwin" ]]; then
        # macOS: check common NerdFont locations
        if ls ~/Library/Fonts/*Nerd* 2>/dev/null | head -1 &>/dev/null || \
           ls /Library/Fonts/*Nerd* 2>/dev/null | head -1 &>/dev/null; then
            has_nf=true
        fi
    fi

    echo "$has_nf"
}

# ── NerdFont test display ────────────────────────────────────────────────────
show_nerdfonts_test() {
    printf "\n  ${DIM}If these icons render correctly, you have NerdFonts:${RESET}\n"
    printf "  󰚩  󰍛  󰊕        󰏘    󰗴   \n"
    printf "  ${DIM}(robot, memory, bolt, branch, folder, clock, dollar,${RESET}\n"
    printf "  ${DIM} paint, code, counter, diff-add, diff-remove)${RESET}\n\n"
}

# ── Segment selector ──────────────────────────────────────────────────────────
select_segments() {
    local segments=()

    printf "\n${CYAN}     ?${RESET} Select which segments to show ${DIM}(y/n for each):${RESET}\n\n"

    local all_segments=(
        "agent:Agent name (when running as agent):true"
        "worktree:Worktree info (when in worktree):true"
        "model:Model name (Opus/Sonnet/Haiku):true"
        "context:Context window usage:true"
        "git:Git branch and status:true"
        "directory:Current directory name:true"
        "duration:Session duration:true"
        "cost:Session cost (API users):true"
        "lines:Lines added/removed:true"
        "tokens:Token counts (in/out):false"
        "effort:Thinking effort level:true"
        "version:Claude Code version:false"
        "style:Output style name:false"
        "rate_5h:5-hour rate limit:true"
        "rate_7d:7-day rate limit:true"
        "extra:Extra usage credits:true"
    )

    for entry in "${all_segments[@]}"; do
        local key="${entry%%:*}"
        local rest="${entry#*:}"
        local desc="${rest%%:*}"
        local default="${rest##*:}"

        local default_label
        if [[ "$default" == "true" ]]; then
            default_label="Y/n"
        else
            default_label="y/N"
        fi

        printf "       ${DIM}%-12s${RESET} %-40s ${DIM}[%s]${RESET} " "$key" "$desc" "$default_label"
        local yn
        read -r yn
        yn="${yn:-$( [[ "$default" == "true" ]] && echo "y" || echo "n" )}"

        if [[ "$yn" =~ ^[Yy] ]]; then
            segments+=("$key")
        fi
    done

    echo "${segments[*]}" | tr ' ' ','
}

# ── Main install ──────────────────────────────────────────────────────────────
main() {
    # Handle --uninstall flag
    if [[ "${1:-}" == "--uninstall" || "${1:-}" == "uninstall" ]]; then
        uninstall
    fi

    print_header

    # ── Check dependencies ────────────────────────────────────────────────────
    local missing=()
    for cmd in jq git curl bc; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done
    if (( ${#missing[@]} > 0 )); then
        error "Missing dependencies: ${missing[*]}"
        info "Please install them first."
        exit 1
    fi
    success "Dependencies found (jq, git, curl, bc)"

    # ── Check for existing statusline ─────────────────────────────────────────
    if [[ -f "$STATUSLINE_DEST" ]]; then
        warn "Existing statusline found at $STATUSLINE_DEST"
        if prompt_yn "Back up and replace it?"; then
            cp "$STATUSLINE_DEST" "$STATUSLINE_DEST.bak"
            success "Backed up to ${STATUSLINE_DEST}.bak"
        else
            error "Installation cancelled."
            exit 1
        fi
    fi

    # ── NerdFonts ─────────────────────────────────────────────────────────────
    local use_nerdfonts=true
    local detected
    detected=$(detect_nerdfonts)

    if [[ "$detected" == "true" ]]; then
        info "NerdFonts detected on your system"
        show_nerdfonts_test
        if ! prompt_yn "Do the icons above render correctly?"; then
            use_nerdfonts=false
            info "NerdFonts disabled, using text fallbacks"
        else
            success "NerdFonts enabled"
        fi
    else
        info "NerdFonts not detected"
        show_nerdfonts_test
        if prompt_yn "Do the icons above render correctly?" "n"; then
            use_nerdfonts=true
            success "NerdFonts enabled"
        else
            use_nerdfonts=false
            info "Using text fallbacks (no NerdFonts)"
        fi
    fi

    # ── Preset selection ──────────────────────────────────────────────────────
    local preset
    preset=$(prompt_choice "Choose a preset:" \
        "Minimal    - Model, context, git branch" \
        "Standard   - Most info on one clean line (recommended)" \
        "Full       - Everything including tokens, version, style" \
        "Custom     - Choose individual segments")

    local segments=""
    local context_style="bar"
    local rate_style="bar"

    case "$preset" in
        1)
            segments="model,context,git"
            compact=true
            context_style="percent"
            rate_style="percent"
            info "Minimal preset selected"
            ;;
        2)
            segments="agent,worktree,model,context,git,directory,duration,cost,lines,effort,rate_5h,rate_7d,extra"
            info "Standard preset selected"
            ;;
        3)
            segments="agent,worktree,model,context,git,directory,duration,cost,lines,tokens,effort,version,style,api_time,rate_5h,rate_7d,extra"
            info "Full preset selected"
            ;;
        4)
            segments=$(select_segments)
            info "Custom segments: $segments"
            ;;
        *)
            segments="agent,worktree,model,context,git,directory,duration,cost,lines,effort,rate_5h,rate_7d,extra"
            info "Standard preset selected (default)"
            ;;
    esac

    # ── Context display style ─────────────────────────────────────────────────
    if [[ "$preset" != "1" ]]; then
        local ctx_choice
        ctx_choice=$(prompt_choice "Context window display style:" \
            "Progress bar  - 42% ████░░░░" \
            "Percentage    - 42%" \
            "Token count   - 185k/1.0M")

        case "$ctx_choice" in
            2) context_style="percent";;
            3) context_style="tokens";;
            *) context_style="bar";;
        esac
    fi

    # ── Rate limit display ────────────────────────────────────────────────────
    if [[ ",$segments," == *",rate_5h,"* || ",$segments," == *",rate_7d,"* ]]; then
        local rate_choice
        rate_choice=$(prompt_choice "Rate limit display:" \
            "Mini bars  - 35% █░░░░" \
            "Percentage - 35%")

        case "$rate_choice" in
            2) rate_style="percent";;
            *) rate_style="bar";;
        esac

    fi

    # ── Install ───────────────────────────────────────────────────────────────
    printf "\n"
    info "Installing..."

    # Ensure directory exists
    mkdir -p "$CLAUDE_DIR"

    # Copy statusline script
    cp "$STATUSLINE_SRC" "$STATUSLINE_DEST"
    chmod +x "$STATUSLINE_DEST"
    success "Installed statusline.sh to $STATUSLINE_DEST"

    # Write config
    cat > "$CONFIG_DEST" <<EOF
{
  "nerdfonts": $use_nerdfonts,
  "segments": "$segments",
  "context_style": "$context_style",
  "rate_style": "$rate_style"
}
EOF
    success "Created config at $CONFIG_DEST"

    # Update settings.json
    if [[ -f "$SETTINGS_FILE" ]]; then
        local tmp
        tmp=$(jq '.statusLine = {"type": "command", "command": "bash \"$HOME/.claude/statusline.sh\""}' "$SETTINGS_FILE" 2>/dev/null)
        if [[ -n "$tmp" ]]; then
            echo "$tmp" > "$SETTINGS_FILE"
        fi
    else
        cat > "$SETTINGS_FILE" <<EOF
{
  "statusLine": {
    "type": "command",
    "command": "bash \"\$HOME/.claude/statusline.sh\""
  }
}
EOF
    fi
    success "Updated settings.json"

    # ── Preview ───────────────────────────────────────────────────────────────
    printf "\n${BOLD}  Preview:${RESET}\n"
    printf "  ${DIM}─────────────────────────────────────────────${RESET}\n"
    printf "  "

    # Generate preview with mock data
    echo '{"model":{"id":"claude-opus-4-6","display_name":"Opus 4.6 (1M context)"},"cwd":"'"$PWD"'","workspace":{"current_dir":"'"$PWD"'"},"context_window":{"context_window_size":1000000,"used_percentage":42,"total_input_tokens":185000,"total_output_tokens":23000,"current_usage":{"input_tokens":85000,"output_tokens":5000,"cache_creation_input_tokens":50000,"cache_read_input_tokens":50000}},"cost":{"total_cost_usd":1.23,"total_duration_ms":723000,"total_api_duration_ms":145000,"total_lines_added":42,"total_lines_removed":15},"rate_limits":{"five_hour":{"used_percentage":35,"resets_at":'"$(( $(date +%s) + 7200 ))"'},"seven_day":{"used_percentage":12,"resets_at":'"$(( $(date +%s) + 604800 ))"'}},"version":"1.0.34"}' | bash "$STATUSLINE_DEST" 2>/dev/null | while IFS= read -r line; do
        printf "  %s\n" "$line"
    done

    printf "  ${DIM}─────────────────────────────────────────────${RESET}\n"

    printf "\n${GREEN}${BOLD}  Installation complete!${RESET}\n"
    printf "${DIM}  Restart Claude Code to see your new statusline.${RESET}\n"
    printf "${DIM}  Edit $CONFIG_DEST to customize further.${RESET}\n"
    printf "${DIM}  Run 'bash install.sh --uninstall' to remove.${RESET}\n\n"
}

main "$@"
