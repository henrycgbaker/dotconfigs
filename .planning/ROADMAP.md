# Roadmap: dotconfigs v3.0

## Overview

Replace the wizard-driven .env deployment model with explicit JSON config. Every module is a source→target pair. The tool is a generic file deployer — it doesn't know about Claude, Git, or VS Code. Wizards deferred to v4.

Phase numbering continues from v2.0 (phases 4-9 complete).

## Config Schema

```jsonc
// global.json — in dotconfigs repo root
//
// "source" paths are ALWAYS relative to the dotconfigs repo root.
// "target" paths are absolute (tilde-expanded) for global.json.
// "method": always specify — "symlink", "copy", or "append". Helps debugging.
// "include" filters files when source is a directory. Omit to deploy all files.
// Top-level keys (claude, git, etc.) are arbitrary labels — the tool just
// finds objects with "source" + "target" and deploys them.
//
// See: global.json (actual config) and project.json.example (reference)
{
  "claude": {
    "hooks": {
      "source": "plugins/claude/hooks",
      "target": "~/.claude/hooks",
      "method": "symlink",
      "include": ["block-destructive.sh", "post-tool-format.py"]
    },
    "settings": {
      "source": "plugins/claude/settings.json",
      "target": "~/.claude/settings.json",
      "method": "symlink"
    },
    "skills": {
      "source": "plugins/claude/commands",
      "target": "~/.claude/commands",
      "method": "symlink",
      "include": ["commit.md", "squash-merge.md", "simplicity-check.md", "pr-review.md"]
    },
    "claude-md": {
      "source": "plugins/claude/CLAUDE.md",
      "target": "~/.claude/CLAUDE.md",
      "method": "symlink"
    }
  },
  "git": {
    "hooks": {
      "source": "plugins/git/hooks",
      "target": "~/.dotconfigs/git-hooks",
      "method": "symlink",
      "include": ["pre-commit", "commit-msg", "prepare-commit-msg", "pre-push"]
    },
    "config": {
      "source": "plugins/git/gitconfig",
      "target": "~/.gitconfig",
      "method": "symlink"
      // Git's native INI format. Direct symlink — no intermediate.
      // `git config --global` writes through the symlink back into the repo.
    },
    "global-excludes": {
      "source": "plugins/git/global-excludes",
      "target": "~/.config/git/ignore",
      "method": "symlink"
      // Referenced by core.excludesFile in gitconfig. Applies to all repos.
    }
  },
  "vscode": {
    "settings": {
      "source": "plugins/vscode/settings.json",
      "target": "~/Library/Application Support/Code/User/settings.json",
      "method": "symlink"
    },
    "keybindings": {
      "source": "plugins/vscode/keybindings.json",
      "target": "~/Library/Application Support/Code/User/keybindings.json",
      "method": "symlink"
    },
    "snippets": {
      "source": "plugins/vscode/snippets",
      "target": "~/Library/Application Support/Code/User/snippets",
      "method": "symlink"
    }
  },
  "shell": {
    "init": {
      "source": "plugins/shell/init.zsh",
      "target": "~/.dotconfigs/shell/init.zsh",
      "method": "symlink"
      // User adds `source ~/.dotconfigs/shell/init.zsh` to ~/.zshrc once.
    },
    "aliases": {
      "source": "plugins/shell/aliases.zsh",
      "target": "~/.dotconfigs/shell/aliases.zsh",
      "method": "symlink"
    }
  }
}

// .dotconfigs/project.json — in each project
//
// Same schema as global.json.
// "source" paths are ALWAYS relative to the dotconfigs repo root (tool resolves).
// "target" paths are relative to the project root (where .dotconfigs/ lives).
// See: project.json.example in repo root for a working example.
{
  "claude": {
    "hooks": {
      "source": "plugins/claude/hooks",
      "target": ".claude/hooks",
      "method": "symlink",
      "include": ["block-destructive.sh"]
    },
    "settings": {
      "source": "plugins/claude/templates/settings/project-template.json",
      "target": ".claude/settings.json",
      "method": "copy"  // copy — project settings are user-editable after first deploy
    }
  },
  "git": {
    "hooks": {
      "source": "plugins/git/hooks",
      "target": ".git/hooks",
      "method": "symlink",
      "include": ["pre-commit", "commit-msg"]
    },
    "exclude-patterns": {
      "source": "plugins/git/project-exclude-patterns",
      "target": ".git/info/exclude",
      "method": "copy"
    },
    "gitignore": {
      "source": "plugins/git/templates/gitignore-default",
      "target": ".gitignore",
      "method": "copy"  // copy — .gitignore is tracked in git and project-specific
    }
  }
}
```

## Phases

- [x] **Phase 10: Hook Path Resolution** — Fix global hooks to use absolute paths
- [ ] **Phase 11: JSON Config + Core Deploy** — global.json schema, deploy reads JSON, gitconfig include file, project deploy
- [ ] **Phase 12: VS Code Plugin + Migration + CLI** — New VS Code plugin, .env→JSON migration, CLI cleanup
- [ ] **Phase 13: Documentation** — README, schema reference, architecture diagram

## Phase Details

### Phase 10: Hook Path Resolution (Complete)
**Goal**: Global Claude hooks work correctly in any project directory
**Status**: Complete (2026-02-10)
**Requirements**: PATH-01, PATH-02, PATH-03

Plans:
- [x] 10-01-PLAN.md — Fix template paths, deploy-time resolution

### Phase 11: JSON Config + Core Deploy
**Goal**: global.json and project.json as the sole configuration mechanism, with deploy reading JSON to symlink files
**Depends on**: Phase 10
**Requirements**: CONF-01..08, DEPL-01..07, PROJ-01..04, GITF-01..04
**Success Criteria** (what must be TRUE):
  1. `global.json` exists in repo root with source→target module definitions
  2. `dotconfigs deploy` reads global.json and symlinks all modules to their targets
  3. `dotconfigs deploy <group>` deploys only modules under that group key
  4. Directory sources deploy each file individually (not directory symlinks)
  5. `--dry-run` and `--force` flags work
  6. `plugins/git/gitconfig` contains identity+workflow+aliases in Git's INI format, symlinked directly to `~/.gitconfig`
  7. `git config --global` commands write through the symlink back into the repo
  8. `.dotconfigs/project.json` per-repo works with `dotconfigs project <path>`
  9. `.dotconfigs/` auto-excluded via `.git/info/exclude`
  10. `jq` dependency checked with clear error message
  11. Existing hook/skill/settings deployments preserved (no functionality loss)
**Plans**: 3 plans

Plans:
- [ ] 11-01-PLAN.md — Generic JSON deploy engine (lib/deploy.sh)
- [ ] 11-02-PLAN.md — CLI deploy rewrite to use global.json
- [ ] 11-03-PLAN.md — Project deploy and project-init commands

### Phase 12: VS Code Plugin + Migration + CLI
**Goal**: Add VS Code config management, migrate from .env, clean up CLI for new model
**Depends on**: Phase 11
**Requirements**: MIGR-01..03, VSCD-01..04, CLI-01..04, SHEL-01..02
**Success Criteria** (what must be TRUE):
  1. `plugins/vscode/` exists with settings.json, keybindings.json, snippets/
  2. VS Code modules in global.json deploy to correct macOS paths
  3. `plugins/vscode/extensions.txt` auto-populated by `dotconfigs setup` via `code --list-extensions`
  4. `plugins/shell/` exists with init.zsh and aliases.zsh
  5. `dotconfigs migrate` converts .env → global.json with backup
  6. Old wizard commands show deprecation messages pointing to global.json
  7. `dotconfigs status` and `dotconfigs list` work with JSON config
  8. Help text reflects new command set
**Plans**: TBD (estimate: 3-4 plans)

### Phase 13: Documentation
**Goal**: Clear docs for new users and reference for the config schema
**Depends on**: Phase 12
**Requirements**: DOC-01..03
**Success Criteria** (what must be TRUE):
  1. README covers: install, first-run, daily usage, adding a new plugin
  2. global.json schema documented with examples
  3. Architecture diagram shows: repo → config → deploy → targets
**Plans**: TBD (estimate: 1-2 plans)

## Progress

**Execution Order:**
Phases execute in numeric order: 10 → 11 → 12 → 13

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 10. Hook Path Resolution | 1/1 | Complete | 2026-02-10 |
| 11. JSON Config + Core Deploy | 0/0 | Not started | - |
| 12. VS Code + Migration + CLI | 0/0 | Not started | - |
| 13. Documentation | 0/0 | Not started | - |
