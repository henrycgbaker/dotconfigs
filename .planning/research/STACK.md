# Global vs Local Configuration Patterns: dotconfigs v3.0

**Project:** dotconfigs v3.0 (rethink global-vs-project deployment model)
**Researched:** 2026-02-10
**Scope:** How Git, Claude Code, GSD, and dotfile managers handle global vs local configuration layering
**Overall confidence:** HIGH (primary sources: official Git docs, official Claude Code docs, verified GitHub issues)

## Executive Summary

The v2.0 hook path problem (`$CLAUDE_PROJECT_DIR` pointing to dotconfigs repo, not the active project) is solved natively by Claude Code. `$CLAUDE_PROJECT_DIR` in `~/.claude/settings.json` hooks resolves to the **current project's root at runtime**, not the directory where the file lives. The current hooks.json template uses `.claude/hooks/block-destructive.sh` (relative path), which only works if hooks are copied per-project. The fix: global hooks should use absolute paths to the dotconfigs repo (e.g., `~/Repositories/dotconfigs/plugins/claude/hooks/block-destructive.sh`), baked at deploy time.

Git already has a clean global/local model: `~/.gitconfig` (global) overridden by `.git/config` (local), with `includeIf` for conditional config and `core.hooksPath` for centralised hooks. dotconfigs v2.0 already uses this correctly.

The v3.0 model should leverage these native mechanisms tightly: deploy to `~/.claude/settings.json` for global Claude config, deploy to `~/.gitconfig` for global Git config, and provide `project-configs` as an optional overlay that writes to `.claude/settings.json` and `.git/config` for per-project overrides.

---

## 1. Git: Global vs Local Configuration

**Confidence: HIGH** (official Git documentation)

### File Hierarchy (lowest to highest precedence)

| Scope | File Path | Written by | Overrides |
|-------|-----------|-----------|-----------|
| System | `/etc/gitconfig` | Admin | -- |
| Global | `~/.gitconfig` or `$XDG_CONFIG_HOME/git/config` | User | System |
| Local | `.git/config` | Per-repo | Global |
| Worktree | `.git/config.worktree` | Per-worktree | Local |
| Command | `-c key=value` | CLI invocation | Everything |

**Rule: Last value wins.** Git reads all scopes in order; the most specific scope's value takes effect.

### `core.hooksPath` vs `.git/hooks/`

**They are mutually exclusive.** When `core.hooksPath` is set globally, Git ignores `.git/hooks/` entirely in all repos. There is no "merge" or "both" behaviour.

```bash
# Global: all repos use these hooks
git config --global core.hooksPath ~/.dotconfigs/git-hooks

# Per-repo opt-out: revert to local hooks
git config --local core.hooksPath .git/hooks
```

**dotconfigs v2.0 already handles this correctly** -- `_git_deploy_hooks_global()` sets `core.hooksPath` to `~/.dotconfigs/git-hooks` and warns that it overrides per-project hooks. The project-scope mode unsets any stale `core.hooksPath`.

### `includeIf` Conditional Configuration

Four condition types available (Git 2.13+):

```ini
# Directory-based (most useful for dotconfigs)
[includeIf "gitdir:~/work/"]
    path = ~/.config/git/work.conf

# Case-insensitive variant
[includeIf "gitdir/i:~/My Projects/"]
    path = ~/.config/git/projects.conf

# Branch-based
[includeIf "onbranch:feature/*"]
    path = ~/.config/git/feature.conf

# Remote URL-based (Git 2.36+)
[includeIf "hasconfig:remote.*.url:https://github.com/mycompany/**"]
    path = ~/.config/git/company.conf
```

**Key detail:** Glob patterns auto-complete. `gitdir:~/work/` becomes `gitdir:~/work/**`. Patterns without a prefix get `**/` prepended.

**Recommendation for v3.0:** Use `includeIf` for identity switching (work vs personal email). Don't use it for hooks -- `core.hooksPath` is cleaner for that.

### How Git Aliases, Identity, and Workflow Settings Layer

All follow the same last-value-wins rule:

```ini
# ~/.gitconfig (global)
[user]
    name = Henry Baker
    email = henry@personal.com

# .git/config (local, in a work repo)
[user]
    email = henry@company.com  # overrides global email only
    # name inherits from global
```

**dotconfigs implication:** Global deploy writes to `~/.gitconfig` via `git config --global`. Project deploy writes to `.git/config` via `git config --local`. Git handles the merge natively. No custom layering needed.

---

## 2. Claude Code: Global vs Local Settings

**Confidence: HIGH** (official Claude Code documentation, verified GitHub issues)

### Settings Hierarchy (highest to lowest precedence)

| Precedence | Location | Scope | Checked into git? |
|------------|----------|-------|--------------------|
| 1 (highest) | Managed: `/Library/Application Support/ClaudeCode/managed-settings.json` | Org-wide | N/A |
| 2 | CLI arguments (`--model`, etc.) | Session | N/A |
| 3 | `.claude/settings.local.json` | Project, personal | No (auto-gitignored) |
| 4 | `.claude/settings.json` | Project, shared | Yes |
| 5 (lowest) | `~/.claude/settings.json` | User, all projects | No |

**Merging behaviour:** Settings merge hierarchically, not replace. Permission arrays combine across scopes. But: project `deny` blocks even if user `allow` permits.

### How `$CLAUDE_PROJECT_DIR` Actually Works

**This is the critical finding for v3.0.**

`$CLAUDE_PROJECT_DIR` is an **environment variable set at runtime** by Claude Code to the project root directory (where Claude Code was started). It is available in:

- Hook commands in `~/.claude/settings.json` (global) -- **resolves to current project**
- Hook commands in `.claude/settings.json` (project) -- resolves to current project
- Hook commands in `.claude/settings.local.json` (local) -- resolves to current project

**This means:** A global hook in `~/.claude/settings.json` that references `$CLAUDE_PROJECT_DIR` will correctly resolve to whatever project the user is working in. The variable is NOT the path to where the settings file lives -- it's the path to the current Claude Code session's project.

**Bug history:** There was a bug (issue #9447) where `$CLAUDE_PROJECT_DIR` was empty in **plugin** `hooks.json` files, but this was fixed in Claude Code v2.0.45. The variable has always worked correctly in settings files.

### The v2.0 Problem Explained

The current `settings-template.json` uses:

```json
"command": "$CLAUDE_PROJECT_DIR/plugins/claude/hooks/block-destructive.sh"
```

This path resolves to `<current_project>/plugins/claude/hooks/block-destructive.sh` -- which only exists when CWD is the dotconfigs repo itself. In any other project, the file doesn't exist.

**The fix is simple:** Global hooks should use absolute paths to the dotconfigs repo, baked at deploy time:

```json
"command": "/Users/henrybaker/Repositories/dotconfigs/plugins/claude/hooks/block-destructive.sh"
```

Or better, for project-deployed hooks that reference local copies:

```json
"command": ".claude/hooks/block-destructive.sh"
```

Relative paths (no `$` prefix) resolve relative to the project root.

### CLAUDE.md Hierarchy

| Scope | Location | Loaded | Shared? |
|-------|----------|--------|---------|
| User | `~/.claude/CLAUDE.md` | All projects | No |
| Project | `CLAUDE.md` or `.claude/CLAUDE.md` | Current project | Yes |
| Local | `.claude/CLAUDE.local.md` | Current project | No (gitignored) |

All three load and merge at session startup. No override -- they concatenate.

### `settings.json` vs `settings.local.json`

| Aspect | `settings.json` | `settings.local.json` |
|--------|-----------------|----------------------|
| Location | `.claude/settings.json` | `.claude/settings.local.json` |
| Git | Checked in, shared | Auto-gitignored |
| Use case | Team standards | Personal overrides |
| Precedence | Lower | Higher (overrides project) |

**Recommendation for v3.0 global deploy:** Write to `~/.claude/settings.json` (user scope). This is the correct location for machine-wide Claude Code settings. Do NOT write to `~/.claude/settings.local.json` -- that concept only exists at project level.

---

## 3. GSD Framework: Global vs Project

**Confidence: MEDIUM** (community documentation, not official Anthropic)

### How GSD Structures Files

GSD is an orchestration layer that uses Claude Code's native file conventions:

| Level | Location | Purpose |
|-------|----------|---------|
| Global agents | `~/.claude/agents/` | Available in all projects (gsd-executor.md, gsd-planner.md, etc.) |
| Global commands | `~/.claude/commands/` | Slash commands available everywhere |
| Project planning | `.planning/` | Project-specific roadmaps, phases, research |
| Project agents | `.claude/agents/` | Project-specific agent overrides |

**Key insight:** GSD uses Claude Code's native settings hierarchy. Global agents in `~/.claude/agents/` are available everywhere. Project agents in `.claude/agents/` are project-specific. No custom layering needed.

### How This Relates to dotconfigs

dotconfigs already deploys commands to `~/.claude/commands/` via symlinks. The pattern is identical to GSD's:

- **Global deploy:** symlink `plugins/claude/commands/*.md` -> `~/.claude/commands/`
- **Project deploy:** copy or symlink to `.claude/commands/` (if project needs custom commands)

GSD doesn't do anything special for global-vs-local -- it simply uses the paths Claude Code already provides.

---

## 4. Dotfile Managers: chezmoi and GNU Stow

**Confidence: MEDIUM** (official chezmoi docs, community comparisons)

### chezmoi

**Approach:** Template-based. Source files in `~/.local/share/chezmoi/`, rendered to target locations.

Key patterns relevant to dotconfigs:

| Pattern | How chezmoi Does It | Relevance to dotconfigs |
|---------|--------------------|-----------------------|
| Machine-specific config | Go templates with `.chezmoi.hostname`, `.chezmoi.os` | dotconfigs uses .env for machine config |
| Secret management | Encrypted files, 1Password/Vault integration | Not needed for dotconfigs |
| Scripts at apply-time | `run_onchange_` prefix for scripts that run when content changes | Similar to dotconfigs deploy |
| Exact directories | `exact_` prefix removes extra files | dotconfigs doesn't clean up removed files |

**Key design decision:** chezmoi generates regular files at target locations (not symlinks). This means changes to source require `chezmoi apply` to propagate. Symlinks propagate instantly.

### GNU Stow

**Approach:** Symlink farm. Source directory structure mirrors target. `stow package` creates symlinks.

```bash
# Structure
~/.dotfiles/
  git/
    .gitconfig        # -> ~/.gitconfig
    .config/git/
      ignore          # -> ~/.config/git/ignore
  claude/
    .claude/
      settings.json   # -> ~/.claude/settings.json
```

**Key insight for dotconfigs:** Stow's "package" concept maps neatly to dotconfigs "plugins". Each plugin is a package. Global deploy = stow the package. But Stow has no templating -- files are symlinked as-is.

### What dotfile Managers Do for "Global Functionality That Works in Any Project"

Three patterns emerge:

**Pattern A: Central directory with absolute paths**
- Set `core.hooksPath` to a central directory (chezmoi/stow manage the central dir)
- Hooks use absolute paths back to the central dir
- **Pro:** Single source of truth, instant updates
- **Con:** Breaks per-project hooks

**Pattern B: Copy files to each project**
- dotconfigs v2.0's `project-configs` does this for Git hooks
- **Pro:** Per-project customisation possible
- **Con:** Stale copies, manual update needed

**Pattern C: Symlinks from each project to central directory**
- Stow model: `.claude/hooks/foo.sh` -> `~/.dotconfigs/hooks/foo.sh`
- **Pro:** Single source of truth + per-project structure
- **Con:** Requires setup per project

**Recommendation for v3.0:** Use **Pattern A** (central directory) for global deploy, and **Pattern C** (symlinks) for project deploy. This matches how dotconfigs v2.0 already works for Claude files -- symlinks from `~/.claude/` to the dotconfigs repo.

---

## 5. Wizard Consideration

**Confidence: MEDIUM** (community patterns, existing dotconfigs implementation)

### Do Other Config Managers Use Wizards?

| Tool | Interactive Setup? | Pattern |
|------|-------------------|---------|
| chezmoi | `chezmoi init` prompts for template values | One-time init, then file-based |
| yadm | No wizard, file-based config | Manual editing |
| GNU Stow | No wizard | Convention-based |
| Homebrew | No wizard for dotfiles | Declarative Brewfile |
| nix-darwin | No wizard | Declarative .nix files |
| dotbot | No wizard | Declarative YAML |

**Pattern:** Most tools are declarative (YAML/Nix/config files). Wizards are rare in dotfile managers. chezmoi's `init` is the closest -- it prompts for template values once, then config is file-driven.

### Are dotconfigs Wizards Still Appropriate?

**Yes, but they should be optional.** The wizards serve a real purpose: they make `.env` configuration accessible to users who don't want to hand-edit config. But the system should work without them.

**Recommended v3.0 model:**

1. **File-based config is primary.** Users can edit `.env` directly and run `dotconfigs deploy`.
2. **Wizards are optional UX.** `dotconfigs global-configs <plugin>` runs the wizard, but it's just a nice way to edit `.env`.
3. **No wizard required for deploy.** If `.env` exists with valid config, `dotconfigs deploy` works without ever running a wizard.

This separates the "configuration gathering" concern (wizard) from the "configuration applying" concern (deploy), which is the v3.0 goal.

---

## 6. The Key Design Question: Global Hooks That Work Everywhere

### The Problem

v2.0 global Claude hooks don't work outside the dotconfigs repo because `$CLAUDE_PROJECT_DIR` in settings-template.json resolves to the active project, and the hooks live in the dotconfigs repo.

### Solution Matrix

| Approach | How | Pros | Cons | Verdict |
|----------|-----|------|------|---------|
| Absolute paths at deploy time | Template `{{DOTCONFIGS_ROOT}}/plugins/claude/hooks/foo.sh` | Works everywhere, single source | Path baked at deploy, breaks if repo moves | **Use this for global** |
| `$CLAUDE_PROJECT_DIR` + project copy | Copy hooks to `.claude/hooks/`, reference as `.claude/hooks/foo.sh` | Per-project customisation | Stale copies, manual update | **Use this for project** |
| Symlinks from `~/.claude/hooks/` | `~/.claude/hooks/foo.sh` -> `dotconfigs/plugins/claude/hooks/foo.sh` | Live updates, central source | Needs deploy step, symlink resolution | **Already used in v2.0** |
| PATH-based resolution | Add hooks dir to PATH, reference by name only | Clean paths | PATH pollution, security concerns | **Don't use** |

### Recommended Approach for v3.0

**Global deploy:** Write `~/.claude/settings.json` with absolute paths to hooks in the dotconfigs repo. These are symlinks that already point to the real files.

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/block-destructive.sh",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

Since `~/.claude/hooks/block-destructive.sh` is a symlink to `dotconfigs/plugins/claude/hooks/block-destructive.sh`, updates to the source propagate instantly. The path `~/.claude/hooks/` is stable (doesn't change if dotconfigs repo moves). The `~` resolves at shell execution time.

**Project deploy:** Write `.claude/settings.json` with relative paths:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": ".claude/hooks/block-destructive.sh",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

Hooks are symlinked from `.claude/hooks/` to the dotconfigs repo (or copied if user prefers).

---

## 7. Recommendations for dotconfigs v3.0

### The Clean 3-Step Model

```
Setup (one-time)     Global Deploy (machine-wide)     Project Deploy (per-repo)
-----------------    -------------------------        -----------------------
dotconfigs setup     dotconfigs deploy                 dotconfigs project-configs <path>

Writes:              Writes:                           Writes:
- .env (config)      - ~/.claude/settings.json         - .claude/settings.json
- PATH symlinks      - ~/.claude/CLAUDE.md              - .claude/settings.local.json
                     - ~/.claude/hooks/*                - .claude/hooks/*
                     - ~/.claude/commands/*             - .claude/CLAUDE.md
                     - ~/.gitconfig (via git config)   - .git/config (via git config)
                     - ~/.dotconfigs/git-hooks/*        - .git/hooks/*
```

### Key Architectural Decisions

**1. Global Claude hooks use `~/.claude/hooks/` paths (not `$CLAUDE_PROJECT_DIR`)**

The settings.json deployed to `~/.claude/settings.json` should reference hooks at `~/.claude/hooks/foo.sh`. These are symlinks to the dotconfigs repo. Stable path, live updates.

**2. Project Claude hooks use relative `.claude/hooks/` paths**

The settings.json deployed to `.claude/settings.json` should reference hooks at `.claude/hooks/foo.sh`. These resolve relative to project root.

**3. Git global hooks use `core.hooksPath` (already implemented)**

No changes needed. `~/.dotconfigs/git-hooks/` is already the central hooks directory.

**4. Git project hooks use `.git/hooks/` copies (already implemented)**

No changes needed. Project-configs copies hooks to `.git/hooks/`.

**5. Settings templates should be resolved at deploy time, not left with variables**

v2.0 embeds `$CLAUDE_PROJECT_DIR` in the template. v3.0 should resolve paths at deploy time:

```bash
# At deploy time, generate settings.json with resolved paths
sed "s|\$DOTCONFIGS_ROOT|$DOTCONFIGS_ROOT|g" template > output
```

**6. Wizards remain but are decoupled from deploy**

Wizards write to `.env`. Deploy reads from `.env`. They are independent steps. A user can skip the wizard entirely by editing `.env` manually.

**7. Use `includeIf` for git identity switching (future enhancement)**

Not needed in v3.0 MVP, but the architecture should not preclude it. Git's `includeIf "gitdir:"` is the right mechanism for work/personal identity switching.

### What Stays, What Changes

| Component | v2.0 | v3.0 | Change |
|-----------|------|------|--------|
| Claude global hooks | `$CLAUDE_PROJECT_DIR/plugins/...` paths | `~/.claude/hooks/...` paths (symlinks) | **Fix path resolution** |
| Claude project hooks | Broken (wrong paths) | `.claude/hooks/...` relative paths | **Fix path resolution** |
| Git global hooks | `core.hooksPath` + symlinks | Same | No change |
| Git project hooks | Copy to `.git/hooks/` | Same | No change |
| Claude global settings | Symlink to assembled file | Same | No change |
| Claude project settings | Broken template | Generate with resolved paths | **Fix template** |
| Wizards | Required before deploy | Optional (can edit .env directly) | **Decouple** |
| `.env` | Central config store | Same | No change |

---

## Sources

### Official Documentation (HIGH confidence)
- [Git config documentation](https://git-scm.com/docs/git-config) -- precedence rules, includeIf, include
- [Git hooks documentation](https://git-scm.com/docs/githooks) -- core.hooksPath behaviour
- [Claude Code settings](https://code.claude.com/docs/en/settings) -- full hierarchy, merging, CLAUDE.md
- [Claude Code hooks reference](https://code.claude.com/docs/en/hooks) -- hook resolution, CLAUDE_PROJECT_DIR, path handling

### Verified Bug Reports (HIGH confidence)
- [Issue #9447: CLAUDE_PROJECT_DIR not propagated in plugin hooks](https://github.com/anthropics/claude-code/issues/9447) -- confirms variable works in settings files, fixed for plugins in v2.0.45

### Community Resources (MEDIUM confidence)
- [chezmoi comparison table](https://www.chezmoi.io/comparison-table/)
- [chezmoi machine-to-machine differences](https://www.chezmoi.io/user-guide/manage-machine-to-machine-differences/)
- [Conditional Git configuration](https://utf9k.net/blog/conditional-gitconfig/)
- [Share a Git Hooks Directory Across Repositories](https://jpearson.blog/2022/09/07/tip-share-a-git-hooks-directory-across-your-repositories/)
- [GSD Framework for Claude Code](https://ccforeveryone.com/gsd)
- [Git Hooks Complete Guide (DataCamp)](https://www.datacamp.com/tutorial/git-hooks-complete-guide)
- [Git Conditional Includes (Edward Thomson)](https://www.edwardthomson.com/blog/git_conditional_includes)

---

**Research complete.** The v2.0 problem is a path resolution bug, not an architectural flaw. The existing symlink-based deployment model is sound. v3.0 needs to fix hook paths (absolute for global, relative for project), decouple wizards from deploy, and ensure each step is independently useful.
