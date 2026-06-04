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

# Emit the (event \t hook-script-basename) tuples a settings.json wires, one per
# line. The basename is the comparable identity of a hook across scopes: global
# wires `~/.claude/hooks/foo.sh`, a project may wire
# `${CLAUDE_PROJECT_DIR}/.claude/hooks/foo.sh` — same script `foo.sh`, so it is
# the basename (not the path) that double-fires. Matcher is deliberately ignored:
# Claude runs a matching hook per scope regardless, so same event + same script
# in two scopes is a duplicate even if the matchers differ. Args: json_file.
_refcheck_hook_identities() {
    local json_file="$1"
    [[ -f "$json_file" ]] || return 0
    jq -r '
        .hooks // {} | to_entries[]
        | .key as $event
        | .value[]? | .hooks[]? | .command? // ""
        | select(. != "")
        | ($event + "\t" + (sub(".*/"; "") | sub("[[:space:]].*"; "")))
    ' "$json_file" 2>/dev/null | sort -u
}

# Defensive guard against accidental cross-scope hook duplication. Claude Code
# merges hooks ADDITIVELY across user (~/.claude) and project (.claude) scopes
# with no dedup — so the same hook script wired for the same event in both scopes
# runs TWICE. Harmless for idempotent PreToolUse guards (wasted subprocess time)
# but actively bad for context/lifecycle hooks (UserPromptSubmit/Notification),
# which fire twice and waste tokens. This flags every such overlap.
# Args: global_settings_json, project_settings_json
# Returns: 0 if no overlap, 1 if any duplicate (one warning per dup).
refcheck_hook_duplication() {
    local global_json="$1" project_json="$2"
    [[ -f "$global_json" && -f "$project_json" ]] || return 0

    local global_ids project_ids dup event script
    global_ids=$(_refcheck_hook_identities "$global_json")
    project_ids=$(_refcheck_hook_identities "$project_json")
    [[ -z "$global_ids" || -z "$project_ids" ]] && return 0

    local rc=0
    # Lines present in BOTH scope listings = double-firing hooks.
    dup=$(comm -12 <(printf '%s\n' "$global_ids") <(printf '%s\n' "$project_ids"))
    [[ -z "$dup" ]] && return 0
    while IFS=$'\t' read -r event script; do
        [[ -z "$event" ]] && continue
        refcheck_warn "duplicate hook: '$script' on $event is wired in BOTH ~/.claude/settings.json and project .claude/settings.json — Claude merges hooks additively, so it will fire twice. Wire it in one scope only."
        rc=1
    done <<< "$dup"
    return $rc
}
