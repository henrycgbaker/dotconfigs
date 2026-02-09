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
        # Update existing key (with quoting)
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s|^${key}=.*|${key}=\"${value}\"|" "$env_file"
        else
            sed -i "s|^${key}=.*|${key}=\"${value}\"|" "$env_file"
        fi
    else
        # Append new key (with quoting)
        echo "${key}=\"${value}\"" >> "$env_file"
    fi
}

# Display checkbox menu for multi-select
# Args: title, options_array_name, selected_array_name
# Usage: wizard_checkbox_menu "Select configs:" available_configs selected_configs
wizard_checkbox_menu() {
    local title="$1"
    local options_var="$2"
    local selected_var="$3"

    # Get arrays by name (bash 3.2 compatible)
    eval "local opts_str=\"\${${options_var}[*]}\""
    eval "local sel_str=\"\${${selected_var}[*]}\""

    # Convert to arrays
    local opts=($opts_str)
    local sel=($sel_str)

    while true; do
        echo "$title"
        echo "  (Enter number to toggle, 'done' to finish, 'all' to select all)"
        echo ""

        local i=1
        for opt in "${opts[@]}"; do
            local checked=" "
            if _is_in_list "$opt" "$sel_str"; then
                checked="x"
            fi
            echo "  [$checked] $i) $opt"
            i=$((i + 1))
        done
        echo ""

        read -p "Choice: " choice

        if [[ "$choice" == "done" ]] || [[ -z "$choice" ]]; then
            # Update the selected array by reference
            eval "${selected_var}=(\${sel[@]})"
            return 0
        elif [[ "$choice" == "all" ]]; then
            sel=("${opts[@]}")
            sel_str="${sel[*]}"
            continue
        elif [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le "${#opts[@]}" ]]; then
            local idx=$((choice - 1))
            local item="${opts[$idx]}"

            # Toggle: remove if present, add if absent
            if _is_in_list "$item" "$sel_str"; then
                # Remove from selected
                local new_sel=()
                for s in "${sel[@]}"; do
                    [[ "$s" != "$item" ]] && new_sel+=("$s")
                done
                sel=("${new_sel[@]}")
            else
                # Add to selected
                sel+=("$item")
            fi
            sel_str="${sel[*]}"
        else
            echo "Invalid choice, try again"
        fi
    done
}

# Display a numbered category menu using read (not select)
# Args: title, category_names (array name)
# Returns: selected index (0-based) via exit code, prints category name to stdout
wizard_category_menu() {
    local title="$1"
    local categories_var="$2"

    # Get category array by name (bash 3.2 compatible)
    eval "local cats_str=\"\${${categories_var}[*]}\""
    local cats=($cats_str)

    while true; do
        echo "$title"
        echo ""

        local i=1
        for cat in "${cats[@]}"; do
            echo "  $i) $cat"
            i=$((i + 1))
        done
        echo ""

        read -p "Select category (1-${#cats[@]}): " choice

        if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le "${#cats[@]}" ]]; then
            local idx=$((choice - 1))
            echo "${cats[$idx]}"
            return $idx
        else
            echo "Invalid selection. Try again." >&2
        fi
    done
}

# Display current configuration in edit mode format
# Args: config_labels (array name), config_values (array name), config_managed (array name)
# Prints numbered list with values or [not managed] for unmanaged items
wizard_edit_mode_display() {
    local labels_var="$1"
    local values_var="$2"
    local managed_var="$3"

    # Get array length (bash 3.2 compatible — no namerefs)
    eval "local count=\${#${labels_var}[@]}"

    local i=0
    while [[ $i -lt $count ]]; do
        eval "local label=\"\${${labels_var}[$i]}\""
        eval "local value=\"\${${values_var}[$i]}\""
        eval "local is_managed=\"\${${managed_var}[$i]}\""

        local display_num=$((i + 1))
        if [[ "$is_managed" == "true" ]]; then
            echo "  $display_num) $label = $value"
        else
            printf "  %d) %s: " "$display_num" "$label"
            colour_not_managed
            echo ""
        fi
        i=$((i + 1))
    done
}

# Parse comma-separated number input for edit mode
# Args: input_string, max_index (0-based)
# Prints space-separated list of valid 0-based indices to stdout
wizard_parse_edit_selection() {
    local input="$1"
    local max_index="$2"

    # Remove whitespace and split by comma
    input=$(echo "$input" | tr -d ' ')
    local IFS=','
    local nums=($input)

    local result=()
    local seen=""

    for num in "${nums[@]}"; do
        if [[ "$num" =~ ^[0-9]+$ ]]; then
            local idx=$((num - 1))
            if [[ $idx -ge 0 ]] && [[ $idx -le $max_index ]]; then
                # Deduplicate
                if ! _is_in_list "$idx" "$seen"; then
                    result+=("$idx")
                    seen="$seen $idx"
                fi
            fi
        fi
    done

    echo "${result[*]}"
}

# Display config toggle menu with checkboxes
# Args: title, config_names (array name), selected (array name)
# Updates selected array in-place with user choices
wizard_config_toggle() {
    local title="$1"
    local options_var="$2"
    local selected_var="$3"

    # Get arrays by name (bash 3.2 compatible)
    eval "local opts_str=\"\${${options_var}[*]}\""
    eval "local sel_str=\"\${${selected_var}[*]}\""

    local opts=($opts_str)
    local sel=($sel_str)

    while true; do
        echo "$title"
        echo "  (Enter number to toggle, 'all' to select all, 'none' to deselect all, 'done' to finish)"
        echo ""

        local i=1
        for opt in "${opts[@]}"; do
            local checked=" "
            if _is_in_list "$opt" "$sel_str"; then
                checked="x"
            fi
            echo "  [$checked] $i) $opt"
            i=$((i + 1))
        done
        echo ""

        read -p "Choice: " choice

        if [[ "$choice" == "done" ]] || [[ -z "$choice" ]]; then
            # Update the selected array by reference
            eval "${selected_var}=(\${sel[@]})"
            return 0
        elif [[ "$choice" == "all" ]]; then
            sel=("${opts[@]}")
            sel_str="${sel[*]}"
            continue
        elif [[ "$choice" == "none" ]]; then
            sel=()
            sel_str=""
            continue
        elif [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le "${#opts[@]}" ]]; then
            local idx=$((choice - 1))
            local item="${opts[$idx]}"

            # Toggle: remove if present, add if absent
            if _is_in_list "$item" "$sel_str"; then
                # Remove from selected
                local new_sel=()
                for s in "${sel[@]}"; do
                    [[ "$s" != "$item" ]] && new_sel+=("$s")
                done
                sel=("${new_sel[@]}")
            else
                # Add to selected
                sel+=("$item")
            fi
            sel_str="${sel[*]}"
        else
            echo "Invalid choice, try again"
        fi
    done
}
