# lib/wizard.sh — Interactive wizard helper functions
# Sourced by dotconfigs entry point.

# Display a prompt and read user input with a default value
# Args: prompt_text, default_value, variable_name
wizard_prompt() {
    local prompt_text="$1"
    local default_value="$2"
    local variable_name="$3"
    local user_input

    read -p "$prompt_text [$default_value]: " user_input
    eval "$variable_name=\${user_input:-$default_value}"
}

# Display a bash select menu and return the choice
# Args: prompt_text, options_array (name of array variable)
wizard_select() {
    local prompt_text="$1"
    local options_var="$2"

    echo "$prompt_text"
    eval "local options=(\"\${${options_var}[@]}\")"
    select choice in "${options[@]}"; do
        if [[ -n "$choice" ]]; then
            echo "$choice"
            return 0
        else
            echo "Invalid selection. Try again." >&2
        fi
    done
}

# Ask a yes/no question with default
# Args: prompt_text, default (y/n)
# Returns: 0 for yes, 1 for no
wizard_yesno() {
    local prompt_text="$1"
    local default="$2"
    local user_input
    local default_hint

    if [[ "$default" == "y" ]]; then
        default_hint="Y/n"
    else
        default_hint="y/N"
    fi

    read -p "$prompt_text [$default_hint]: " user_input
    user_input="${user_input:-$default}"

    user_input=$(echo "$user_input" | tr '[:upper:]' '[:lower:]')
    case "$user_input" in
        y|yes) return 0 ;;
        n|no) return 1 ;;
        *)
            echo "Invalid input. Please enter y or n." >&2
            wizard_yesno "$prompt_text" "$default"
            ;;
    esac
}

# Print a formatted step header
# Args: step_number, step_title
wizard_header() {
    local step_number="$1"
    local step_title="$2"

    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "  Step $step_number: $step_title"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
}

# Check if a value exists in a space-separated string
# Args: value, space_separated_string
# Returns: 0 if found, 1 if not
_is_in_list() {
    local needle="$1"
    local haystack="$2"
    local item

    for item in $haystack; do
        if [[ "$item" == "$needle" ]]; then
            return 0
        fi
    done
    return 1
}

# Append a key=value pair to .env file
# Args: env_file, key, value
wizard_save_env() {
    local env_file="$1"
    local key="$2"
    local value="$3"

    # Check if key already exists
    if grep -q "^${key}=" "$env_file" 2>/dev/null; then
        # Update existing key
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s|^${key}=.*|${key}=\"${value}\"|" "$env_file"
        else
            sed -i "s|^${key}=.*|${key}=\"${value}\"|" "$env_file"
        fi
    else
        # Append new key
        echo "${key}=\"${value}\"" >> "$env_file"
    fi
}
