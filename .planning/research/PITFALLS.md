# v3.0 Research: .dotconfigs/ Directory Conventions and CLI Design

**Domain:** Developer tool configuration management (dotconfigs v3.0)
**Researched:** 2026-02-10
**Mode:** Ecosystem + Feasibility
**Overall confidence:** HIGH (based on direct inspection of tool directories, established conventions, and existing codebase analysis)

---

## Executive Summary

The v3.0 milestone moves project config from a single `.dotconfigs.json` file to a `.dotconfigs/` directory, and rethinks the CLI command surface. This research surveys how established developer tools structure their project directories, store config, handle gitignore strategies, and design CLI command surfaces. The findings strongly favour a **single `config.json` inside `.dotconfigs/`** (not per-plugin files), the **entire `.dotconfigs/` directory being git-ignored by default** (personal tool, not team config), and a **minimal 4-command CLI** that maps cleanly to the 3-step conceptual model.

Key insight: dotconfigs is a personal configuration tool, not a team collaboration tool. This distinction drives nearly every design decision -- it means the config directory should be ignored, the CLI should be explicit, and the global config should live inside the dotconfigs repo itself (not `~/.config/`).

---

## 1. Directory Conventions (What Other Tools Do)

### .git/ -- The Reference Standard

Structure observed directly on this machine:
```
.git/
  config          -- single config file (INI format)
  hooks/          -- executable scripts per lifecycle event
  info/           -- metadata (exclude file)
  objects/        -- content-addressed storage
  refs/           -- branch/tag pointers
  HEAD            -- current ref pointer
  description     -- repo description
```

**Pattern:** Single config file + purpose-specific subdirectories. Config is flat (INI), not nested JSON. Everything is functional (no "settings" subdirectory with multiple files). The directory is never committed -- it is entirely local.

### .claude/ -- The Most Relevant Precedent

Structure observed from `~/.claude/` on this machine:
```
~/.claude/
  settings.json       -- main config (symlink to dotconfigs in this case)
  settings.local.json -- personal overrides (not shared)
  CLAUDE.md           -- project instructions
  commands/           -- slash command markdown files
  agents/             -- subagent markdown files
  hooks/              -- hook scripts
```

Project-level `.claude/` follows the same structure. **Pattern:** Single settings file + `*.local.*` for personal overrides + purpose-specific subdirectories for different asset types.

**Key convention:** `settings.json` (shared/team) vs `settings.local.json` (personal, gitignored). This two-file pattern is the closest analogue to what dotconfigs needs.

### .vscode/ -- Minimal Per-Concern Files

```
.vscode/
  settings.json       -- workspace settings
  extensions.json     -- recommended extensions
  launch.json         -- debugger config
  tasks.json          -- task runner config
```

**Pattern:** Multiple files, but each serves a distinct **tooling concern** (editor settings vs debugger vs tasks), not per-plugin. These are small, focused files. The directory is typically committed (team config).

### .idea/ -- XML Explosion (Anti-Pattern)

```
.idea/
  misc.xml
  modules.xml
  workspace.xml       -- personal, gitignored
  vcs.xml
  codeStyles/
  inspectionProfiles/
  ... (many more)
```

**Pattern:** Per-concern XML files + subdirectories. Partially committed, partially ignored. This is widely considered the most confusing gitignore story among developer tools. **Anti-pattern for dotconfigs:** too many files, unclear what to commit, merge conflicts in XML.

### .husky/ -- Minimal Hook Directory

```
.husky/
  pre-commit          -- hook script (executable)
  commit-msg          -- hook script
  _/                  -- internal husky runtime (gitignored)
```

**Pattern:** One file per hook, flat structure, almost no config. Husky sets `core.hooksPath` to `.husky/_/` internally. The hook files themselves are committed. Very minimal.

### Summary of Directory Patterns

| Tool | Config files | Committed? | Pattern |
|------|-------------|------------|---------|
| .git/ | 1 (config) | Never | Single config + functional subdirs |
| .claude/ | 2 (settings.json + settings.local.json) | settings.json: yes, local: no | Main + local override |
| .vscode/ | 3-4 (per concern) | Usually yes | Per-concern files |
| .idea/ | 10+ (per concern) | Partially | Over-split, confusing |
| .husky/ | 1 per hook | Yes | Minimal, functional |

**Recommendation for `.dotconfigs/`:** Follow the `.claude/` pattern -- single `config.json` as the primary file. Do NOT split per-plugin. The `.claude/` precedent is the most relevant because (a) it is the tool dotconfigs primarily manages, and (b) the user is already familiar with its conventions.

---

## 2. Config File Structure Recommendation

### Option A: Single Monolithic config.json (RECOMMENDED)

```json
{
  "version": "3.0",
  "modules": {
    "claude": {
      "enabled": true,
      "deploy_target": "~/.claude",
      "settings": true,
      "hooks": ["block-destructive", "post-tool-format"],
      "commands": ["commit", "pr-review", "squash-merge"],
      "claude_md": {
        "sections": ["communication", "simplicity", "documentation", "git", "code-style"],
        "exclude_method": "git-info-exclude"
      }
    },
    "git": {
      "enabled": true,
      "identity": {
        "name": "Henry Baker",
        "email": "henry@example.com"
      },
      "hooks": {
        "pre-commit": { "enabled": true },
        "commit-msg": { "enabled": true },
        "pre-push": { "enabled": true, "branch_protection": "warn" }
      }
    }
  }
}
```

**Why this wins:**
- **Atomic:** One file to read, one file to write. No partial-state issues.
- **Precedent:** `package.json` stores config for npm, eslint, prettier, jest, etc. all in one file. Users understand this pattern.
- **Discoverability:** Open one file, see everything. No hunting across subdirectories.
- **Simplicity:** Fewer moving parts = fewer bugs. Critical for a bash tool parsing JSON.
- **Diffability:** One file in `git diff` shows all project config changes.
- **.env replacement:** The current flat `.env` maps directly to a single JSON. Less migration complexity.

### Option B: Per-Plugin Files (NOT Recommended)

```
.dotconfigs/
  claude.json
  git.json
```

**Why this loses:**
- **Two plugins do not justify per-plugin files.** This is premature abstraction for a tool with 2 plugins. At 5+ plugins, reconsider.
- **Coordination problems:** If deploying requires reading multiple files, you need merge logic. One file avoids this.
- **`jq` complexity:** Reading one JSON file with `jq` is straightforward. Reading N files and merging is significantly harder in bash.
- **No user expectation:** Nobody expects to open `.dotconfigs/claude.json` separately. They expect one config file.

### Option C: Hybrid (Not Recommended for Now)

One `config.json` + optional per-plugin override files. This is `.claude/settings.json` + `.claude/settings.local.json` scaled up. Adds complexity without clear benefit at 2 plugins. Could be a v4.0 evolution if plugin count grows.

### jq Dependency Consideration

Moving from `.env` to JSON requires parsing JSON in bash. Options:

| Approach | Pros | Cons |
|----------|------|------|
| **`jq` (recommended)** | Standard tool, powerful, well-tested | External dependency (not on macOS by default) |
| **Python json module** | Already available on macOS | Slower, heavier subprocess |
| **Pure bash** | No deps | Fragile, limited, maintenance nightmare |

**Recommendation:** Require `jq`. It is the standard JSON tool for shell scripts. Add a check in `dotconfigs setup` that validates `jq` is installed and provides install instructions (`brew install jq` / `apt install jq`). This is the only new dependency and it is worth it.

**Confidence:** HIGH -- based on direct pattern analysis of established tools.

---

## 3. Gitignore Strategy Recommendation

### The Core Question: Is `.dotconfigs/` Personal or Team Config?

This is the most important design decision. Everything flows from it.

**Answer: Personal.** dotconfigs is a personal configuration tool. Reasons:
- It manages *your* Claude settings, *your* git hooks, *your* CLAUDE.md sections
- Team members may use different tools entirely (not everyone uses Claude Code)
- The config contains personal preferences (identity, hook strictness, deploy paths)
- The user explicitly said "deploy adds `.dotconfigs/` to `.git/info/exclude` or `.gitignore` (configurable)"

### Recommendation: Entire `.dotconfigs/` Ignored by Default

```
# Default: add to .git/info/exclude (personal, doesn't pollute .gitignore)
.dotconfigs/
```

**Why `.git/info/exclude` is the right default:**
- `.git/info/exclude` is for personal/machine-specific patterns that don't need sharing
- `.gitignore` is for project-wide patterns all developers agree on
- dotconfigs is personal tooling -- exactly what `info/exclude` is for
- This matches the existing pattern: dotconfigs already adds `CLAUDE.md` and `.claude/` to `info/exclude`

**Why NOT `.gitignore`:**
- Adding `.dotconfigs/` to `.gitignore` implies the team uses dotconfigs
- Other team members would see a gitignore entry for a tool they don't use
- Creates noise in PRs that touch `.gitignore`

**But make it configurable** (as the user stated): some users may want `.gitignore` for team-wide dotconfigs usage. Offer a wizard choice:
1. `.git/info/exclude` (default -- personal, invisible to team)
2. `.gitignore` (team -- visible to team, committed)

**What about committed team config?** If a team wants to share dotconfigs config, that is a future v4.0 concern. For v3.0, the model is personal-only.

**Confidence:** HIGH -- aligns with git documentation, existing dotconfigs patterns, and user's stated requirements.

---

## 4. CLI Command Design Recommendation

### Research: How Established Tools Structure Commands

**git:** `init`, `add`, `commit`, `push`, `pull`, `status`, `diff`, `config`, `log`
- Two-level: `git remote add`, `git config --global`
- `init` is the one-time setup verb
- Day-to-day verbs are short and frequent

**npm:** `init`, `install`, `run`, `test`, `publish`
- Flat command surface
- `init` creates `package.json`

**chezmoi:** `init`, `add`, `edit`, `apply`, `diff`, `status`, `update`, `cd`
- `init` sets up source directory
- `apply` deploys dotfiles to home
- `diff` shows pending changes
- 60+ total commands (too many -- chezmoi is a cautionary tale)

**Key principle from clig.dev:** "Where possible, a CLI should follow patterns that already exist. That's what makes CLIs intuitive and guessable."

### The 3-Step Model Mapped to Commands

The user's conceptual model:
1. **Setup** -- builds manifest of available modules from plugin directories
2. **Global** -- deploys selected modules machine-wide
3. **Project** -- deploys selected modules per-repo

This maps cleanly to 4 commands:

```
dotconfigs setup                    # One-time tool init (PATH, jq check)
dotconfigs global [plugin]          # Configure + deploy global settings
dotconfigs project [plugin] [path]  # Configure + deploy project settings
dotconfigs status [plugin]          # Show what's deployed where
```

### Why Merge Configure + Deploy

The current v2.0 has a split: `global-configs` (wizard) then `deploy` (apply). This two-step model creates friction:
- Users forget to run `deploy` after `global-configs`
- Config sits in `.env` without being applied -- confusing state
- "I changed my settings but nothing happened" is a common complaint pattern

**Recommendation:** Make deploy implicit. `dotconfigs global claude` runs the wizard AND deploys. If you only want to preview, use `--dry-run`.

This follows the chezmoi pattern: `chezmoi edit --apply` is the recommended workflow (edit + apply in one step). It also follows `git commit` pattern (stages and commits aren't separate commands for most users thanks to `git commit -a`).

**But keep `deploy` as an alias** for explicit re-deployment without re-running the wizard:
```
dotconfigs deploy [plugin]          # Re-deploy from existing config (no wizard)
dotconfigs deploy --dry-run         # Preview deployment
```

### Minimal Command Surface (Recommended)

| Command | Purpose | Notes |
|---------|---------|-------|
| `dotconfigs setup` | One-time init | PATH symlinks, jq check, version marker |
| `dotconfigs global [plugin]` | Global config wizard + deploy | Replaces `global-configs` + `deploy` |
| `dotconfigs project [plugin] [path]` | Project config wizard + deploy | Replaces `project-configs` + `project-init` |
| `dotconfigs deploy [plugin]` | Re-deploy from existing config | No wizard, just apply. `--dry-run`, `--force` |
| `dotconfigs status [plugin]` | Show deployment state | Drift detection, deployed vs pending |
| `dotconfigs list` | Show available plugins | Keep from v2.0, simple and useful |
| `dotconfigs help [command]` | Contextual help | Keep from v2.0 |

That is **5 user-facing commands** (setup, global, project, status, list) plus 2 utility commands (deploy, help). `deploy` is the explicit "apply without wizard" escape hatch.

### Commands to Drop or Merge

| v2.0 Command | v3.0 Fate | Reason |
|-------------|-----------|--------|
| `global-configs` | Merged into `global` | Shorter, deploy is implicit |
| `project-configs` / `project-init` | Merged into `project` | One command, no confusion over naming |
| `deploy` (standalone) | Keep as explicit re-deploy | Useful for scripting and CI |

### What About `dotconfigs init`?

`git init` creates `.git/`. Should `dotconfigs init` create `.dotconfigs/`?

**No -- `project` already does this.** Adding `init` creates naming confusion: "Do I run `init` or `project`?" The `project` command creates `.dotconfigs/config.json` as part of its workflow. No need for a separate `init`.

If the user wants a non-interactive scaffolding command (create `.dotconfigs/` with defaults, no wizard), that could be `dotconfigs project --defaults`.

**Confidence:** HIGH for the command structure. The merge of configure+deploy is a strong recommendation based on multiple tool precedents, but could be contentious -- flag for discussion.

---

## 5. Naming Recommendations

### Command Names

| v2.0 | v3.0 Recommendation | Rationale |
|------|---------------------|-----------|
| `global-configs` | `global` | Shorter. "dotconfigs global claude" reads naturally as "configure dotconfigs globally for claude" |
| `project-configs` / `project-init` | `project` | Same pattern. "dotconfigs project claude ." reads naturally |
| `deploy` | `deploy` | Keep. Clear verb, established meaning |
| `setup` | `setup` | Keep. One-time init, established from v2.0 |
| `status` | `status` | Keep. Matches `git status` convention |
| `list` | `list` | Keep. Simple, clear |

### Why `global` and `project` (Nouns) Not `configure` (Verb)

The pattern `dotconfigs global claude` uses **scope as the command** (noun-first). This works because:
- The tool name already contains the verb implication ("dotconfigs" = "configure dotconfigs")
- `global` and `project` are scopes, not ambiguous nouns
- It reads left-to-right: tool -> scope -> target
- Shorter than `dotconfigs configure-global claude` or `dotconfigs global-deploy claude`

Alternative considered: `dotconfigs deploy --global claude` / `dotconfigs deploy --project claude .`
- Rejected: Makes `deploy` the primary verb, but the wizard (configure) is the primary action
- `--global` vs `--project` as flags would prevent positional path argument for project

### The `dots` Alias

v2.0 already has `dots` as a symlink alias. Keep it. `dots global claude` is pleasingly brief.

**Confidence:** MEDIUM -- naming is inherently subjective. The pattern is sound but the user may prefer different verbs. Flag for discussion.

---

## 6. Global Config Location Recommendation

### Where Other Tools Store Global Config

| Tool | Global config location | Pattern |
|------|----------------------|---------|
| git | `~/.gitconfig` | Home directory dotfile |
| Claude Code | `~/.claude/settings.json` | Home directory dotdir |
| npm | `~/.npmrc` | Home directory dotfile |
| chezmoi | `~/.config/chezmoi/chezmoi.toml` | XDG compliant |
| VS Code | `~/Library/Application Support/Code/` | OS-native app data |

### Recommendation: Global Config Lives in the Dotconfigs Repo

```
~/Repositories/dotconfigs/config.json    # Global config
```

**Why the dotconfigs repo itself, not `~/.config/dotconfigs/`:**

1. **It already works this way.** The current `.env` lives in the repo root. Users expect to find config next to the tool.
2. **dotconfigs IS the config repo.** It is not a general-purpose tool installed via package manager -- it is a personal repository of configuration. The config belongs in the repo.
3. **XDG is for installed software.** `~/.config/` is for tools installed system-wide that need user-specific config. dotconfigs is cloned, not installed.
4. **Simplicity.** One location for everything: templates, plugins, config. No hunting across directories.
5. **Backup via git.** The global `config.json` can optionally be committed to the dotconfigs repo (it is personal config, after all). This gives version history for free.

**What about `.env` migration?** The existing `.env` becomes `config.json` in the repo root. Same location, different format.

**What about the project-level config?** That goes in `.dotconfigs/config.json` inside each project repo.

**Summary:**
- Global: `<dotconfigs-repo>/config.json`
- Project: `<project-repo>/.dotconfigs/config.json`

**Confidence:** HIGH -- follows existing pattern, simplest approach, aligns with "lightweight as possible".

---

## 7. Pitfalls to Avoid

### Critical Pitfalls

#### Pitfall 1: Over-Engineering the Directory Structure

**What goes wrong:** Creating `.dotconfigs/plugins/claude/settings.json` + `.dotconfigs/plugins/git/hooks.json` + `.dotconfigs/meta.json` when a single `config.json` would suffice.

**Why it happens:** Developer instinct to "organise" and "prepare for scale". The plugin architecture in the tool itself (source code) does not need to be mirrored in the user-facing config directory.

**Consequences:**
- More files to parse in bash (harder, slower, more bugs)
- Users confused about which file to edit
- Merge/coordination logic needed across files
- Violates "lightweight as possible" principle

**Prevention:** Start with one `config.json`. Only add files when there is a concrete, demonstrated need (rule of three). The `.dotconfigs/` directory should have exactly one file (`config.json`) at v3.0 launch.

**Detection:** If you find yourself writing file-merging logic, you have too many files.

---

#### Pitfall 2: Making the Config Directory Committable by Default

**What goes wrong:** Users accidentally commit `.dotconfigs/` because it was not auto-ignored. Team members see personal config in PRs. Merge conflicts ensue.

**Why it happens:** Forgetting to add the ignore rule during `dotconfigs project`, or assuming users will manually add it.

**Consequences:**
- Personal preferences leaked to team (deploy paths, identity info)
- Merge conflicts on config files
- Team members confused by unfamiliar tool config in repo

**Prevention:**
1. `dotconfigs project` MUST add `.dotconfigs/` to `.git/info/exclude` (or `.gitignore` if user chose that) as part of its workflow -- not optional.
2. Validate the ignore rule exists on every `dotconfigs project` invocation (idempotent).
3. Warn if `.dotconfigs/` is tracked by git (detected via `git ls-files`).

---

#### Pitfall 3: jq Dependency Breaks the "Lightweight" Promise

**What goes wrong:** Moving to JSON config requires `jq`, which is not installed by default on macOS. Users run `dotconfigs setup` and immediately hit "jq: command not found".

**Why it happens:** Bash cannot natively parse JSON. Any JSON-based config requires an external tool.

**Consequences:**
- First-run experience is broken for users without `jq`
- Adds install friction ("I need to install something before I can install something")
- Contradicts "lightweight as possible"

**Prevention:**
1. Check for `jq` in `dotconfigs setup` with clear install instructions.
2. Consider: could the config stay as a simple key=value format (`.env` or INI) for v3.0, deferring JSON to v4.0?
3. If JSON is essential: provide a `scripts/install-jq.sh` helper or use Python's `json` module as fallback (Python is on every macOS).
4. Alternative: use a structured but bash-parseable format. See "INI-style alternative" below.

**INI-style alternative (no jq needed):**
```ini
[dotconfigs]
version=3.0

[claude]
enabled=true
deploy_target=~/.claude
hooks=block-destructive post-tool-format

[git]
enabled=true
hooks.pre-commit=true
hooks.commit-msg=true
```

This keeps bash parsing simple (`source` or `grep/sed`) while adding structure the flat `.env` lacks. Worth serious consideration for "lightweight as possible".

---

#### Pitfall 4: Implicit Deploy Surprising Users

**What goes wrong:** User runs `dotconfigs global claude` expecting just the wizard, but it immediately deploys settings to `~/.claude/`. Unintended side effects.

**Why it happens:** The recommended merge of configure + deploy (Section 4) removes the safety of a separate deploy step.

**Consequences:**
- User overwrites existing config they wanted to keep
- No "I changed my mind" moment between configure and deploy
- Scripted/CI usage harder if deploy is implicit

**Prevention:**
1. Show a confirmation summary before deploying: "These changes will be deployed. Continue? [Y/n]"
2. Always show a `--dry-run` preview before actual deployment in interactive mode.
3. Provide `--no-deploy` flag to run wizard only (configure without deploying).
4. Alternative: keep the two-step model but make `deploy` automatic after `global-configs` with a confirmation prompt.

---

### Moderate Pitfalls

#### Pitfall 5: Migration Path from .env to config.json

**What goes wrong:** Users upgrade from v2.0 to v3.0. Their `.env` exists but `config.json` does not. Tool breaks or ignores existing config.

**Why it happens:** No migration logic between config formats.

**Prevention:**
1. On first v3.0 run, detect `.env` and offer to migrate: "Found v2.0 config (.env). Migrate to v3.0 (config.json)? [Y/n]"
2. Write a `_migrate_env_to_json()` function that maps `.env` keys to JSON structure.
3. Keep `.env` as backup after migration (rename to `.env.v2-backup`).
4. Version the config file: `"version": "3.0"` at the top.

---

#### Pitfall 6: `.dotconfigs/` Name Conflicts

**What goes wrong:** Another tool already uses `.dotconfigs/` in the project, or the name is confused with the tool's own repo directory.

**Why it happens:** `.dotconfigs` is both the tool name and the directory name. Ambiguity.

**Prevention:**
1. Validate on `dotconfigs project` that `.dotconfigs/` does not already exist (or if it does, that it was created by dotconfigs -- check for `config.json` with version field).
2. Consider: should the project directory be `.dotconfigs/` at all? Alternative: `.dotconfigs.d/` or just `.dotconfigs.json` (staying with a single file, no directory).

**Assessment:** The user explicitly wants to move FROM `.dotconfigs.json` TO `.dotconfigs/` directory. The name is intentional. Just validate on creation.

---

#### Pitfall 7: Wizard Compatibility -- v2.0 Wizards Generating v3.0 Config

**What goes wrong:** The user said "existing v2.0 wizards should be compatible -- they may be adapted to generate these config files in v4.0." If v3.0 changes the config format but v2.0 wizards still run, they will write `.env` while v3.0 expects `config.json`.

**Why it happens:** Hybrid state during migration where wizards and config format are out of sync.

**Prevention:**
1. v3.0 should be able to read BOTH `.env` and `config.json`, preferring `config.json` if it exists.
2. Wizards in v3.0 should write to `config.json` only.
3. If a wizard writes `.env` (v2.0 wizard still running), the deploy command should detect this and suggest migration.
4. Or: v3.0 does NOT change the config format at all (keeps `.env`), and only introduces the `.dotconfigs/` directory for project-level config. This is the safest approach for "compatible wizards".

---

#### Pitfall 8: Confusing `global` and `project` Scopes

**What goes wrong:** User runs `dotconfigs global` in a project directory and expects it to configure the project. Or runs `dotconfigs project` and expects global effects.

**Why it happens:** Scope names are abstract. Users think location-first ("I'm in my project, so this must be project config").

**Prevention:**
1. `dotconfigs global` should work from any directory (it always writes to the dotconfigs repo).
2. `dotconfigs project` should require being in a git repo (or specifying a path).
3. Show the scope explicitly in output: "Configuring GLOBAL settings for claude (affects all projects)".
4. Error clearly if user runs `dotconfigs project` outside a git repo.

---

### Minor Pitfalls

#### Pitfall 9: deploy --dry-run Fidelity

**What goes wrong:** Dry-run output says "Would create X" but actual deploy creates Y. Dry-run and real deploy diverge over time.

**Prevention:** Implement dry-run as the same code path with a `dry_run` flag checked at write operations, not as a separate code path. This is already the v2.0 approach -- keep it.

---

#### Pitfall 10: Missing `--force` / `--yes` for Scripted Usage

**What goes wrong:** Users want to run `dotconfigs project --defaults .` in CI or a setup script, but the command requires interactive input.

**Prevention:** Every command that has interactive prompts must accept `--yes` or `--defaults` to skip them. This is essential for automation. `clig.dev` emphasises: "Never require prompts -- always provide flag alternatives for scripting."

---

## 8. Architecture Decision: config.json vs .env -- A Deeper Look

Given the "lightweight as possible" constraint, this deserves more analysis.

### Option A: Keep .env for Global, Use config.json for Project (Hybrid)

```
Global:  ~/Repos/dotconfigs/.env          (unchanged from v2.0)
Project: <repo>/.dotconfigs/config.json   (new in v3.0)
```

**Pros:**
- Zero migration for global config
- Wizards continue writing `.env` unchanged
- Only project config needs JSON (smaller scope)
- No `jq` dependency for global operations

**Cons:**
- Two different formats to maintain
- JSON parsing still needed for project config
- Inconsistency between global and project config

### Option B: config.json for Both (Full Migration)

```
Global:  ~/Repos/dotconfigs/config.json   (replaces .env)
Project: <repo>/.dotconfigs/config.json   (new in v3.0)
```

**Pros:**
- Consistent format everywhere
- JSON supports nesting, arrays, types
- Better tooling (schema validation, IDE support)

**Cons:**
- Migration required for all users
- `jq` dependency added
- Wizard rewrite needed

### Option C: Structured .env (INI-style) for Both

```
Global:  ~/Repos/dotconfigs/.env          (enhanced with sections)
Project: <repo>/.dotconfigs/config        (same format)
```

**Pros:**
- No new dependencies
- Bash-native parsing
- Lightweight

**Cons:**
- Limited structure (no nesting, no arrays)
- Non-standard -- no tooling support
- Doesn't solve the "richer config" problem

### Recommendation

**For v3.0: Option A (Hybrid).** Keep `.env` for global, introduce `config.json` for project only. This minimises disruption and limits the `jq` dependency to project operations only (which are less frequent).

**For v4.0: Option B (Full migration).** Once v3.0 is stable, migrate global to JSON too.

This aligns with "existing v2.0 wizards should be compatible" -- the wizards keep writing `.env`, and only the new project-init code writes JSON.

**Confidence:** MEDIUM -- this is a genuine tradeoff. The user should decide based on how strongly they feel about "lightweight" vs "consistent format".

---

## 9. Roadmap Implications

Based on this research, the suggested v3.0 phase structure:

### Phase 1: .dotconfigs/ Directory Foundation
- Create `.dotconfigs/` directory scaffold
- Define `config.json` schema for project config
- Implement `jq` detection and fallback
- Add `.dotconfigs/` to `.git/info/exclude` logic

### Phase 2: CLI Command Restructure
- Rename `global-configs` to `global`
- Rename `project-configs`/`project-init` to `project`
- Add implicit deploy to `global` and `project`
- Add `--dry-run`, `--no-deploy`, `--defaults` flags
- Deprecate old command names with warnings

### Phase 3: Project Config Migration
- `dotconfigs project` creates `.dotconfigs/config.json`
- Project deploy reads from `config.json`
- Migrate from `.dotconfigs.json` to `.dotconfigs/config.json`
- Validate gitignore/exclude rule on every project invocation

### Phase 4: Polish and Migration
- `.env` to `config.json` migration helper (optional)
- Status command updated for new structure
- Documentation updated
- Deprecation warnings for v2.0 patterns

---

## 10. Open Questions for Discussion

1. **Should `global` run the wizard AND deploy, or keep them separate?** The research recommends merging, but this changes user expectations from v2.0.

2. **Is `jq` an acceptable dependency?** If not, the INI-style format or keeping `.env` for everything are the alternatives.

3. **Should v3.0 change the global config format at all?** The safest path is to only introduce `.dotconfigs/config.json` for projects, leaving global `.env` untouched until v4.0.

4. **Should `.dotconfigs/` contain anything beyond `config.json`?** The research says no for v3.0 -- but future versions might add `.dotconfigs/local.json` for personal overrides if the directory ever becomes committable.

5. **Per-module deploy locations in config.json -- how to specify?** The user said "each module can be deployed to custom locations on a per-module basis." The JSON schema needs a `deploy_target` field per module. What is the default?

---

## Sources

### Tool Directory Conventions
- Direct filesystem inspection of `.git/`, `.claude/`, `.vscode/` on local machine (HIGH confidence)
- [Husky -- Git hooks made easy](https://github.com/typicode/husky) -- .husky/ directory structure
- [JetBrains .idea directory documentation](https://www.jetbrains.com/help/idea/creating-and-managing-projects.html)
- [VS Code user and workspace settings](https://code.visualstudio.com/docs/getstarted/settings)
- [Claude Code settings reference](https://www.eesel.ai/blog/settings-json-claude-code)

### CLI Design
- [Command Line Interface Guidelines (clig.dev)](https://clig.dev/) -- comprehensive CLI design principles
- [The Poetics of CLI Command Names](https://smallstep.com/blog/the-poetics-of-cli-command-names/) -- naming patterns
- [chezmoi command overview](https://www.chezmoi.io/user-guide/command-overview/) -- dotfiles manager CLI surface
- [10 design principles for delightful CLIs](https://www.atlassian.com/blog/it-teams/10-design-principles-for-delightful-clis)

### Gitignore Strategy
- [Understanding .gitignore vs .git/info/exclude](https://www.yopa.page/blog/2024-11-1-understanding-git-ignore-patterns-gitignore-vs-git-info-exclude.html)
- [Git exclude, a handy feature](https://marijkeluttekes.dev/blog/articles/2025/09/03/git-exclude-a-handy-feature-you-might-not-know-about/)
- [git-scm.com gitignore documentation](https://git-scm.com/docs/gitignore)

### Config File Patterns
- [ESLint flat config in monorepo discussion](https://github.com/eslint/eslint/discussions/16960) -- single vs multiple config
- [Use .config to store project configs (Lobsters discussion)](https://lobste.rs/s/wac58n/use_config_store_your_project_configs)
- [The creeping scourge of tooling config files (HN)](https://news.ycombinator.com/item?id=24066748)

### XDG / Global Config
- [XDG Base Directory Specification](https://specifications.freedesktop.org/basedir/latest/)
- [XDG Base Directory - ArchWiki](https://wiki.archlinux.org/title/XDG_Base_Directory)

### Dotfiles Management
- [chezmoi design FAQ](https://www.chezmoi.io/user-guide/frequently-asked-questions/design/)
- [awesome-dotfiles](https://github.com/webpro/awesome-dotfiles) -- dotfiles tool landscape
- [yadm - Yet Another Dotfiles Manager](https://yadm.io/)
