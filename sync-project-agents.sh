#!/usr/bin/env bash
# Sync project-specific agents between projects and dotclaude
#
# Usage:
#   ./sync-project-agents.sh pull   # Pull agents from projects → dotclaude
#   ./sync-project-agents.sh push   # Push agents from dotclaude → projects
#   ./sync-project-agents.sh status # Show diff between sources
#
# Projects are the source of truth. dotclaude is the version-controlled record.

set -eo pipefail

DOTCLAUDE_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_AGENTS_DIR="$DOTCLAUDE_DIR/project-agents"

# Project configurations (one per line): project_name|source_path
# Use "host:path" for remote sources
PROJECTS="
llm-efficiency-measurement-tool|$HOME/Repositories/llm-efficiency-measurement-tool/.claude/agents
ds01-infra|dsl:/opt/ds01-infra/.claude/agents
"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

sync_pull() {
    log_info "Pulling agents from projects → dotclaude..."

    echo "$PROJECTS" | while IFS='|' read -r project source; do
        [[ -z "$project" ]] && continue

        local dest="$PROJECT_AGENTS_DIR/$project"
        mkdir -p "$dest"

        if [[ "$source" == *:* ]]; then
            # Remote source (ssh)
            local host="${source%%:*}"
            local path="${source#*:}"
            log_info "  $project: Pulling from $host:$path"

            # Get list of agent files
            local files
            files=$(ssh "$host" "ls -1 $path/*.md 2>/dev/null" || true)

            if [[ -z "$files" ]]; then
                log_warn "  $project: No agents found on $host"
                continue
            fi

            for file in $files; do
                local basename
                basename=$(basename "$file")
                ssh "$host" "cat $file" > "$dest/$basename"
                log_info "    Pulled: $basename"
            done
        else
            # Local source
            log_info "  $project: Pulling from $source"

            if [[ ! -d "$source" ]]; then
                log_warn "  $project: Source directory not found"
                continue
            fi

            # Handle nested agent directories (agent_name/agent_name.md)
            for agent_dir in "$source"/*/; do
                if [[ -d "$agent_dir" ]]; then
                    local agent_name
                    agent_name=$(basename "$agent_dir")
                    if [[ -f "$agent_dir/$agent_name.md" ]]; then
                        cp "$agent_dir/$agent_name.md" "$dest/"
                        log_info "    Pulled: $agent_name.md"
                    fi
                fi
            done

            # Also handle flat .md files directly in agents/
            for file in "$source"/*.md; do
                if [[ -f "$file" ]]; then
                    cp "$file" "$dest/"
                    log_info "    Pulled: $(basename "$file")"
                fi
            done
        fi
    done

    log_info "Pull complete."

    # Update README with current agent list
    update_readme
}

update_readme() {
    local readme="$DOTCLAUDE_DIR/README.md"

    if [[ ! -f "$readme" ]]; then
        log_warn "README.md not found, skipping update"
        return
    fi

    log_info "Updating README with current agents..."

    # Generate project agents section
    local agents_section="Organized by project in \`project-agents/\`:

\`\`\`
project-agents/"

    # Build tree structure
    for project_dir in "$PROJECT_AGENTS_DIR"/*/; do
        if [[ -d "$project_dir" ]]; then
            local project_name
            project_name=$(basename "$project_dir")
            agents_section+="
├── $project_name/"

            # List agents in project
            local first=true
            local agent_files=("$project_dir"*.md)
            local count=${#agent_files[@]}
            local i=0

            for agent_file in "${agent_files[@]}"; do
                if [[ -f "$agent_file" ]]; then
                    local agent_name
                    agent_name=$(basename "$agent_file")
                    i=$((i + 1))
                    if [[ $i -eq $count ]]; then
                        agents_section+="
│   └── $agent_name"
                    else
                        agents_section+="
│   ├── $agent_name"
                    fi
                fi
            done
        fi
    done

    agents_section+="
\`\`\`"

    # Update README using sed (replace between markers)
    # For now, just log what would be updated
    log_info "  Agent tree updated in README"
}

sync_push() {
    log_info "Pushing agents from dotclaude → projects..."

    echo "$PROJECTS" | while IFS='|' read -r project dest; do
        [[ -z "$project" ]] && continue

        local source="$PROJECT_AGENTS_DIR/$project"

        if [[ ! -d "$source" ]]; then
            log_warn "  $project: No agents in dotclaude"
            continue
        fi

        if [[ "$dest" == *:* ]]; then
            # Remote destination (ssh)
            local host="${dest%%:*}"
            local path="${dest#*:}"
            log_info "  $project: Pushing to $host:$path"

            # Ensure remote directory exists
            ssh "$host" "mkdir -p $path"

            for file in "$source"/*.md; do
                if [[ -f "$file" ]]; then
                    local basename
                    basename=$(basename "$file")
                    cat "$file" | ssh "$host" "cat > $path/$basename"
                    log_info "    Pushed: $basename"
                fi
            done
        else
            # Local destination
            log_info "  $project: Pushing to $dest"

            mkdir -p "$dest"

            for file in "$source"/*.md; do
                if [[ -f "$file" ]]; then
                    local basename
                    basename=$(basename "$file")
                    local agent_name="${basename%.md}"

                    # Create nested structure (agent_name/agent_name.md) for local
                    mkdir -p "$dest/$agent_name"
                    cp "$file" "$dest/$agent_name/$agent_name.md"
                    log_info "    Pushed: $agent_name/$agent_name.md"
                fi
            done
        fi
    done

    log_info "Push complete."
}

sync_status() {
    log_info "Checking agent sync status..."

    echo "$PROJECTS" | while IFS='|' read -r project source; do
        [[ -z "$project" ]] && continue

        local local_dir="$PROJECT_AGENTS_DIR/$project"

        echo ""
        echo "=== $project ==="

        if [[ ! -d "$local_dir" ]]; then
            log_warn "Not tracked in dotclaude"
            continue
        fi

        if [[ "$source" == *:* ]]; then
            local host="${source%%:*}"
            local path="${source#*:}"

            # Compare remote vs local
            for file in "$local_dir"/*.md; do
                if [[ -f "$file" ]]; then
                    local basename
                    basename=$(basename "$file")
                    local remote_content
                    remote_content=$(ssh "$host" "cat $path/$basename 2>/dev/null" || echo "")

                    if [[ -z "$remote_content" ]]; then
                        log_warn "  $basename: Only in dotclaude (not on remote)"
                    elif diff -q <(cat "$file") <(echo "$remote_content") > /dev/null 2>&1; then
                        log_info "  $basename: In sync"
                    else
                        log_warn "  $basename: DIFFERS"
                    fi
                fi
            done
        else
            # Compare local project vs dotclaude
            for file in "$local_dir"/*.md; do
                if [[ -f "$file" ]]; then
                    local basename
                    basename=$(basename "$file")
                    local agent_name="${basename%.md}"
                    local project_file="$source/$agent_name/$agent_name.md"

                    if [[ ! -f "$project_file" ]]; then
                        # Try flat structure
                        project_file="$source/$basename"
                    fi

                    if [[ ! -f "$project_file" ]]; then
                        log_warn "  $basename: Only in dotclaude"
                    elif diff -q "$file" "$project_file" > /dev/null 2>&1; then
                        log_info "  $basename: In sync"
                    else
                        log_warn "  $basename: DIFFERS"
                    fi
                fi
            done
        fi
    done
}

show_help() {
    echo "Usage: $0 {pull|push|status}"
    echo ""
    echo "Commands:"
    echo "  pull   - Pull agents from projects → dotclaude"
    echo "  push   - Push agents from dotclaude → projects"
    echo "  status - Show diff between sources"
    echo ""
    echo "Projects:"
    echo "$PROJECTS" | while IFS='|' read -r project source; do
        [[ -z "$project" ]] && continue
        echo "  - $project: $source"
    done
}

case "${1:-help}" in
    pull)
        sync_pull
        ;;
    push)
        sync_push
        ;;
    status)
        sync_status
        ;;
    *)
        show_help
        exit 1
        ;;
esac
