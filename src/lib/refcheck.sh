# lib/refcheck.sh — strict deployed-reference scanner for dotconfigs
# Sourced by dotconfigs entry point and by `dotconfigs validate`.
# Depends on: jq. Colour vars (COLOUR_*) are used if set, else degrade to plain.
#
# Purpose: catch dangling references that a plain deploy would happily install —
# e.g. a settings.json `statusLine.command` or hook `command` pointing at a
# script that isn't actually deployed (the class of bug that silently shipped a
# missing statusLine helper before this existed).
#
# Functions emit "  ! <message>" warnings on stderr and tally into the caller's
# `warnings` counter when one is in scope (via the optional refcheck_warn shim).

# Increment the caller's `warnings` counter if it exists; always print to stderr.
# Args: message
refcheck_warn() {
    printf "  %b! %s%b\n" "${COLOUR_YELLOW:-}" "$1" "${COLOUR_RESET:-}" >&2
    # `warnings` may be unset when refcheck runs standalone (validate); guard it.
    if [[ -n "${warnings+x}" ]]; then
        warnings=$(( warnings + 1 ))
    fi
}

# Warn when a Claude item is selected in BOTH the machine and a project
# selection. ~/.claude is read by Claude Code in every directory, so deploying
# the same item into <repo>/.claude as well means Claude loads it twice -- a
# skill read twice, a hook fired twice (settings.json merges additively). Git is
# exempt by construction: a repo has exactly one .git/hooks/<x> (it cannot run
# twice), and the template dir only seeds *new* repos, so a git hook selected
# machine-wide and per-project never covers the same repo twice. Tally via
# refcheck_warn. Args: machine_deploy_json, project_deploy_json, project_label
refcheck_claude_duplication() {
    local machine="$1" project="$2" label="$3" dups
    [[ -f "$machine" && -f "$project" ]] || return 0
    command -v jq >/dev/null 2>&1 || return 0
    dups=$(jq -rn --slurpfile m "$machine" --slurpfile p "$project" '
        ($m[0].claude // {}) as $mc | ($p[0].claude // {}) as $pc
        | [ $mc | to_entries[] | .key as $cat | .value | to_entries[]
            | select(.value == true and ($pc[$cat][.key] == true))
            | "claude/\($cat)/\(.key)" ]
        | join(", ")
    ' 2>/dev/null) || return 0
    [[ -z "$dups" ]] && return 0
    refcheck_warn "duplicate: active both machine-wide (~/.claude) and in $label, so Claude loads each twice -- disable in one selection: $dups"
}

# Resolve a referenced command/path to an absolute, checkable filesystem path.
# Expands a leading ~, substitutes ${CLAUDE_PROJECT_DIR}/$CLAUDE_PROJECT_DIR
# (using $base_dir as the stand-in), and strips a leading "command " wrapper.
# Bare command names (no slash) are treated as PATH lookups, not file checks.
# Args: raw_reference, base_dir
# Output: absolute path to check via stdout, or empty if it's a PATH-style name.
refcheck_resolve_path() {
    local ref="$1" base="$2"
    # Drop any argument suffix: keep only the first whitespace-delimited token.
    ref="${ref%%[[:space:]]*}"
    [[ -z "$ref" ]] && return 0

    # Substitute the project-dir variable in both ${VAR} and $VAR forms.
    ref="${ref//\$\{CLAUDE_PROJECT_DIR\}/$base}"
    ref="${ref//\$CLAUDE_PROJECT_DIR/$base}"
    # Substitute the plugin-root variable (native-plugin command form).
    ref="${ref//\$\{CLAUDE_PLUGIN_ROOT\}/$base}"

    case "$ref" in
        '~'/*) echo "${ref/#\~/$HOME}" ;;
        /*)    echo "$ref" ;;
        ./*)   echo "$base/${ref#./}" ;;
        */*)   echo "$base/$ref" ;;          # relative path with a slash
        *)     echo "" ;;                    # bare name → PATH lookup, skip
    esac
}

# Scan one JSON settings file for command/helper references that point at
# files which do not exist. Checks statusLine.command, every
# hooks[*][*].hooks[*].command, apiKeyHelper, and awsCredentialExport.
# Args: json_file, base_dir (for relative/${CLAUDE_PROJECT_DIR} resolution)
# Returns: 0 if all references resolve, 1 if any dangle (warnings emitted).
refcheck_settings_json() {
    local json_file="$1" base_dir="${2:-$PWD}"
    [[ -f "$json_file" ]] || return 0

    local refs
    refs=$(jq -r '
        [ .statusLine.command?,
          .apiKeyHelper?,
          .awsCredentialExport?,
          (.hooks // {} | .[]? | .[]? | .hooks[]? | .command?)
        ] | map(select(. != null and . != "")) | .[]
    ' "$json_file" 2>/dev/null)

    [[ -z "$refs" ]] && return 0

    local rc=0 ref resolved
    while IFS= read -r ref; do
        [[ -z "$ref" ]] && continue
        resolved=$(refcheck_resolve_path "$ref" "$base_dir")
        # Empty → bare PATH-style command; nothing to existence-check.
        [[ -z "$resolved" ]] && continue
        if [[ ! -e "$resolved" ]]; then
            refcheck_warn "dangling reference in $(basename "$json_file"): '$ref' → $resolved (not found)"
            rc=1
        fi
    done <<< "$refs"
    return $rc
}
