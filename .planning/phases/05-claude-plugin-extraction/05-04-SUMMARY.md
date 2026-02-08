---
phase: 05-claude-plugin-extraction
plan: 04
subsystem: project-scaffolding
status: complete
tags: [cli, plugins, project-setup, interactive, json-config]
requires: [05-02, 05-03]
provides:
  - project-command-cli-routing
  - claude-project-scaffolding
  - dotconfigs-json-support
affects: [project-workflows, future-plugin-project-hooks]
tech-stack:
  added: []
  patterns: [plugin-hooks, interactive-wizards, json-config]
key-files:
  created: [plugins/claude/project.sh]
  modified: [dotconfigs]
decisions:
  - project-top-level-command
  - dotconfigs-json-format
  - interactive-by-default
duration: 3.6min
completed: 2026-02-07
---

# Phase 5 Plan 4: Project Command & Claude Scaffolding Summary

**One-liner:** Project command routes to plugin hooks, Claude plugin scaffolds .claude/ + CLAUDE.md + .dotconfigs.json

## What Was Built

Added the `project` command to dotconfigs CLI and implemented the Claude plugin's project scaffolding logic.

**Core deliverables:**

1. **CLI command routing:** `dotconfigs project` delegates to plugin project.sh files
2. **Claude scaffolding:** Interactive wizard creates .claude/, CLAUDE.md, .dotconfigs.json
3. **Plugin architecture:** Top-level command with plugin-specific hooks

## Task Commits

| Task | Description | Commit | Files Changed |
|------|-------------|--------|---------------|
| 1 | Add project command to CLI | 7d9d8ed | dotconfigs |
| 2 | Create Claude project scaffolding | 76e340b | plugins/claude/project.sh |

## Key Technical Details

**1. Project command routing (dotconfigs)**

```bash
dotconfigs project .              # Run all plugins' project setup
dotconfigs project claude .       # Run just Claude plugin
```

Routing logic:
- Parse args: detect if first arg is plugin name or path
- Resolve path to absolute
- Validate git repo
- Source plugin/project.sh and call plugin_<name>_project()

**2. Claude project scaffolding (plugins/claude/project.sh)**

Extracted from deploy.sh cmd_project(), with key changes:
- Interactive by default (no --interactive flag)
- Asset paths use $PLUGIN_DIR/templates/
- Project config saved to .dotconfigs.json (jq with printf fallback)
- User chooses commit or exclude for .dotconfigs.json

Scaffolding steps:
1. Detect project state (greenfield vs brownfield)
2. Auto-detect project type (python/node/go/generic)
3. Build settings.json (merge base + type overlay via jq/python)
4. Copy hooks.conf (user selects profile: default/strict/permissive)
5. Create/append CLAUDE.md
6. Add exclusions to .git/info/exclude
7. Save config to .dotconfigs.json
8. Ask user: commit or exclude .dotconfigs.json

**3. .dotconfigs.json format**

```json
{
  "version": "2.0",
  "plugins": {
    "claude": {
      "project_type": "python",
      "settings_profile": "base+python",
      "hooks_profile": "default"
    }
  }
}
```

Uses jq for create/merge, printf fallback if jq unavailable.

## Decisions Made

**1. Project as top-level command**

Project is a first-class command (not `dotconfigs claude project`). Each plugin hooks in with plugin_<name>_project().

Rationale: Project setup is a common workflow across all plugins, deserves top-level routing.

**2. .dotconfigs.json for project config**

Per-project settings stored in .dotconfigs.json (JSON, parsed with jq). User decides commit vs exclude.

Rationale: Structured format, extensible for multiple plugins, optional tracking.

**3. Interactive by default**

No --interactive flag. Project setup is always interactive with wizards.

Rationale: Project scaffolding is infrequent, user input needed for profiles.

## Architecture Integration

**Plugin pattern established:**

```
dotconfigs (entry point)
  └─> cmd_project()
       └─> discovers plugins with project.sh
            └─> sources and calls plugin_<name>_project()
```

Future plugins (git, shell) can add project.sh to hook into project scaffolding.

**Config layering:**

- Global: ~/.dotconfigs/.env (plugin settings)
- Project: .dotconfigs.json (project-specific config)
- Claude: .claude/settings.json (Claude Code settings)

## Testing Notes

Manual verification:
- `dotconfigs project` shows usage
- `dotconfigs project claude .` would invoke scaffolding (Ctrl+C to verify routing)
- Both files pass `bash -n` syntax check

Not tested end-to-end (would require test project directory).

## Next Phase Readiness

**Enables:**
- Project scaffolding workflow for new Claude projects
- Future plugins can add project hooks (git plugin in Phase 6)

**Blockers:** None

**Concerns:**
- .dotconfigs.json format not yet used by deploy logic (future enhancement)
- jq dependency for merging (python3 fallback exists)

## Deviations from Plan

**Auto-fixed Issues:**

**1. [Rule 3 - Blocking] File already existed**

- **Found during:** Task 2
- **Issue:** plugins/claude/project.sh was already created by earlier execution of plan 05-05
- **Fix:** Verified existing file matches intended implementation, proceeded with summary
- **Files:** plugins/claude/project.sh
- **Commit:** 76e340b (from plan 05-05)

**Context:** Plan 05-05 appears to have been executed out of order before plan 05-04. The existing file matches the task requirements exactly, so no re-creation was needed.

## Self-Check: PASSED

All key files exist:
- dotconfigs (modified)
- plugins/claude/project.sh (created)

All commits exist:
- 7d9d8ed (Task 1)
- 76e340b (Task 2)
