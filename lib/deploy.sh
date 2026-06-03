# lib/deploy.sh — Generic JSON-driven deployment engine
# Sourced by dotconfigs entry point.
# Depends on: lib/symlinks.sh (backup_and_link, is_dotconfigs_owned, link_file)

# Check if jq is installed
# Returns: 0 if installed, 1 with install instructions if not
check_jq() {
    if ! command -v jq &>/dev/null; then
        echo "Error: jq is required but not installed."
        echo ""
        echo "Install instructions:"
        echo "  macOS:   brew install jq"
        echo "  Ubuntu:  sudo apt-get install jq"
        echo "  Fedora:  sudo dnf install jq"
        echo ""
        return 1
    fi
    return 0
}

# Expand tilde in path to $HOME
# Args: path_with_tilde
# Returns: expanded path via stdout
expand_tilde() {
    echo "${1/#\~/$HOME}"
}

# Idempotency check for the append method: every non-blank line in source must
# already appear (exact match) somewhere in target. `grep -qFf` is the obvious
# tool here but it has "any match" semantics and treats blank lines as wildcards,
# so a single common line in target falsely reports the whole source as present.
# Args: source, target
# Returns: 0 if every non-blank source line is present in target, 1 otherwise.
_source_already_appended() {
    local src="$1" tgt="$2"
    [[ -s "$src" && -f "$tgt" ]] || return 1
    local line
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "${line//[[:space:]]/}" ]] && continue
        grep -qFx -- "$line" "$tgt" || return 1
    done < "$src"
    return 0
}

# Parse modules from JSON config recursively
# Args: config_file [, group_key]
# If group_key is empty/unset, walks entire config; otherwise filters to .[$group] first.
# Returns: tab-separated lines: source\ttarget\tmethod\tinclude_csv
parse_modules() {
    local config_file="$1"
    local group_key="${2:-}"

    if [[ -z "$group_key" ]]; then
        # Recursive descent over the whole config
        jq -r '.. | select(type == "object") | select(has("source") and has("target")) | [.source, .target, .method, (if has("include") then ((.include // []) - (.exclude // []) | if length == 0 then "__NONE__" else join(",") end) else "" end)] | @tsv' "$config_file" 2>/dev/null || true
    else
        # Filter to specific group first, then recursive descent
        jq -r --arg group "$group_key" '.[$group] | .. | select(type == "object") | select(has("source") and has("target")) | [.source, .target, .method, (if has("include") then ((.include // []) - (.exclude // []) | if length == 0 then "__NONE__" else join(",") end) else "" end)] | @tsv' "$config_file" 2>/dev/null || true
    fi
}

# Remove stale symlinks from a target directory after deploy
# Removes: dotconfigs-owned symlinks not in deployed set, broken/dangling symlinks
# Preserves: foreign regular files, foreign valid symlinks
# Args: target_dir, deployed_csv (comma-separated expected filenames), dotconfigs_root, dry_run
# Uses global `removed` counter
cleanup_stale_in_directory() {
    local target_dir="$1"
    local deployed_csv="$2"
    local dotconfigs_root="$3"
    local dry_run="$4"
    local item
    local item_name
    local is_expected

    # Target dir doesn't exist — nothing to clean
    if [[ ! -d "$target_dir" ]]; then
        return
    fi

    # Parse deployed_csv into array (bash 3.2 compatible)
    local expected_files=()
    if [[ -n "$deployed_csv" ]]; then
        local IFS=','
        for item_name in $deployed_csv; do
            expected_files+=("$item_name")
        done
        unset IFS
    fi

    # Iterate items in target dir (use both -e and -L to catch broken symlinks)
    for item in "$target_dir"/*; do
        # Handle empty directory (glob returns literal pattern)
        [[ ! -e "$item" && ! -L "$item" ]] && continue

        item_name=$(basename "$item")

        # Check if this item is in the expected set
        is_expected=false
        for expected in "${expected_files[@]}"; do
            if [[ "$expected" == "$item_name" ]]; then
                is_expected=true
                break
            fi
        done

        [[ "$is_expected" == "true" ]] && continue

        # Item is not in the expected deploy set — check if we should remove it
        if [[ -L "$item" && ! -e "$item" ]]; then
            # Broken/dangling symlink — only remove if it pointed into dotconfigs
            local raw_target
            raw_target=$(readlink "$item" 2>/dev/null)
            if [[ "$raw_target" == "$dotconfigs_root"* ]]; then
                if [[ "$dry_run" == "true" ]]; then
                    echo "  Would remove broken symlink: $item_name"
                else
                    rm -f "$item"
                    echo "  ✓ Removed broken symlink: $item_name"
                fi
                eval "removed=\$(( \$removed + 1 ))"
            fi
        elif is_dotconfigs_owned "$item" "$dotconfigs_root" 2>/dev/null; then
            # Stale dotconfigs-owned symlink — remove
            if [[ "$dry_run" == "true" ]]; then
                echo "  Would remove stale: $item_name"
            else
                rm -f "$item"
                echo "  ✓ Removed stale: $item_name"
            fi
            eval "removed=\$(( \$removed + 1 ))"
        fi
        # Otherwise: foreign file or foreign valid symlink — leave it alone
    done
}

# Symlink-deploy a single file or directory, state-aware.
# Reports Unchanged / Would link / Would update / conflict and tallies the
# correct counter (created/updated/unchanged/skipped) via eval into the caller.
# Used for every symlink target so dry-run reflects real on-disk state.
# Args: source, target, name, dotconfigs_root, dry_run, interactive_mode
link_one() {
    local src="$1" tgt="$2" name="$3" root="$4" dry="$5" mode="$6"
    local rel="${src#$root/}"
    local state
    state=$(check_file_state "$tgt" "$src" "$root")

    if [[ "$state" == "deployed" ]]; then
        echo "  Unchanged: $rel -> $tgt"
        eval "unchanged=\$(( \$unchanged + 1 ))"
        return
    fi

    if [[ "$dry" == "true" ]]; then
        case "$state" in
            not-deployed)
                echo "  Would link: $rel -> $tgt"
                eval "created=\$(( \$created + 1 ))"
                ;;
            drifted-foreign)
                if [[ "$mode" == "force" ]]; then
                    echo "  Would overwrite: $rel -> $tgt (--force)"
                    eval "updated=\$(( \$updated + 1 ))"
                else
                    echo "  Would prompt: conflict at $tgt (source: $rel)"
                    eval "skipped=\$(( \$skipped + 1 ))"
                fi
                ;;
            *)
                # drifted-broken / drifted-wrong-target: ours, will be re-pointed
                echo "  Would update: $rel -> $tgt"
                eval "updated=\$(( \$updated + 1 ))"
                ;;
        esac
        return
    fi

    # Real run: act, then count by the prior state.
    backup_and_link "$src" "$tgt" "$name" "$mode"
    local rc=$?
    if [[ $rc -eq 0 ]]; then
        if [[ "$state" == "not-deployed" ]]; then
            eval "created=\$(( \$created + 1 ))"
        else
            eval "updated=\$(( \$updated + 1 ))"
        fi
    elif [[ $rc -eq 2 ]]; then
        eval "unchanged=\$(( \$unchanged + 1 ))"
    else
        eval "skipped=\$(( \$skipped + 1 ))"
    fi
}

# Deploy files from a directory source
# Args: source_dir, target_dir, include_csv, dotconfigs_root, dry_run, interactive_mode
# Returns: Status counts via global counters
deploy_directory_files() {
    local source_dir="$1"
    local target_dir="$2"
    local include_csv="$3"
    local dotconfigs_root="$4"
    local dry_run="$5"
    local interactive_mode="$6"
    local file
    local file_name
    local target_file
    local status

    # All items excluded — deploy nothing, but still clean up stale entries
    if [[ "$include_csv" == "__NONE__" ]]; then
        cleanup_stale_in_directory "$target_dir" "" "$dotconfigs_root" "$dry_run"
        return
    fi

    # Create target directory unless dry-run
    if [[ "$dry_run" != "true" ]]; then
        # If target path exists but isn't a directory (e.g. dangling symlink, file), remove it
        # Note: -d follows symlinks, so symlinks to valid directories are preserved
        if [[ ! -d "$target_dir" && ( -L "$target_dir" || -e "$target_dir" ) ]]; then
            rm -f "$target_dir"
        fi
        mkdir -p "$target_dir"
    fi

    # Parse include list if provided
    if [[ -n "$include_csv" ]]; then
        # Split CSV into array (bash 3.2 compatible - no readarray)
        local include_files=()
        local IFS=','
        for file_name in $include_csv; do
            include_files+=("$file_name")
        done
        unset IFS

        # Deploy only included files
        for file_name in "${include_files[@]}"; do
            file="$source_dir/$file_name"
            target_file="$target_dir/$file_name"

            if [[ ! -e "$file" ]]; then
                echo "  ! Warning: included file not found: $file_name"
                eval "skipped=\$(( \$skipped + 1 ))"
                continue
            fi

            link_one "$file" "$target_file" "$file_name" "$dotconfigs_root" "$dry_run" "$interactive_mode"
        done

        # Clean up stale entries (include-list branch)
        cleanup_stale_in_directory "$target_dir" "$include_csv" "$dotconfigs_root" "$dry_run"
    else
        # Deploy all files in directory, building the deployed CSV as we go.
        local all_csv=""
        for file in "$source_dir"/*; do
            [[ ! -e "$file" ]] && continue
            [[ -d "$file" ]] && continue  # Skip subdirectories

            file_name=$(basename "$file")
            target_file="$target_dir/$file_name"

            link_one "$file" "$target_file" "$file_name" "$dotconfigs_root" "$dry_run" "$interactive_mode"
            all_csv="${all_csv:+$all_csv,}$file_name"
        done

        cleanup_stale_in_directory "$target_dir" "$all_csv" "$dotconfigs_root" "$dry_run"
    fi
}

# Perform the deep-merge into a tmp file alongside target; on success echo the
# tmp path (caller must mv or rm); on failure clean up and return non-zero.
# Args: source, target
_merge_to_tmp() {
    local source="$1" target="$2"
    local tmp="${target}.merge.$$"
    if jq -s '
        .[0] as $live | .[1] as $base
        | ($live * $base)
        | .permissions.allow = ((($live.permissions.allow // []) + ($base.permissions.allow // [])) | unique)
        | .permissions.deny  = ((($live.permissions.deny  // []) + ($base.permissions.deny  // [])) | unique)
        | .permissions.ask   = ((($live.permissions.ask   // []) + ($base.permissions.ask   // [])) | unique)
    ' "$target" "$source" > "$tmp" 2>/dev/null; then
        echo "$tmp"
        return 0
    fi
    rm -f "$tmp"
    return 1
}

# Substitute well-known deploy-time placeholders in a JSON source.
# Currently handles:
#   {{AUTHOR_NAME}}  -> git config --global user.name (fallback: Henry Baker)
#   {{AUTHOR_EMAIL}} -> git config --global user.email (fallback: henry.c.g.baker@gmail.com)
#
# If the source contains no placeholders, echoes the original path unchanged
# and returns 0. Otherwise writes a temp file with substituted content and
# echoes its path; caller must rm the temp file after use.
#
# Args: source
_substitute_placeholders() {
    local source="$1"
    if ! grep -q -e '{{AUTHOR_NAME}}' -e '{{AUTHOR_EMAIL}}' "$source" 2>/dev/null; then
        echo "$source"
        return 0
    fi
    local name email used_fallback=false
    name=$(git config --global user.name 2>/dev/null)
    email=$(git config --global user.email 2>/dev/null)
    if [[ -z "$name" ]]; then
        name="Henry Baker"
        used_fallback=true
    fi
    if [[ -z "$email" ]]; then
        email="henry.c.g.baker@gmail.com"
        used_fallback=true
    fi
    if [[ "$used_fallback" == "true" ]]; then
        echo "  ! attribution: git config --global user.{name,email} not set; using hardcoded fallback ($name <$email>). Set your git identity to override." >&2
    fi
    local tmp
    tmp=$(mktemp -t "dotconfigs.subst.XXXXXX")
    if ! jq --arg name "$name" --arg email "$email" '
        walk(if type == "string" then
            gsub("\\{\\{AUTHOR_NAME\\}\\}"; $name) | gsub("\\{\\{AUTHOR_EMAIL\\}\\}"; $email)
        else . end)
    ' "$source" > "$tmp" 2>/dev/null; then
        rm -f "$tmp"
        # On substitution failure, fall back to the original source so deploy
        # doesn't break — placeholders will land in the target verbatim and the
        # user will see them next time they read the file.
        echo "$source"
        return 1
    fi
    echo "$tmp"
}

# Deep-merge a managed JSON base ($source) into a co-owned target file,
# preserving local entries. Used for files an application writes into (e.g.
# Claude Code appends permission grants to settings.json): a symlink would write
# those grants through into the repo, and a plain copy would clobber them.
#
# Semantics: base wins on managed keys; permissions.{allow,deny,ask} arrays are
# UNIONED so locally-approved grants survive every deploy. Result is a regular
# file (never a symlink). Idempotent.
# Args: source_base, target
# Returns: 0 if target changed, 2 if merge result identical to existing target
#          (idempotent re-run), 1 on jq failure.
merge_json_settings() {
    local source="$1"
    local target="$2"

    # First deploy, or a stale symlink target (nothing local to preserve):
    # place the base as a fresh regular file.
    if [[ ! -e "$target" || -L "$target" ]]; then
        rm -f "$target"
        mkdir -p "$(dirname "$target")"
        cp "$source" "$target"
        return 0
    fi

    local tmp
    tmp=$(_merge_to_tmp "$source" "$target") || return 1

    if cmp -s "$tmp" "$target"; then
        rm -f "$tmp"
        return 2
    fi
    mv "$tmp" "$target"
    return 0
}

# Deploy a single module (source -> target)
# Args: source, target, method, include_csv, dotconfigs_root, dry_run, interactive_mode
# Returns: status string via global counters
deploy_module() {
    local source="$1"
    local target="$2"
    local method="$3"
    local include_csv="$4"
    local dotconfigs_root="$5"
    local dry_run="$6"
    local interactive_mode="$7"
    local abs_source
    local abs_target
    local rel_src

    # Expand tilde in target
    abs_target=$(expand_tilde "$target")

    # Make source absolute if not already
    if [[ "$source" != /* ]]; then
        abs_source="$dotconfigs_root/$source"
    else
        abs_source="$source"
    fi

    # Compute relative source for display
    rel_src="${abs_source#$dotconfigs_root/}"

    # Validate source exists
    if [[ ! -e "$abs_source" ]]; then
        echo "  ! Warning: source not found: $rel_src"
        eval "skipped=\$(( \$skipped + 1 ))"
        return
    fi

    # Switch on method
    case "$method" in
        symlink)
            if [[ -d "$abs_source" ]]; then
                # Directory source: deploy files individually
                deploy_directory_files "$abs_source" "$abs_target" "$include_csv" "$dotconfigs_root" "$dry_run" "$interactive_mode"
            else
                # File source: single symlink
                link_one "$abs_source" "$abs_target" "$(basename "$abs_target")" "$dotconfigs_root" "$dry_run" "$interactive_mode"
            fi
            ;;
        copy)
            if [[ "$dry_run" == "true" ]]; then
                if [[ -f "$abs_target" ]] && cmp -s "$abs_source" "$abs_target"; then
                    echo "  Unchanged: $rel_src -> $abs_target"
                    eval "unchanged=\$(( \$unchanged + 1 ))"
                elif [[ -e "$abs_target" ]]; then
                    echo "  Would copy (overwrite): $rel_src -> $abs_target"
                    eval "updated=\$(( \$updated + 1 ))"
                else
                    echo "  Would copy: $rel_src -> $abs_target"
                    eval "created=\$(( \$created + 1 ))"
                fi
            else
                local target_dir
                target_dir=$(dirname "$abs_target")
                mkdir -p "$target_dir"

                # Check if target already matches source
                if [[ -f "$abs_target" ]] && cmp -s "$abs_source" "$abs_target"; then
                    echo "  Unchanged: $rel_src -> $abs_target"
                    eval "unchanged=\$(( \$unchanged + 1 ))"
                else
                    local existed="false"
                    [[ -e "$abs_target" ]] && existed="true"
                    cp -p "$abs_source" "$abs_target"
                    echo "  ✓ Copied $rel_src -> $abs_target"
                    if [[ "$existed" == "true" ]]; then
                        eval "updated=\$(( \$updated + 1 ))"
                    else
                        eval "created=\$(( \$created + 1 ))"
                    fi
                fi
            fi
            ;;
        merge)
            # JSON deep-merge for co-owned files (preserves local entries; never
            # symlinks, never clobbers). See merge_json_settings.
            #
            # Source is first run through _substitute_placeholders so deploy-time
            # values ({{AUTHOR_NAME}}, {{AUTHOR_EMAIL}}) land in the merged
            # target. If no placeholders are present, the original path is used
            # unchanged (no temp file created).
            local _merge_src
            _merge_src=$(_substitute_placeholders "$abs_source")
            if [[ "$dry_run" == "true" ]]; then
                if [[ ! -f "$abs_target" || -L "$abs_target" ]]; then
                    echo "  Would create $abs_target from $rel_src (merge)"
                    eval "created=\$(( \$created + 1 ))"
                else
                    local _preview
                    if _preview=$(_merge_to_tmp "$_merge_src" "$abs_target") \
                       && cmp -s "$_preview" "$abs_target"; then
                        echo "  Unchanged: $rel_src -> $abs_target (merge no-op)"
                        eval "unchanged=\$(( \$unchanged + 1 ))"
                    else
                        echo "  Would merge $rel_src -> $abs_target (preserving local entries)"
                        eval "updated=\$(( \$updated + 1 ))"
                    fi
                    [[ -n "$_preview" ]] && rm -f "$_preview"
                fi
            else
                # `|| _rc=$?` suppresses set -e so the non-zero "unchanged" (2)
                # and "failed" (1) returns are dispatched here, not fatal.
                local _rc=0
                merge_json_settings "$_merge_src" "$abs_target" || _rc=$?
                case $_rc in
                    0)
                        echo "  ✓ Merged $rel_src -> $abs_target (local entries preserved)"
                        eval "updated=\$(( \$updated + 1 ))"
                        ;;
                    2)
                        echo "  Unchanged: $rel_src -> $abs_target"
                        eval "unchanged=\$(( \$unchanged + 1 ))"
                        ;;
                    *)
                        echo "  ! Merge failed for $abs_target (invalid JSON?); left unchanged" >&2
                        eval "skipped=\$(( \$skipped + 1 ))"
                        ;;
                esac
            fi
            [[ "$_merge_src" != "$abs_source" ]] && rm -f "$_merge_src"
            ;;
        append)
            if [[ "$dry_run" == "true" ]]; then
                if _source_already_appended "$abs_source" "$abs_target"; then
                    echo "  Unchanged: $rel_src -> $abs_target (already present)"
                    eval "unchanged=\$(( \$unchanged + 1 ))"
                else
                    echo "  Would append: $rel_src -> $abs_target"
                    eval "updated=\$(( \$updated + 1 ))"
                fi
            else
                local target_dir
                target_dir=$(dirname "$abs_target")
                mkdir -p "$target_dir"

                # Check if content already present (idempotent)
                if _source_already_appended "$abs_source" "$abs_target"; then
                    echo "  Unchanged: $rel_src -> $abs_target (already present)"
                    eval "unchanged=\$(( \$unchanged + 1 ))"
                else
                    cat "$abs_source" >> "$abs_target"
                    echo "  ✓ Appended $rel_src -> $abs_target"
                    eval "updated=\$(( \$updated + 1 ))"
                fi
            fi
            ;;
        *)
            echo "  ! Warning: unknown method '$method' for $rel_src"
            eval "skipped=\$(( \$skipped + 1 ))"
            ;;
    esac
}

# Check the deployment state of a single module, by method.
# Echoes one tab-separated "<state>\t<display_name>" line per file (for a
# symlink directory module, one line per included file; otherwise one line).
# A missing source is appended to the display name so the user sees the cause.
#
# States: deployed, drifted-broken, drifted-foreign, drifted-wrong-target,
#         not-deployed.
#
# Args: source, target, method, include_csv, dotconfigs_root
check_module_state() {
    local source="$1"
    local target="$2"
    local method="$3"
    local include_csv="$4"
    local dotconfigs_root="$5"
    local abs_source abs_target rel_src

    if [[ "$source" != /* ]]; then
        abs_source="$dotconfigs_root/$source"
    else
        abs_source="$source"
    fi
    abs_target=$(expand_tilde "$target")
    rel_src="${abs_source#"$dotconfigs_root/"}"

    if [[ ! -e "$abs_source" ]]; then
        printf "%s\t%s\n" "not-deployed" "$rel_src (source missing)"
        return 0
    fi

    case "$method" in
        symlink)
            if [[ -d "$abs_source" ]]; then
                [[ "$include_csv" == "__NONE__" ]] && return 0
                local files=() target_base="${abs_target##*/}"
                if [[ -n "$include_csv" ]]; then
                    # IFS=',' for CSV split; set -f disables glob expansion so
                    # an entry like "foo.*" is a literal filename.
                    local IFS=','
                    set -f
                    for f in $include_csv; do files+=("$f"); done
                    set +f
                else
                    local f
                    for f in "$abs_source"/*; do
                        [[ ! -e "$f" ]] && continue
                        [[ -d "$f" ]] && continue
                        files+=("${f##*/}")
                    done
                fi
                local name state
                for name in "${files[@]}"; do
                    state=$(check_file_state "$abs_target/$name" "$abs_source/$name" "$dotconfigs_root")
                    printf "%s\t%s/%s\n" "$state" "$target_base" "$name"
                done
            else
                local state
                state=$(check_file_state "$abs_target" "$abs_source" "$dotconfigs_root")
                printf "%s\t%s\n" "$state" "$rel_src"
            fi
            ;;
        merge)
            # Target is intentionally a superset of source (Claude appends
            # permission grants). We can confirm a regular file exists; a
            # stale dotconfigs symlink doesn't count.
            if [[ -f "$abs_target" && ! -L "$abs_target" ]]; then
                printf "%s\t%s\n" "deployed" "$rel_src"
            else
                printf "%s\t%s\n" "not-deployed" "$rel_src"
            fi
            ;;
        append)
            # Same idempotency contract as deploy_module: every non-blank
            # line of source must already appear in target.
            if _source_already_appended "$abs_source" "$abs_target"; then
                printf "%s\t%s\n" "deployed" "$rel_src"
            else
                printf "%s\t%s\n" "not-deployed" "$rel_src"
            fi
            ;;
        copy)
            if [[ -f "$abs_target" ]] && cmp -s "$abs_source" "$abs_target" 2>/dev/null; then
                printf "%s\t%s\n" "deployed" "$rel_src"
            elif [[ -e "$abs_target" ]]; then
                printf "%s\t%s\n" "drifted-foreign" "$rel_src"
            else
                printf "%s\t%s\n" "not-deployed" "$rel_src"
            fi
            ;;
        *)
            echo "Warning: unknown method '$method' for $rel_src" >&2
            printf "%s\t%s\n" "not-deployed" "$rel_src (unknown method: $method)"
            ;;
    esac
}

# Print a global-config error and return 1 if .dotconfigs/global.json is missing.
# Relies on the caller-scoped $GLOBAL_CONFIG (set in the entry point).
_require_global_config() {
    if [[ ! -f "$GLOBAL_CONFIG" ]]; then
        echo "Error: $GLOBAL_CONFIG not found. Run 'dotconfigs global-init' first." >&2
        return 1
    fi
}

# Emit per-file "<state>\t<name>" lines for every module in a plugin's group.
# Args: plugin
_collect_plugin_states() {
    local plugin="$1"
    parse_modules "$GLOBAL_CONFIG" "$plugin" \
        | while IFS=$'\t' read -r source target method include_csv; do
            check_module_state "$source" "$target" "$method" "$include_csv" "$SCRIPT_DIR"
          done
}

# Tally a "<state>\t<name>" blob into flag/count vars in the caller's scope.
# Args: lines, has_ok_var, has_drift_var, has_missing_var, count_ok_var, total_var
_tally_states() {
    local lines="$1" has_ok_var="$2" has_drift_var="$3" has_missing_var="$4" count_ok_var="$5" total_var="$6"
    local state name ok=false drift=false missing=false n_ok=0 n_total=0

    while IFS=$'\t' read -r state name; do
        [[ -z "$state" ]] && continue
        n_total=$(( n_total + 1 ))
        case "$state" in
            deployed)     ok=true;      n_ok=$(( n_ok + 1 )) ;;
            not-deployed) missing=true ;;
            drifted-*)    drift=true ;;
        esac
    done <<< "$lines"

    eval "$has_ok_var=\$ok"
    eval "$has_drift_var=\$drift"
    eval "$has_missing_var=\$missing"
    eval "$count_ok_var=\$n_ok"
    eval "$total_var=\$n_total"
}

# Undeploy a single module (inverse of deploy_module).
# Removes dotconfigs-owned artefacts; preserves anything we can't safely reverse.
# - symlink:  remove dotconfigs-owned symlinks (file or directory module)
# - copy:     remove iff target byte-matches source (untouched copy); else warn+skip
# - merge:    not safely reversible (target may carry local additions); warn+skip
# - append:   not safely reversible (appended lines may interleave); warn+skip
# Counters used: removed, skipped, unchanged
# Args: source, target, method, include_csv, dotconfigs_root, dry_run
undeploy_module() {
    local source="$1"
    local target="$2"
    local method="$3"
    local include_csv="$4"
    local dotconfigs_root="$5"
    local dry_run="$6"
    local abs_source abs_target rel_src

    abs_target=$(expand_tilde "$target")
    if [[ "$source" != /* ]]; then
        abs_source="$dotconfigs_root/$source"
    else
        abs_source="$source"
    fi
    rel_src="${abs_source#$dotconfigs_root/}"

    case "$method" in
        symlink)
            if [[ -d "$abs_source" ]]; then
                # Directory module: walk expected files
                if [[ "$include_csv" == "__NONE__" ]]; then
                    return
                fi
                local files=() name
                if [[ -n "$include_csv" ]]; then
                    local IFS=','
                    set -f
                    for name in $include_csv; do files+=("$name"); done
                    set +f
                else
                    local f
                    for f in "$abs_source"/*; do
                        [[ ! -e "$f" ]] && continue
                        [[ -d "$f" ]] && continue
                        files+=("${f##*/}")
                    done
                fi
                for name in "${files[@]}"; do
                    _undeploy_symlink "$abs_target/$name" "$dotconfigs_root" "$dry_run" "$rel_src/$name"
                done
            else
                _undeploy_symlink "$abs_target" "$dotconfigs_root" "$dry_run" "$rel_src"
            fi
            ;;
        copy)
            if [[ ! -e "$abs_target" ]]; then
                eval "unchanged=\$(( \$unchanged + 1 ))"
            elif [[ -f "$abs_target" ]] && cmp -s "$abs_source" "$abs_target" 2>/dev/null; then
                if [[ "$dry_run" == "true" ]]; then
                    echo "  Would remove copy: $abs_target"
                else
                    rm -f "$abs_target"
                    echo "  ✓ Removed copy: $abs_target"
                fi
                eval "removed=\$(( \$removed + 1 ))"
            else
                echo "  - Skipped (modified): $abs_target"
                eval "skipped=\$(( \$skipped + 1 ))"
            fi
            ;;
        merge|append)
            if [[ -e "$abs_target" ]]; then
                echo "  - Skipped ($method not safely reversible): $abs_target"
                eval "skipped=\$(( \$skipped + 1 ))"
            else
                eval "unchanged=\$(( \$unchanged + 1 ))"
            fi
            ;;
        *)
            echo "  ! Warning: unknown method '$method' for $rel_src"
            eval "skipped=\$(( \$skipped + 1 ))"
            ;;
    esac
}

# Helper: remove one symlink target if dotconfigs-owned; warn on foreign content.
# Args: target_path, dotconfigs_root, dry_run, display_name
_undeploy_symlink() {
    local tgt="$1" root="$2" dry="$3" name="$4"

    if [[ ! -e "$tgt" && ! -L "$tgt" ]]; then
        eval "unchanged=\$(( \$unchanged + 1 ))"
        return
    fi
    if [[ -L "$tgt" ]] && is_dotconfigs_owned "$tgt" "$root"; then
        if [[ "$dry" == "true" ]]; then
            echo "  Would remove symlink: $tgt"
        else
            rm -f "$tgt"
            echo "  ✓ Removed symlink: $tgt"
        fi
        eval "removed=\$(( \$removed + 1 ))"
        return
    fi
    # Broken dotconfigs-owned symlink: remove if it pointed back into the repo
    if [[ -L "$tgt" && ! -e "$tgt" ]]; then
        local raw_target
        raw_target=$(readlink "$tgt" 2>/dev/null)
        if [[ "$raw_target" == "$root"* ]]; then
            if [[ "$dry" == "true" ]]; then
                echo "  Would remove broken symlink: $tgt"
            else
                rm -f "$tgt"
                echo "  ✓ Removed broken symlink: $tgt"
            fi
            eval "removed=\$(( \$removed + 1 ))"
            return
        fi
    fi
    echo "  - Skipped (foreign): $tgt"
    eval "skipped=\$(( \$skipped + 1 ))"
}

# Walk a config and undeploy every module. Mirror of deploy_from_json.
# Args: config_file, dotconfigs_root, [group_key], [dry_run], [project_root]
undeploy_from_json() {
    local config_file="$1"
    local dotconfigs_root="$2"
    local group_key="${3:-}"
    local dry_run="${4:-true}"
    local project_root="${5:-}"
    local modules_data source target method include_csv

    if ! check_jq; then
        return 1
    fi
    if [[ ! -f "$config_file" ]]; then
        echo "Error: config file not found: $config_file"
        return 1
    fi

    removed=0
    skipped=0
    unchanged=0

    modules_data=$(parse_modules "$config_file" "$group_key")
    if [[ -z "$modules_data" ]]; then
        echo "No modules found in $config_file"
        [[ -n "$group_key" ]] && echo "(group: $group_key)"
        return 0
    fi

    if [[ "$dry_run" == "true" ]]; then
        echo "Dry-run mode: no changes will be made"
        echo ""
    fi
    if [[ -n "$group_key" ]]; then
        echo "Undeploying group: $group_key"
    else
        echo "Undeploying all modules"
    fi
    echo ""

    while IFS=$'\t' read -r source target method include_csv; do
        if [[ -n "$project_root" && "$target" != /* && "$target" != ~* ]]; then
            target="$project_root/$target"
        fi
        undeploy_module "$source" "$target" "$method" "$include_csv" "$dotconfigs_root" "$dry_run"
    done <<< "$modules_data"

    echo ""
    echo "Undeploy summary:"
    if [[ "$dry_run" == "true" ]]; then
        echo "  Would remove: $removed"
    else
        echo "  Removed:      $removed"
    fi
    echo "  Unchanged:    $unchanged"
    echo "  Skipped:      $skipped"
}

# Main deployment entry point
# Args: config_file, dotconfigs_root, [group_key], [dry_run], [force], [project_root]
deploy_from_json() {
    local config_file="$1"
    local dotconfigs_root="$2"
    local group_key="${3:-}"
    local dry_run="${4:-false}"
    local force="${5:-false}"
    local project_root="${6:-}"
    local interactive_mode
    local modules_data
    local line
    local source
    local target
    local method
    local include_csv

    # Check jq dependency
    if ! check_jq; then
        return 1
    fi

    # Validate config file exists
    if [[ ! -f "$config_file" ]]; then
        echo "Error: config file not found: $config_file"
        return 1
    fi

    # Determine interactive mode from force flag
    if [[ "$force" == "true" ]]; then
        interactive_mode="force"
    else
        interactive_mode="true"
    fi

    # Initialize counters (bash 3.2 compatible - no local -i)
    created=0
    updated=0
    unchanged=0
    skipped=0
    removed=0

    # Parse modules
    modules_data=$(parse_modules "$config_file" "$group_key")

    # Check if any modules found
    if [[ -z "$modules_data" ]]; then
        echo "No modules found in $config_file"
        if [[ -n "$group_key" ]]; then
            echo "(group: $group_key)"
        fi
        return 0
    fi

    # Print header
    if [[ "$dry_run" == "true" ]]; then
        echo "Dry-run mode: no changes will be made"
        echo ""
    fi

    if [[ -n "$group_key" ]]; then
        echo "Deploying group: $group_key"
    else
        echo "Deploying all modules"
    fi
    echo ""

    # Deploy each module
    while IFS=$'\t' read -r source target method include_csv; do
        # If project_root is set, resolve relative targets against it
        if [[ -n "$project_root" && "$target" != /* && "$target" != ~* ]]; then
            target="$project_root/$target"
        fi
        deploy_module "$source" "$target" "$method" "$include_csv" "$dotconfigs_root" "$dry_run" "$interactive_mode"
    done <<< "$modules_data"

    # Print summary
    echo ""
    echo "Deployment summary:"
    echo "  Created:   $created"
    echo "  Updated:   $updated"
    echo "  Unchanged: $unchanged"
    echo "  Removed:   $removed"
    echo "  Skipped:   $skipped"
}
