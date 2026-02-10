# Project Research Summary: dotconfigs v3.0

**Project:** dotconfigs v3.0 -- Global/Local Architecture Rethink
**Domain:** Developer tooling, shell configuration management, dotfiles deployment
**Researched:** 2026-02-10
**Confidence:** HIGH

---

## Executive Summary

The v3.0 milestone is smaller than initially expected. Research across four parallel streams (global/local config patterns, module/manifest architecture, shell configuration management, and .dotconfigs/ directory + CLI design) converges on a single conclusion: **the v2.0 architecture is fundamentally sound; v3.0 is a set of targeted fixes, not a rewrite.** The core problem -- Claude hooks breaking outside the dotconfigs repo -- is a path resolution bug, not an architectural flaw. The fix is to use absolute paths (baked at deploy time) for global hooks and relative paths for project hooks. The symlink-based deployment model, plugin directory structure, and wizard-driven configuration all survive intact.

The recommended v3.0 approach has three prongs. First, **fix hook path resolution** so global Claude hooks work in any project (the blocking bug). Second, **introduce `.dotconfigs/` as the project-level config directory** with a single `config.json` inside it, replacing the flat `.dotconfigs.json` file. Third, **streamline the CLI** by merging `global-configs` into `global` and `project-configs`/`project-init` into `project`, with deploy becoming implicit. The shell plugin (aliases, PATH, env vars) is a separate, additive workstream that does not block the core fixes.

Key risks are: (1) the `jq` dependency needed for JSON config parsing conflicts with the "lightweight as possible" principle -- mitigated by keeping `.env` for global config in v3.0 and only using JSON for project config; (2) merging wizard + deploy into one command could surprise users -- mitigated by a confirmation prompt before deploy; (3) migration from v2.0 `.env` to v3.0 JSON needs to be seamless -- mitigated by a phased approach where global config format stays unchanged. The research is unanimous: do the minimum necessary, leverage the tools' native layering (Git's config hierarchy, Claude Code's settings precedence), and resist the urge to build infrastructure for hypothetical futures.

---

## Key Findings

### From STACK.md: Global vs Local Configuration Patterns

The v2.0 hook path problem has a simple fix. `$CLAUDE_PROJECT_DIR` in `~/.claude/settings.json` resolves to the **current project at runtime**, not the settings file's location. The bug is that `settings-template.json` uses `$CLAUDE_PROJECT_DIR/plugins/claude/hooks/...`, which points to the active project (where the hooks don't exist), not the dotconfigs repo.

**Core recommendations:**
- **Global Claude hooks:** Use absolute paths to `~/.claude/hooks/` (symlinks to dotconfigs repo). Stable path, live updates via symlinks.
- **Project Claude hooks:** Use relative `.claude/hooks/` paths. Resolve relative to project root.
- **Global Git hooks:** `core.hooksPath` to `~/.dotconfigs/git-hooks/` -- already correct in v2.0, no change needed.
- **Project Git hooks:** Copy to `.git/hooks/` -- already correct in v2.0, no change needed.
- **Settings templates:** Resolve paths at deploy time (sed substitution), not left with `$CLAUDE_PROJECT_DIR` variables.
- **Wizards:** Decouple from deploy. Wizards write config; deploy reads config. Independent steps.

**What stays the same:** Git's `~/.gitconfig` + `.git/config` layering, Claude Code's `~/.claude/settings.json` + `.claude/settings.json` layering, symlink-based deployment, `.env` for global config storage.

### From FEATURES.md: Module/Manifest Architecture

The module system needs no new infrastructure. The filesystem IS the manifest -- drop a file in the right directory, it becomes a module. This pattern (used by Vim, Oh My Zsh, GNU Stow) is battle-tested and already implemented via `discover_hooks()`, `discover_skills()`, etc.

**Must have (table stakes):**
- Filesystem-based module discovery (exists, no change)
- Convention-based deploy targets (hooks go to `hooks/`, skills to `commands/` -- already hardcoded)
- Per-module-type scope control (global/project/both) via config
- Config records user choices only, not system facts

**Should have (differentiators):**
- JSON config for project-level settings (`.dotconfigs/config.json`)
- Per-module enable/disable within a type (individual hook toggling)
- Wizard-generates-config pattern (like `npm init` generates `package.json`)

**Defer to v4.0+:**
- Per-module manifest files (over-engineers what filesystem communicates)
- Module dependency resolution (we have ~20 modules, no circular deps)
- Module versioning (git IS the version system)
- Schema validation engine, plugin registry, YAML config option
- Full `.env` to JSON migration for global config

**Anti-features (never build):**
- Central module database, module priority/ordering, nested dependencies
- Per-module `.module.json` metadata files

### From ARCHITECTURE.md: Shell Configuration Management

The shell plugin follows the "sourceable snippet" pattern used by Homebrew, nvm, pyenv, and Starship. It generates numbered files in `~/.dotconfigs/shell/` and injects a single `source` line into `.zshrc`.

**Major components:**
1. **Sourceable directory** (`~/.dotconfigs/shell/`) -- numbered files: `01-path.zsh`, `02-env.zsh`, `03-aliases.zsh`, `04-functions.zsh`
2. **Entry point** (`init.zsh`) -- sources all numbered files in order
3. **`.zshrc` injection** -- one grep-guarded source line, backed up before first modification
4. **Idempotent PATH helper** -- `typeset -U PATH` (zsh-native) + `case ":$PATH:"` guard (POSIX fallback)

**Scope decisions:**
- Manage: aliases, functions, PATH additions, environment variables
- Do NOT manage: prompt/theme, plugin managers, shell options, completions, secrets, system config
- Hook into `.zshrc` (not `.zshenv`) -- runs after macOS `path_helper`, covers all interactive shells
- zsh-primary, POSIX-compatible where free. No bash-specific targeting for MVP.

### From PITFALLS.md: .dotconfigs/ Directory + CLI Design

**Critical pitfalls (prevent these):**

1. **Over-engineering the directory structure.** Start with one `config.json` in `.dotconfigs/`. Do not split per-plugin. If you're writing file-merging logic, you have too many files.

2. **Making `.dotconfigs/` committable by default.** Personal tool config must be git-ignored. Default to `.git/info/exclude` (not `.gitignore`). Validate the ignore rule exists on every `dotconfigs project` invocation.

3. **`jq` dependency breaking first-run experience.** JSON parsing requires `jq`, which is not on macOS by default. Mitigate by keeping `.env` for global (no `jq` needed) and only requiring `jq` for project config. Or use Python's `json` module as fallback.

4. **Implicit deploy surprising users.** If `dotconfigs global` both configures AND deploys, show a confirmation summary before deploying. Provide `--no-deploy` and `--dry-run` flags.

5. **Migration from `.env` to `config.json`.** Detect `.env` on first v3.0 run, offer migration, keep backup. Version the config file (`"version": "3.0"`).

---

## Convergent Recommendations

All four research streams agree on these points:

| Recommendation | Supported by |
|---------------|-------------|
| Fix hook paths (absolute for global, relative for project) | STACK, PITFALLS |
| Filesystem-as-manifest (no manifest files) | FEATURES, PITFALLS |
| Single `config.json` per scope (not per-plugin files) | FEATURES, PITFALLS |
| `.dotconfigs/` ignored via `.git/info/exclude` by default | STACK, PITFALLS |
| Wizards write config, deploy reads config (decoupled) | STACK, FEATURES |
| Convention-based deploy targets (no per-file path config) | FEATURES, ARCHITECTURE |
| Keep `.env` for global config in v3.0, JSON for project only | FEATURES, PITFALLS |
| CLI: `global` replaces `global-configs`, `project` replaces `project-configs` | PITFALLS |
| Shell plugin: sourceable directory pattern, `.zshrc` injection | ARCHITECTURE |
| Do not manage: prompt, shell options, plugin managers | ARCHITECTURE |

---

## Open Questions / Tradeoffs Needing User Decisions

1. **Should `global` merge wizard + deploy, or keep them separate?** Research recommends merging (less friction, follows chezmoi/npm patterns) but with a confirmation prompt. The user may prefer the explicit two-step model from v2.0. **Recommendation:** Merge with confirmation.

2. **Is `jq` an acceptable dependency?** If yes: use JSON for project config. If no: use INI-style or keep `.env` format for everything. Python `json` module is a fallback but adds subprocess overhead. **Recommendation:** Accept `jq`, check in `dotconfigs setup`, provide install instructions.

3. **Should v3.0 change global config format at all?** The safest path keeps `.env` for global and only introduces `config.json` for projects. Full migration to JSON can wait for v4.0. **Recommendation:** Keep `.env` for global in v3.0. This preserves wizard compatibility and avoids `jq` for the most common operations.

4. **Per-module-type scope or per-individual-module scope?** Config schema can support per-type (all hooks share one scope) or per-module (each hook individually). **Recommendation:** Start with per-type. YAGNI.

5. **Should the shell plugin be part of v3.0 or a separate milestone?** It's additive (doesn't block or depend on the core fixes). **Recommendation:** Include as a later phase within v3.0, but don't block the core path fixes on it.

---

## Recommended v3.0 Architecture (Synthesised)

### The 3-Step Conceptual Model

```
Setup (one-time)         Global (machine-wide)            Project (per-repo)
-----------------        -------------------------        -----------------------
dotconfigs setup         dotconfigs global [plugin]        dotconfigs project [plugin] [path]

Validates:               Reads: .env                      Reads: .env (defaults) + wizard
- PATH, jq, deps         Writes:                          Writes:
- version marker         - ~/.claude/settings.json        - .dotconfigs/config.json
                         - ~/.claude/CLAUDE.md            - .claude/settings.json
                         - ~/.claude/hooks/* (symlinks)   - .claude/hooks/* (symlinks)
                         - ~/.claude/commands/* (symlinks) - .git/config
                         - ~/.gitconfig (git config)      - .git/hooks/*
                         - ~/.dotconfigs/git-hooks/*       - .git/info/exclude (.dotconfigs/)
```

### Hook Path Resolution (The Core Fix)

```
Global deploy writes to ~/.claude/settings.json:
  "command": "~/.claude/hooks/block-destructive.sh"
  (symlink -> ~/Repos/dotconfigs/plugins/claude/hooks/block-destructive.sh)

Project deploy writes to .claude/settings.json:
  "command": ".claude/hooks/block-destructive.sh"
  (relative to project root)
```

### CLI Command Surface

| Command | Purpose | Replaces |
|---------|---------|----------|
| `dotconfigs setup` | One-time init (PATH, deps) | `setup` (unchanged) |
| `dotconfigs global [plugin]` | Global wizard + deploy | `global-configs` + `deploy` |
| `dotconfigs project [plugin] [path]` | Project wizard + deploy | `project-configs` + `project-init` |
| `dotconfigs deploy [plugin]` | Re-deploy from existing config | `deploy` (unchanged) |
| `dotconfigs status [plugin]` | Show deployment state | `status` (unchanged) |
| `dotconfigs list` | Show available plugins | `list` (unchanged) |

### Config Locations

| Scope | Location | Format | Notes |
|-------|----------|--------|-------|
| Global | `<dotconfigs-repo>/.env` | Key-value | Unchanged from v2.0 |
| Project | `<project>/.dotconfigs/config.json` | JSON | New in v3.0 |

---

## Implications for Roadmap

### Phase 1: Fix Hook Path Resolution

**Rationale:** This is the blocking bug. Everything else works. Fix it first.
**Delivers:** Global Claude hooks that work in any project, not just the dotconfigs repo.
**Changes:**
- `settings-template.json` uses absolute `~/.claude/hooks/` paths (not `$CLAUDE_PROJECT_DIR`)
- Deploy bakes absolute paths at deploy time via sed substitution
- Project deploy uses relative `.claude/hooks/` paths
**Addresses:** STACK.md core finding, PITFALLS.md Pitfall 1 (path resolution)
**Avoids:** Over-engineering (this is a one-line path fix in the template, not a redesign)
**Research flag:** Standard pattern, no research needed.

### Phase 2: Decouple Wizards from Deploy

**Rationale:** Dependency for all subsequent phases. Wizards must write config without deploying, deploy must read config without re-asking questions.
**Delivers:** Clean separation of configuration-gathering (wizard) and configuration-applying (deploy). `dotconfigs deploy` works without ever running a wizard if config exists.
**Changes:**
- Wizard writes to `.env` (global) or `.dotconfigs/config.json` (project)
- Deploy reads from `.env` / `config.json`
- Wizard is optional -- users can hand-edit config
**Addresses:** STACK.md recommendation 6, FEATURES.md wizard-as-config-generator pattern
**Avoids:** PITFALLS.md Pitfall 4 (implicit deploy surprising users)
**Research flag:** Standard refactoring, no research needed.

### Phase 3: `.dotconfigs/` Directory + Project Config

**Rationale:** Replaces flat `.dotconfigs.json` with a directory that can grow. Foundation for per-project module control.
**Delivers:** `.dotconfigs/config.json` for project-level configuration, auto-ignored via `.git/info/exclude`.
**Changes:**
- `dotconfigs project` creates `.dotconfigs/` directory with `config.json`
- Project deploy reads JSON config (requires `jq`)
- `.dotconfigs/` added to `.git/info/exclude` automatically
- Migration from `.dotconfigs.json` to `.dotconfigs/config.json`
**Addresses:** PITFALLS.md directory conventions, FEATURES.md config schema
**Avoids:** PITFALLS.md Pitfall 1 (over-engineering directory), Pitfall 2 (committable by default), Pitfall 3 (`jq` dependency -- mitigated by only needing `jq` for project ops)
**Research flag:** Needs research on `jq` fallback strategy and JSON schema validation approach.

### Phase 4: CLI Command Restructure

**Rationale:** Simplify the command surface now that wizard and deploy are decoupled.
**Delivers:** Shorter commands (`global`, `project`), implicit deploy with confirmation, `--dry-run`/`--defaults`/`--no-deploy` flags.
**Changes:**
- `global-configs` becomes `global` (deprecation warning on old name)
- `project-configs`/`project-init` becomes `project`
- `global` and `project` run wizard then deploy (with confirmation)
- `deploy` remains as explicit re-deploy without wizard
- `--yes`/`--defaults` for scripted/CI usage
**Addresses:** PITFALLS.md CLI design, PITFALLS.md Pitfall 10 (scripted usage)
**Avoids:** PITFALLS.md Pitfall 4 (implicit deploy -- confirmation prompt), Pitfall 8 (scope confusion -- explicit output messaging)
**Research flag:** Standard CLI refactoring, no research needed.

### Phase 5: Shell Plugin (MVP)

**Rationale:** Additive feature, doesn't block core fixes. Aliases + PATH are the highest-value, lowest-risk shell concerns.
**Delivers:** New `plugins/shell/` plugin with aliases and PATH management. Sourceable directory in `~/.dotconfigs/shell/`, one `.zshrc` injection line.
**Changes:**
- New plugin: `plugins/shell/` with `setup.sh`, `deploy.sh`, templates
- Generates `~/.dotconfigs/shell/{init.zsh, 01-path.zsh, 03-aliases.zsh}`
- Injects grep-guarded source line into `.zshrc`
- Idempotent PATH management (zsh `typeset -U` + POSIX `case` guard)
**Addresses:** ARCHITECTURE.md full scope (Tier 1 only for MVP)
**Avoids:** ARCHITECTURE.md anti-patterns (no .zshrc replacement, no prompt management, no shell options, no plugin manager integration)
**Research flag:** Needs research during planning -- `.zshrc` injection is invasive and must be thoroughly tested. Backup strategy essential.

### Phase 6: Shell Plugin Extended (Post-MVP)

**Rationale:** After aliases + PATH prove stable, add env vars, functions, tool initialisers.
**Delivers:** Environment variable management, shell functions, `eval "$(tool init zsh)"` management.
**Changes:**
- Generate `02-env.zsh`, `04-functions.zsh`, `05-tools.zsh`
- Tool initialiser ordering (must come after PATH setup)
- Platform conditionals (macOS vs Linux)
**Addresses:** ARCHITECTURE.md Tier 2
**Research flag:** Standard patterns, no research needed.

### Phase Ordering Rationale

- **Phase 1 first:** It's the blocking bug. Three lines of change, massive impact.
- **Phase 2 second:** Architectural prerequisite for Phases 3-4. Clean separation enables everything else.
- **Phase 3 before 4:** The project config directory needs to exist before CLI commands reference it.
- **Phase 4 after 3:** CLI changes reference the new config structure.
- **Phases 5-6 last:** Additive, independent. Can be deferred or parallelised without blocking the core v3.0 deliverables.

### Research Flags

**Needs deeper research during planning:**
- **Phase 3:** JSON schema design, `jq` availability/fallback strategy, migration path from `.dotconfigs.json`
- **Phase 5:** `.zshrc` injection safety, backup/restore strategy, interaction with oh-my-zsh/zinit/antidote

**Standard patterns (skip research):**
- **Phase 1:** Simple path fix, well-understood
- **Phase 2:** Standard decoupling refactor
- **Phase 4:** CLI restructuring, established patterns
- **Phase 6:** Extension of proven Phase 5 infrastructure

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack (Global/Local Patterns) | **HIGH** | Official Git docs, official Claude Code docs, verified GitHub issues. `$CLAUDE_PROJECT_DIR` behaviour confirmed. |
| Features (Module/Manifest) | **HIGH** | Patterns well-established across Vim, Oh My Zsh, GNU Stow, npm, Dotbot. Filesystem-as-manifest is battle-tested. |
| Architecture (Shell Config) | **HIGH** | Sourceable snippet pattern used by every major dev tool. macOS path_helper behaviour well-documented. |
| Pitfalls (Directory + CLI) | **HIGH** | Direct filesystem inspection of `.git/`, `.claude/`, `.vscode/`. CLI patterns from clig.dev. |

**Overall confidence:** **HIGH**

The v3.0 scope is well-defined and the changes are smaller than expected. The riskiest area is the shell plugin (Phase 5) because `.zshrc` modification is inherently invasive, but the "single source line" pattern is the industry standard and well-understood.

### Gaps to Address

1. **`jq` dependency strategy.** Research recommends requiring `jq` but acknowledges it's not on macOS by default. Decision: require it, provide install instructions, or use Python `json` as fallback? **Handle during Phase 3 planning.**

2. **JSON schema for `.dotconfigs/config.json`.** FEATURES.md proposes a schema, PITFALLS.md proposes a slightly different one. Need to finalise the canonical schema. **Handle during Phase 3 planning.**

3. **Wizard UX for merged configure+deploy.** The confirmation prompt design (what to show, how to preview) needs prototyping. **Handle during Phase 4 planning.**

4. **v2.0 `.env` to v3.0 `config.json` migration.** Clear that it's needed, but exact key mapping not defined. **Handle during Phase 3 planning.**

5. **Shell plugin interaction with existing setups.** Users with oh-my-zsh, zinit, or Starship -- how does the source line interact? **Handle during Phase 5 planning.**

---

## Sources

### Primary (HIGH confidence)
- [Git config documentation](https://git-scm.com/docs/git-config) -- precedence rules, includeIf
- [Git hooks documentation](https://git-scm.com/docs/githooks) -- core.hooksPath behaviour
- [Claude Code settings](https://code.claude.com/docs/en/settings) -- full hierarchy, merging, CLAUDE.md
- [Claude Code hooks reference](https://code.claude.com/docs/en/hooks) -- hook resolution, CLAUDE_PROJECT_DIR
- [Issue #9447: CLAUDE_PROJECT_DIR not propagated in plugin hooks](https://github.com/anthropics/claude-code/issues/9447) -- confirms variable works in settings files
- [Zsh startup files](https://zsh.sourceforge.io/Intro/intro_3.html) -- official zsh documentation
- [clig.dev](https://clig.dev/) -- CLI design principles
- Direct filesystem inspection of `.git/`, `.claude/`, `.vscode/` on local machine

### Secondary (MEDIUM confidence)
- [Dotbot GitHub](https://github.com/anishathalye/dotbot) -- YAML/JSON config for link targets
- [chezmoi comparison table](https://www.chezmoi.io/comparison-table/) -- dotfile manager patterns
- [GNU Stow Manual](https://www.gnu.org/software/stow/manual/stow.html) -- filesystem mirroring
- [Oh My Zsh Plugins Wiki](https://github.com/ohmyzsh/ohmyzsh/wiki/plugins) -- filesystem convention
- [npm init Documentation](https://docs.npmjs.com/cli/v8/commands/npm-init/) -- wizard generates config
- [Homebrew shellenv source](https://github.com/Homebrew/brew/blob/master/Library/Homebrew/cmd/shellenv.sh) -- idempotent PATH
- [ESLint Flat Config](https://eslint.org/blog/2022/08/new-config-system-part-2/) -- single config patterns
- [Securing Zsh](https://hoop.dev/blog/securing-zsh-how-to-lock-down-your-shell-and-prevent-plugin-based-attacks/) -- security patterns

### Tertiary (LOW confidence)
- Community dotfiles patterns (various GitHub repos)
- INI-style config as `jq` alternative -- proposed but not widely validated in this context
- Shell plugin interaction with oh-my-zsh/zinit -- inferred from documentation, not tested

---
*Research completed: 2026-02-10*
*Ready for roadmap: yes*
