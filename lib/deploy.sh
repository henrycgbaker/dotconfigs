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

# Resolve a manifest source (repo-relative or already absolute) to an absolute
# path against the repo root. Args: source, dotconfigs_root
_abs_source() {
    case "$1" in
        /*) printf '%s' "$1" ;;
        *)  printf '%s/%s' "$2" "$1" ;;
    esac
}

# Resolve a manifest target to its final absolute path: expand a leading ~, then
# prefix with project_root when the target is project-scoped (relative). Machine
# targets (already ~/absolute) pass through unprefixed. Args: target, project_root
resolve_target() {
    local t; t=$(expand_tilde "$1")
    [[ -n "$2" && "$t" != /* ]] && t="$2/$t"
    printf '%s' "$t"
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

# --- managed-block method --------------------------------------------------
# A "managed" target is a line-oriented file dotconfigs co-owns with the user,
# but unlike `append` the managed region is delimited by sentinel markers so it
# can be UPDATED in place on re-deploy and REMOVED on undeploy. Used for
# untracked, dotconfigs-owned files like `.git/info/exclude` whose source block
# evolves over time. (Tracked, team-owned files like `.gitignore` stay on
# `append`: seed-once, never rewrite a committed file.)
#
# Markers are keyed by the module's relative source path so multiple managed
# blocks coexist in one target. Marker lines are `#` comments, inert in every
# file `managed` targets (git config / exclude / ignore syntax).

# Set caller-scoped `_mb_begin` / `_mb_end` to the marker pair for block_id.
# Caller must declare both `local` first. (Assign-by-dynamic-scope keeps the
# three managed case arms from repeating the marker strings or a split.)
# Args: block_id (stable unique key, e.g. relative source path)
_managed_markers() {
    _mb_begin="# >>> dotconfigs:$1 >>>"
    _mb_end="# <<< dotconfigs:$1 <<<"
}

# True if `target` contains a block opened by the exact line `begin`.
# Args: begin, target
_has_managed_block() {
    [[ -f "$2" ]] && grep -qFx -- "$1" "$2"
}

# Emit `target` to stdout with the managed block removed, robustly against a
# hand-broken file (markers are `#` comments the user can edit). The rule that
# never loses user content and always re-converges to a single clean block:
#   * a well-formed begin..end pair → dropped (content + both markers);
#   * an UNTERMINATED begin (end missing/altered) → only the begin marker line
#     is dropped; the lines under it are flushed back out, NOT swallowed;
#   * a stray end marker line (no open block) → dropped.
# So marker *lines* are always removed, real content is always kept, and after
# the caller appends one fresh block the file holds exactly one block again.
# Args: target, begin, end
_strip_managed_block() {
    awk -v b="$2" -v e="$3" '
        $0 == b           { if (inblk) printf "%s", buf; inblk = 1; buf = ""; next }
        inblk && $0 == e  { inblk = 0; buf = ""; next }
        inblk             { buf = buf $0 ORS;          next }
        $0 == e           { next }
                          { print }
        END { if (inblk) printf "%s", buf }
    ' "$1"
}

# Render the would-be target for a managed deploy to stdout: target with any
# existing same-keyed block stripped, then a fresh block appended. Guarantees
# exactly one newline before the end marker even if source lacks a trailing one.
# Args: source, target, begin, end
_managed_block_render() {
    local source="$1" target="$2" begin="$3" end="$4"
    [[ -f "$target" ]] && _strip_managed_block "$target" "$begin" "$end"
    printf '%s\n' "$begin"
    cat "$source"
    [[ -n "$(tail -c1 "$source" 2>/dev/null)" ]] && printf '\n'
    printf '%s\n' "$end"
}

# True (0) if a managed deploy would be a no-op (target already current).
# Args: source, target, begin, end
_managed_block_in_sync() {
    local source="$1" target="$2" begin="$3" end="$4"
    [[ -f "$target" ]] || return 1
    local tmp="${target}.managed.$$" rc=0
    _managed_block_render "$source" "$target" "$begin" "$end" > "$tmp" 2>/dev/null \
        || { rm -f "$tmp"; return 1; }
    cmp -s "$tmp" "$target" || rc=1
    rm -f "$tmp"
    return $rc
}

# Sync a managed block into target (atomic tmp+mv). Idempotent.
# Args: source, target, begin, end
# Returns: 0 if target changed, 2 if identical (no-op), 1 on failure.
_managed_block_sync() {
    local source="$1" target="$2" begin="$3" end="$4"
    mkdir -p "$(dirname "$target")"
    local tmp="${target}.managed.$$"
    _managed_block_render "$source" "$target" "$begin" "$end" > "$tmp" 2>/dev/null \
        || { rm -f "$tmp"; return 1; }
    if [[ -f "$target" ]] && cmp -s "$tmp" "$target"; then
        rm -f "$tmp"
        return 2
    fi
    mv "$tmp" "$target"
    return 0
}

# Remove a managed block from target (atomic tmp+mv).
# Args: target, begin, end
# Returns: 0 if removed, 2 if no block present, 1 on failure.
_managed_block_remove() {
    local target="$1" begin="$2" end="$3"
    _has_managed_block "$begin" "$target" || return 2
    local tmp="${target}.managed.$$"
    _strip_managed_block "$target" "$begin" "$end" > "$tmp" 2>/dev/null \
        || { rm -f "$tmp"; return 1; }
    mv "$tmp" "$target"
    return 0
}

# Build a single merged catalogue from every plugin's manifest.json:
#   { "<plugin>": { "<category>": { "<name>": { source, method, target, ... } } } }
# Args: plugins_dir
_merged_manifest() {
    local plugins_dir="$1" merged="{}" d name
    for d in "$plugins_dir"/*/; do
        [[ -f "${d}manifest.json" ]] || continue
        name=$(basename "$d")
        merged=$(jq --arg n "$name" --slurpfile mf "${d}manifest.json" '.[$n] = $mf[0]' <<<"$merged") || return 1
    done
    printf '%s' "$merged"
}

# Resolve the deployment plan for a scope: join the merged catalogue with the
# selection (deploy.json) and emit one TSV row per (item, scope-matching target):
#   enabled<TAB>source<TAB>target<TAB>method<TAB>label
# label is "<plugin>/<category>/<name>". Scope is "machine" (~/absolute targets)
# or "project" (relative targets). enabled is the deploy.json bool (false when
# the item is absent from the selection).
# Args: plugins_dir, deploy_json, scope
resolve_plan() {
    local plugins_dir="$1" deploy_json="$2" scope="$3"
    local merged sel
    merged=$(_merged_manifest "$plugins_dir") || return 1
    sel="{}"; [[ -f "$deploy_json" ]] && sel=$(cat "$deploy_json")
    jq -rn --argjson m "$merged" --argjson sel "$sel" --arg scope "$scope" '
        $m | to_entries[] as $p
        | $p.value | to_entries[] as $c
        | $c.value | to_entries[] as $i
        | $i.value as $e
        | ($e.target | if type=="array" then . else [.] end)[] as $t
        | (if ($t | test("^[~/]")) then "machine" else "project" end) as $ts
        | select($ts == $scope)
        # The on-disk selection may nest per-check toggles under a hook as
        # {enabled, checks}. Collapse to the bare `enabled` bool here so the
        # @tsv row never carries an object (which would abort the whole walk and
        # silently truncate the plan). Bare-bool entries pass through unchanged.
        | ($sel[$p.key][$c.key][$i.key]) as $v
        | ((if ($v | type) == "object" then $v.enabled else $v end) // false) as $en
        | [$en, $e.source, $t, $e.method, "\($p.key)/\($c.key)/\($i.key)"] | @tsv
    ' 2>/dev/null || true
}

# Emit one "<hook>\t<check>\t<enabled-bool>" row per check that any catalogued
# item declares, resolving the on/off value from the selection's nested
# `checks` (falling back to the check's manifest `default`, else on). Shared by
# the materialise and unmaterialise passes. Args: plugins_dir, deploy_json
_hook_check_rows() {
    local plugins_dir="$1" deploy_json="$2" merged sel
    merged=$(_merged_manifest "$plugins_dir") || return 0
    sel="{}"; [[ -f "$deploy_json" ]] && sel=$(cat "$deploy_json")
    jq -rn --argjson m "$merged" --argjson sel "$sel" '
        $m | to_entries[] as $p
        | $p.value | to_entries[] as $c
        | $c.value | to_entries[] as $i
        | ($i.value.checks // {}) | to_entries[] as $ck
        # A hook selection value may be a bare bool (legacy / all-defaults) or
        # absent; only read nested check overrides when it is an object, else
        # fall back to the manifest default. Indexing .checks on a bool would
        # abort the whole jq stream and truncate the materialisation.
        | ($sel[$p.key][$c.key][$i.key]) as $hv
        | (if ($hv | type) == "object" then $hv.checks[$ck.key] else null end) as $ov
        | (if $ov == null then ($ck.value.default // true) else $ov end) as $on
        | [$i.key, $ck.key, ($on | tostring)] | @tsv
    ' 2>/dev/null || true
}

# Materialise per-check toggles into git config so the deployed hook dispatchers
# can read them at commit time: `git config --global dotconfigs.<hook>.<check>`.
# Machine scope only — the toggles are global, mirroring the global git-template
# hooks. A missing key means "on" (the dispatcher's default), so this only needs
# to write the values; disabled checks are written as `false`. Args: plugins_dir,
# deploy_json, dry_run
materialise_hook_checks() {
    local plugins_dir="$1" deploy_json="$2" dry_run="${3:-false}"
    local rows hook check val n=0
    rows=$(_hook_check_rows "$plugins_dir" "$deploy_json")
    [[ -z "$rows" ]] && return 0
    while IFS=$'\t' read -r hook check val; do
        [[ -z "$hook" ]] && continue
        if [[ "$dry_run" == "true" ]]; then
            echo "  Would set: dotconfigs.$hook.$check = $val"
        else
            git config --global "dotconfigs.$hook.$check" "$val"
        fi
        n=$((n + 1))
    done <<< "$rows"
    [[ "$dry_run" != "true" && "$n" -gt 0 ]] && echo "  Hook checks materialised: $n"
    return 0
}

# Remove every materialised per-check toggle from git config (inverse of
# materialise_hook_checks), so the dispatchers fall back to their default-on
# behaviour. Args: plugins_dir, deploy_json, dry_run
unmaterialise_hook_checks() {
    local plugins_dir="$1" deploy_json="$2" dry_run="${3:-false}"
    local rows hook check val seen=" "
    rows=$(_hook_check_rows "$plugins_dir" "$deploy_json")
    [[ -z "$rows" ]] && return 0
    while IFS=$'\t' read -r hook check _; do
        [[ -z "$hook" ]] && continue
        if [[ "$dry_run" == "true" ]]; then
            echo "  Would unset: dotconfigs.$hook.$check"
        else
            git config --global --unset "dotconfigs.$hook.$check" 2>/dev/null || true
            # Drop the now-empty [dotconfigs "<hook>"] section once per hook.
            if [[ "$seen" != *" $hook "* ]]; then
                git config --global --remove-section "dotconfigs.$hook" 2>/dev/null || true
                seen="$seen$hook "
            fi
        fi
    done <<< "$rows"
    return 0
}

# Synthesise the Claude settings `hooks` block from the enabled, wired Claude
# hooks. Inverse of the old static block: each selected hook contributes its
# `wiring` (one object or an array of them); entries are grouped by event then
# matcher, exactly the shape ~/.claude/settings.json expects. The command is the
# hook's own machine target. Echoes the hooks object ({} if none).
# True if this item's deployed source is synthesised at deploy time: the Claude
# settings.json, whose `hooks` block we generate from the selected hooks. Deploy
# injects that block; undeploy strips it — both gate on this one predicate so the
# two sides can never drift. Args: label (plugin/category/name)
_is_synthesised_settings() {
    [[ "$1" == "claude/config/settings" ]]
}

# Args: plugins_dir, deploy_json
synthesise_claude_hooks() {
    local plugins_dir="$1" deploy_json="$2"
    local cm="$plugins_dir/claude/manifest.json" sel="{}"
    [[ -f "$cm" ]] || { printf '{}'; return; }
    [[ -f "$deploy_json" ]] && sel=$(cat "$deploy_json")
    jq -n --slurpfile mf "$cm" --argjson sel "$sel" '
        ($sel.claude.hooks // {}) as $hsel
        | [ $mf[0].hooks | to_entries[]
            | .key as $name | .value as $e
            | select($e.wiring != null and ($hsel[$name] == true))
            | ($e.wiring | if type=="array" then . else [.] end)[]
            | . + { command: $e.target } ]
        | group_by(.event)
        | map({ key: .[0].event,
                value: ( group_by(.matcher | tostring)
                         | map( (.[0].matcher) as $m
                                | { hooks: map( { type: "command" }
                                              + (if .if != null then { if: .if } else {} end)
                                              + { command: .command }
                                              + (if .timeout != null then { timeout: .timeout } else {} end) ) }
                                  + (if $m != null then { matcher: $m } else {} end) ) ) })
        | from_entries
    '
}

# Write a temp copy of the Claude settings source with the synthesised `hooks`
# block injected. Echoes the temp path (caller removes it). If no hooks are
# selected, the source is copied through unchanged.
# Args: plugins_dir, deploy_json, settings_src (abs path)
_synthesise_settings_source() {
    local plugins_dir="$1" deploy_json="$2" settings_src="$3"
    local hooks tmp
    hooks=$(synthesise_claude_hooks "$plugins_dir" "$deploy_json")
    [[ -z "$hooks" ]] && hooks='{}'
    tmp=$(mktemp "${TMPDIR:-/tmp}/dotconfigs-settings.XXXXXX")
    # Always set .hooks (even to {}) so the merge OVERWRITES any previously
    # deployed wiring: deselecting every hook must clear the block, not leave a
    # stale one behind (the merge keeps target keys the source omits).
    jq --argjson h "$hooks" '.hooks = $h' "$settings_src" > "$tmp"
    printf '%s' "$tmp"
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

# Sweep every symlink target dir in a plan for dotconfigs-owned stale/broken
# symlinks (catalogue-deleted orphans and broken-into-repo links), preserving
# foreign files/symlinks and any still-catalogued item. Shared by `deploy` (so a
# deploy is a full reconcile, like `stow -R` / `chezmoi apply`) and `cleanup`.
# Args: plan, project_root, dotconfigs_root, dry_run. Accumulates into `removed`.
_sweep_stale_symlinks() {
    local plan="$1" project_root="$2" dotconfigs_root="$3" dry_run="$4"
    local rows enabled source target method label t dir csv
    rows=$(
        while IFS=$'\t' read -r enabled source target method label; do
            [[ "$method" == "symlink" ]] || continue
            t=$(resolve_target "$target" "$project_root")
            printf '%s\t%s\n' "$(dirname "$t")" "$(basename "$t")"
        done <<< "$plan"
    )
    [[ -z "$rows" ]] && return 0
    while IFS= read -r dir; do
        [[ -z "$dir" ]] && continue
        csv=$(awk -F'\t' -v d="$dir" '$1==d{printf "%s%s",sep,$2; sep=","}' <<< "$rows")
        cleanup_stale_in_directory "$dir" "$csv" "$dotconfigs_root" "$dry_run"
    done < <(cut -f1 <<< "$rows" | sort -u)
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
    backup_and_link "$src" "$tgt" "$name" "$mode" "$root"
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
        | (if ($base | has("hooks")) then .hooks = $base.hooks else . end)
    ' "$target" "$source" > "$tmp" 2>/dev/null; then
        echo "$tmp"
        return 0
    fi
    rm -f "$tmp"
    return 1
}

# Warn when a deploy is about to clobber a live edit. The merge keeps the
# plugin source as the winner on every managed key except the unioned
# permissions arrays, so a top-level key whose deployed value differs from the
# source value will be silently overwritten on the next deploy. This is exactly
# the "/update-config edited ~/.claude/settings.json, dotconfigs deploy reverts
# it" footgun — surface it as a warning so the user ports the change back into
# the plugin source. Top-level keys only (the merge is shallow except for
# permissions); `.permissions` is excluded since it's unioned, not overwritten.
# Args: source (substituted), target. Tallies into caller's `warnings`.
_warn_merge_collisions() {
    local source="$1" target="$2"
    [[ -f "$target" && ! -L "$target" ]] || return 0
    local collisions
    collisions=$(jq -rn --slurpfile s "$source" --slurpfile t "$target" '
        ($s[0] // {}) as $src | ($t[0] // {}) as $tgt
        | $src | keys[] as $k
        | select($k != "permissions")
        | select(($tgt | has($k)) and ($tgt[$k] != $src[$k]))
        | $k
    ' 2>/dev/null)
    [[ -z "$collisions" ]] && return 0
    local key
    while IFS= read -r key; do
        [[ -z "$key" ]] && continue
        printf "  %b! merge-collision: '%s' differs in %s; deploy will overwrite the live value with the plugin source%b\n" \
            "${COLOUR_YELLOW:-}" "$key" "$(basename "$target")" "${COLOUR_RESET:-}" >&2
        if [[ -n "${warnings+x}" ]]; then warnings=$(( warnings + 1 )); fi
    done <<< "$collisions"
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
    # --includes so an identity set in an included file (e.g. our gitconfig-base)
    # is honoured; plain --global misses includes and would force the fallback.
    name=$(git config --global --includes user.name 2>/dev/null)
    email=$(git config --global --includes user.email 2>/dev/null)
    # Then the instance .env (DOTCONFIGS_AUTHOR_*, sourced by the entry point),
    # before the hardcoded last-resort default.
    [[ -z "$name" ]] && name="${DOTCONFIGS_AUTHOR_NAME:-}"
    [[ -z "$email" ]] && email="${DOTCONFIGS_AUTHOR_EMAIL:-}"
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

    # First deploy, or a stale symlink target (nothing local to preserve): start
    # from an empty object and fall through to the merge, so the first deploy
    # yields the same canonical (jq-normalised, permission-unioned) form a
    # re-deploy would -- deploy is then idempotent from run one.
    if [[ ! -e "$target" || -L "$target" ]]; then
        rm -f "$target"
        mkdir -p "$(dirname "$target")"
        printf '{}\n' > "$target"
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
# Args: source, target, method, dotconfigs_root, dry_run, interactive_mode
# Returns: status string via global counters
deploy_module() {
    local source="$1"
    local target="$2"
    local method="$3"
    local dotconfigs_root="$4"
    local dry_run="$5"
    local interactive_mode="$6"
    local abs_source
    local abs_target
    local rel_src

    # Expand tilde in target
    abs_target=$(expand_tilde "$target")

    abs_source=$(_abs_source "$source" "$dotconfigs_root")
    # Compute relative source for display
    rel_src="${abs_source#$dotconfigs_root/}"

    # Validate source exists. A missing source is a hard error (fail-loud):
    # a manifest entry pointing at a file that isn't there is a packaging bug,
    # not something to silently skip. Tally into `errors` so the deploy exits
    # non-zero (see deploy_from_json summary).
    if [[ ! -e "$abs_source" ]]; then
        printf "  %b✗ Error: source not found: %s%b\n" "${COLOUR_RED:-}" "$rel_src" "${COLOUR_RESET:-}" >&2
        eval "errors=\$(( \$errors + 1 ))"
        return
    fi

    # Switch on method
    case "$method" in
        symlink)
            # Each item is a single source -> target; link_one handles a file or
            # a directory source identically (one symlink either way).
            link_one "$abs_source" "$abs_target" "$(basename "$abs_target")" "$dotconfigs_root" "$dry_run" "$interactive_mode"
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
            _warn_merge_collisions "$_merge_src" "$abs_target"
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
        managed)
            # Sentinel-delimited managed region: updatable in place, reversible.
            # See _managed_block_sync. Marker key is the relative source path so
            # multiple managed blocks can coexist in one target.
            local _mb_begin _mb_end
            _managed_markers "$rel_src"
            if [[ "$dry_run" == "true" ]]; then
                if _managed_block_in_sync "$abs_source" "$abs_target" "$_mb_begin" "$_mb_end"; then
                    echo "  Unchanged: $rel_src -> $abs_target (managed block current)"
                    eval "unchanged=\$(( \$unchanged + 1 ))"
                elif _has_managed_block "$_mb_begin" "$abs_target"; then
                    echo "  Would update managed block: $rel_src -> $abs_target"
                    eval "updated=\$(( \$updated + 1 ))"
                else
                    echo "  Would write managed block: $rel_src -> $abs_target"
                    eval "created=\$(( \$created + 1 ))"
                fi
            else
                local _had_block=false
                _has_managed_block "$_mb_begin" "$abs_target" && _had_block=true
                local _rc=0
                _managed_block_sync "$abs_source" "$abs_target" "$_mb_begin" "$_mb_end" || _rc=$?
                case $_rc in
                    0)
                        if [[ "$_had_block" == "true" ]]; then
                            echo "  ✓ Updated managed block $rel_src -> $abs_target"
                            eval "updated=\$(( \$updated + 1 ))"
                        else
                            echo "  ✓ Wrote managed block $rel_src -> $abs_target"
                            eval "created=\$(( \$created + 1 ))"
                        fi
                        ;;
                    2)
                        echo "  Unchanged: $rel_src -> $abs_target (managed block current)"
                        eval "unchanged=\$(( \$unchanged + 1 ))"
                        ;;
                    *)
                        echo "  ! Managed sync failed for $abs_target; left unchanged" >&2
                        eval "skipped=\$(( \$skipped + 1 ))"
                        ;;
                esac
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
# Args: source, target, method, dotconfigs_root
check_module_state() {
    local source="$1"
    local target="$2"
    local method="$3"
    local dotconfigs_root="$4"
    local abs_source abs_target rel_src

    abs_source=$(_abs_source "$source" "$dotconfigs_root")
    abs_target=$(expand_tilde "$target")
    rel_src="${abs_source#"$dotconfigs_root/"}"

    if [[ ! -e "$abs_source" ]]; then
        printf "%s\t%s\n" "not-deployed" "$rel_src (source missing)"
        return 0
    fi

    case "$method" in
        symlink)
            local state
            state=$(check_file_state "$abs_target" "$abs_source" "$dotconfigs_root")
            printf "%s\t%s\n" "$state" "$rel_src"
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
        managed)
            # Deployed iff the managed block is present and current (a stale
            # block reads as not-deployed since `deploy` can auto-update it).
            local _mb_begin _mb_end
            _managed_markers "$rel_src"
            if _managed_block_in_sync "$abs_source" "$abs_target" "$_mb_begin" "$_mb_end"; then
                printf "%s\t%s\n" "deployed" "$rel_src"
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

# Print an error and return 1 if the machine selection file is missing.
# Relies on the caller-scoped $DEPLOY_CONFIG (set in the entry point).
_require_deploy_config() {
    if [[ ! -f "$DEPLOY_CONFIG" ]]; then
        echo "Error: $DEPLOY_CONFIG not found. Run 'dotconfigs init' first." >&2
        return 1
    fi
}

# Emit per-file "<state>\t<name>" lines for a plugin's enabled machine items.
# Takes a pre-resolved machine plan so the caller resolves it once for all plugins.
# Args: plugin, plan (resolve_plan output)
_collect_plugin_states() {
    local plugin="$1" plan="$2"
    printf '%s\n' "$plan" \
        | while IFS=$'\t' read -r enabled source target method label; do
            [[ "$enabled" == "true" ]] || continue
            [[ "$label" == "$plugin/"* ]] || continue
            check_module_state "$source" "$target" "$method" "$REPO_ROOT"
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
# - symlink:  remove the dotconfigs-owned symlink (foreign files preserved)
# - managed:  remove just our sentinel-delimited block (reversible); else unchanged
# - merge:    not safely reversible (target may carry local additions); warn+skip
# - append:   not safely reversible (appended lines may interleave); warn+skip
# Counters used: removed, skipped, unchanged
# Args: source, target, method, dotconfigs_root, dry_run
undeploy_module() {
    local source="$1"
    local target="$2"
    local method="$3"
    local dotconfigs_root="$4"
    local dry_run="$5"
    local abs_source abs_target rel_src

    abs_target=$(expand_tilde "$target")
    abs_source=$(_abs_source "$source" "$dotconfigs_root")
    rel_src="${abs_source#$dotconfigs_root/}"

    case "$method" in
        symlink)
            _undeploy_symlink "$abs_target" "$dotconfigs_root" "$dry_run" "$rel_src"
            ;;
        managed)
            # Reversible (unlike merge/append): strip just our sentinel block,
            # leaving any user lines in the file intact.
            local _mb_begin _mb_end
            _managed_markers "$rel_src"
            if [[ ! -e "$abs_target" ]] || ! _has_managed_block "$_mb_begin" "$abs_target"; then
                eval "unchanged=\$(( \$unchanged + 1 ))"
            elif [[ "$dry_run" == "true" ]]; then
                echo "  Would remove managed block: $abs_target"
                eval "removed=\$(( \$removed + 1 ))"
            elif _managed_block_remove "$abs_target" "$_mb_begin" "$_mb_end"; then
                echo "  ✓ Removed managed block: $abs_target"
                eval "removed=\$(( \$removed + 1 ))"
            else
                echo "  - Skipped (managed removal failed): $abs_target"
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

# Strip the dotconfigs-synthesised `hooks` block from a deployed Claude
# settings.json on undeploy. That block is generated entirely by us (hooks are
# authoritative at deploy time), so removing it is safe and reversible, while the
# rest of the file — the user's own settings — is left untouched. This is why the
# settings item is handled here instead of falling through to the merge-skip path.
# Args: abs_target, dry_run
_undeploy_synthesised_hooks() {
    local tgt="$1" dry="$2"
    if [[ ! -f "$tgt" ]] || ! jq -e '(.hooks // {}) | length > 0' "$tgt" >/dev/null 2>&1; then
        eval "unchanged=\$(( \$unchanged + 1 ))"
        return
    fi
    if [[ "$dry" == "true" ]]; then
        echo "  Would clear synthesised hooks block: $tgt"
        eval "removed=\$(( \$removed + 1 ))"
        return
    fi
    local tmp; tmp=$(mktemp -t "dotconfigs.undeploy.XXXXXX")
    if jq 'del(.hooks)' "$tgt" > "$tmp" 2>/dev/null; then
        mv "$tmp" "$tgt"
        echo "  ✓ Cleared synthesised hooks block: $tgt"
        eval "removed=\$(( \$removed + 1 ))"
    else
        rm -f "$tmp"
        echo "  - Skipped (could not edit settings): $tgt"
        eval "skipped=\$(( \$skipped + 1 ))"
    fi
}

# Walk a config and undeploy every module. Mirror of deploy_from_json.
# Args: plugins_dir, deploy_json, scope, dotconfigs_root, [dry_run], [project_root]
undeploy_from_json() {
    local plugins_dir="$1"
    local deploy_json="$2"
    local scope="$3"
    local dotconfigs_root="$4"
    local dry_run="${5:-true}"
    local project_root="${6:-}"
    local plan enabled source target method label rtarget

    if ! check_jq; then
        return 1
    fi

    removed=0
    skipped=0
    unchanged=0

    # Undeploy removes every catalogued artefact in scope, regardless of whether
    # it is currently selected, so it works even if deploy.json is gone.
    plan=$(resolve_plan "$plugins_dir" "$deploy_json" "$scope")
    if [[ -z "$plan" ]]; then
        echo "No items found for scope '$scope'"
        return 0
    fi

    if [[ "$dry_run" == "true" ]]; then
        echo "Dry-run mode: no changes will be made"
        echo ""
    fi
    echo "Undeploying ($scope)"
    echo ""

    while IFS=$'\t' read -r enabled source target method label; do
        [[ -z "$source" ]] && continue
        rtarget=$(resolve_target "$target" "$project_root")
        # The Claude settings.json carries a synthesised `hooks` block; strip just
        # that on undeploy (keep the user's other settings) rather than skipping it
        # as an unreversible merge, which would leave hooks wired to removed files.
        if _is_synthesised_settings "$label"; then
            _undeploy_synthesised_hooks "$(expand_tilde "$rtarget")" "$dry_run"
            continue
        fi
        undeploy_module "$source" "$rtarget" "$method" "$dotconfigs_root" "$dry_run"
    done <<< "$plan"

    # Remove materialised per-check toggles (machine scope only), so the
    # dispatchers fall back to their default-on behaviour.
    if [[ "$scope" == "machine" ]]; then
        unmaterialise_hook_checks "$plugins_dir" "$deploy_json" "$dry_run"
    fi

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

# Scan merge-method targets for dangling command references (the statusLine /
# hook-command class of bug). Shared by deploy_from_json (post-deploy) and
# `dotconfigs validate`; takes the already-parsed module rows so neither caller
# re-parses. No-op if refcheck.sh isn't sourced — deploy.sh only soft-depends
# on it, so standalone-sourced callers (and tests) still work.
# Args: plan (TSV rows: enabled<TAB>source<TAB>target<TAB>method<TAB>label), [project_root]
_refcheck_merge_targets() {
    local plan="$1" project_root="${2:-}"
    declare -f refcheck_settings_json >/dev/null 2>&1 || return 0
    local enabled source target method label rc_target
    while IFS=$'\t' read -r enabled source target method label; do
        [[ "$enabled" == "true" && "$method" == "merge" ]] || continue
        rc_target=$(resolve_target "$target" "$project_root")
        refcheck_settings_json "$rc_target" "$(dirname "$rc_target")" || true
    done <<< "$plan"
}

# Main deployment entry point
# Args: plugins_dir, deploy_json, scope, dotconfigs_root, [dry_run], [force], [project_root]
deploy_from_json() {
    local plugins_dir="$1"
    local deploy_json="$2"
    local scope="$3"
    local dotconfigs_root="$4"
    local dry_run="${5:-false}"
    local force="${6:-false}"
    local project_root="${7:-}"
    local interactive_mode plan enabled source target method label rtarget

    if ! check_jq; then
        return 1
    fi
    if [[ ! -f "$deploy_json" ]]; then
        echo "Error: selection file not found: $deploy_json" >&2
        echo "Run 'dotconfigs init${project_root:+ $project_root}' first." >&2
        return 1
    fi

    if [[ "$force" == "true" ]]; then
        interactive_mode="force"
    else
        interactive_mode="true"
    fi

    created=0; updated=0; unchanged=0; skipped=0; removed=0; errors=0; warnings=0

    plan=$(resolve_plan "$plugins_dir" "$deploy_json" "$scope")
    if [[ -z "$plan" ]]; then
        echo "No items found for scope '$scope' in $deploy_json"
        return 0
    fi

    if [[ "$dry_run" == "true" ]]; then
        echo "Dry-run mode: no changes will be made"
        echo ""
    fi
    echo "Deploying ($scope) from $deploy_json"
    echo ""

    # Enabled items are deployed; disabled items are torn down in the same pass
    # so toggling an item off in deploy.json removes its artefact next deploy.
    while IFS=$'\t' read -r enabled source target method label; do
        [[ -z "$source" ]] && continue
        rtarget=$(resolve_target "$target" "$project_root")
        if [[ "$enabled" == "true" ]]; then
            if _is_synthesised_settings "$label"; then
                # The Claude settings fragment carries a hooks block synthesised
                # from the selected, wired hooks (no hand-maintained wiring).
                local _ssrc
                _ssrc=$(_synthesise_settings_source "$plugins_dir" "$deploy_json" "$dotconfigs_root/$source")
                deploy_module "$_ssrc" "$rtarget" "$method" "$dotconfigs_root" "$dry_run" "$interactive_mode"
                rm -f "$_ssrc"
            else
                deploy_module "$source" "$rtarget" "$method" "$dotconfigs_root" "$dry_run" "$interactive_mode"
            fi
        else
            undeploy_module "$source" "$rtarget" "$method" "$dotconfigs_root" "$dry_run"
        fi
    done <<< "$plan"

    # Reconcile: sweep dotconfigs-owned symlinks orphaned by items removed from
    # the catalogue entirely (deselected items were already torn down above), so
    # a deploy converges the target to the catalogue rather than leaking orphans.
    _sweep_stale_symlinks "$plan" "$project_root" "$dotconfigs_root" "$dry_run"

    # Materialise per-check hook toggles into git config (machine scope only —
    # the keys are global, read by the deployed hook dispatchers at commit time).
    if [[ "$scope" == "machine" ]]; then
        materialise_hook_checks "$plugins_dir" "$deploy_json" "$dry_run"
    fi

    # Post-deploy: scan deployed JSON settings targets for dangling command
    # references. Warnings only — never blocks a deploy. Skipped on dry-run.
    if [[ "$dry_run" != "true" ]]; then
        _refcheck_merge_targets "$plan" "$project_root"
    fi

    echo ""
    echo "Deployment summary:"
    echo "  Created:   $created"
    echo "  Updated:   $updated"
    echo "  Unchanged: $unchanged"
    echo "  Removed:   $removed"
    echo "  Skipped:   $skipped"
    if [[ "$warnings" -gt 0 ]]; then
        printf "  %bWarnings:  %s%b\n" "${COLOUR_YELLOW:-}" "$warnings" "${COLOUR_RESET:-}"
    fi
    if [[ "$errors" -gt 0 ]]; then
        printf "  %bErrors:    %s%b\n" "${COLOUR_RED:-}" "$errors" "${COLOUR_RESET:-}"
        echo ""
        printf "%bDeploy completed with %s error(s).%b\n" "${COLOUR_RED:-}" "$errors" "${COLOUR_RESET:-}" >&2
        return 1
    fi
    return 0
}
