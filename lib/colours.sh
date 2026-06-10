# lib/colours.sh — TTY-aware colour helpers for dotconfigs output
# Sourced by dotconfigs entry point.

# Initialize colour codes and symbols based on TTY detection
init_colours() {
    if [[ -t 1 ]]; then
        # TTY detected: use ANSI colour codes
        COLOUR_GREEN='\033[32m'
        COLOUR_YELLOW='\033[33m'
        COLOUR_RED='\033[31m'
        COLOUR_CYAN='\033[36m'
        COLOUR_RESET='\033[0m'
        SYMBOL_OK='✓'
        SYMBOL_DRIFT='△'
        SYMBOL_MISSING='✗'
    else
        # Non-TTY (piped): use plain text
        COLOUR_GREEN=''
        COLOUR_YELLOW=''
        COLOUR_RED=''
        COLOUR_CYAN=''
        COLOUR_RESET=''
        SYMBOL_OK='[OK]'
        SYMBOL_DRIFT='[DRIFT]'
        SYMBOL_MISSING='[MISSING]'
    fi
}

# Wrap text in green colour
# Args: text
colour_green() {
    printf "%b%s%b" "$COLOUR_GREEN" "$1" "$COLOUR_RESET"
}

# Wrap text in yellow colour
# Args: text
colour_yellow() {
    printf "%b%s%b" "$COLOUR_YELLOW" "$1" "$COLOUR_RESET"
}

# Wrap text in red colour
# Args: text
colour_red() {
    printf "%b%s%b" "$COLOUR_RED" "$1" "$COLOUR_RESET"
}

# Wrap text in cyan colour
# Args: text
colour_cyan() {
    printf "%b%s%b" "$COLOUR_CYAN" "$1" "$COLOUR_RESET"
}

# Print formatted file status line
# Args: display_name, state
_print_file_status() {
    local display_name="$1"
    local state="$2"

    case "$state" in
        deployed)
            printf "  %b %s\n" "$(colour_green "$SYMBOL_OK")" "$display_name"
            ;;
        drifted-broken)
            printf "  %b %s %b\n" "$(colour_yellow "$SYMBOL_DRIFT")" "$display_name" "$(colour_yellow "(broken symlink)")"
            ;;
        drifted-foreign)
            printf "  %b %s %b\n" "$(colour_yellow "$SYMBOL_DRIFT")" "$display_name" "$(colour_yellow "(foreign file)")"
            ;;
        drifted-wrong-target)
            printf "  %b %s %b\n" "$(colour_yellow "$SYMBOL_DRIFT")" "$display_name" "$(colour_yellow "(wrong target)")"
            ;;
        not-deployed)
            printf "  %b %s\n" "$(colour_red "$SYMBOL_MISSING")" "$display_name"
            ;;
        *)
            printf "  ? %s (unknown state: %s)\n" "$display_name" "$state"
            ;;
    esac
}
