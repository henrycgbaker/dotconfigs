# Feature Landscape: Module/Manifest Architecture for dotconfigs v3.0

**Domain:** Module-based configuration deployment with manifest/registry patterns
**Researched:** 2026-02-10
**Project:** dotconfigs v3.0 (module architecture milestone)
**Confidence:** HIGH (patterns well-established across many tools)

## Executive Summary

The v3.0 module system needs to answer one question: "What deploys where?" After surveying how Vim, Oh My Zsh, GNU Stow, Dotbot, chezmoi, Homebrew, VSCode, Cargo, and ESLint handle module definition and deployment, the clear winner for dotconfigs is a **hybrid pattern: filesystem-as-manifest for discovery + a single JSON config for user choices and deploy targets**.

The filesystem already defines what modules exist (hooks in `hooks/`, skills in `commands/`, templates in `templates/`). The only thing missing is where each module deploys and whether the user wants it enabled. A JSON config file captures those two things. That is the entire v3.0 system.

**Key insight from research:** Every tool that starts with a manifest file for module *definition* ends up duplicating what the filesystem already says. The tools that work best (GNU Stow, Oh My Zsh, Vim's native packages) let the filesystem define what exists and use a separate, minimal config for user preferences. Dotbot is the gold standard for the "config file specifies deploy targets" pattern -- its `install.conf.yaml` is just a mapping of `destination: source`.

**Second key insight:** The scope problem (global vs project) is not a module metadata problem -- it is a deployment config problem. A module does not inherently "belong" to global or project scope. The user decides where to deploy it. The config records that decision.

---

## 1. Module Definition Patterns (Ranked by Simplicity)

How does a module say "I exist and here is what I provide"?

### Pattern A: Filesystem Convention (RECOMMENDED)

**Used by:** Vim native packages, Oh My Zsh, GNU Stow, Cargo (auto-discovery)
**How it works:** The filesystem structure IS the module definition. No manifest file needed.

```
plugins/claude/
  hooks/                    # Module type: hook
    block-destructive.sh    # One module
    post-tool-format.py     # Another module
  commands/                 # Module type: skill
    commit.md
    pr-review.md
  templates/                # Module type: template
    claude-md/
      01-communication.md
      02-simplicity.md
    settings/
      base.json
      hooks.json
```

**Vim parallel:** Vim doesn't need a manifest to know a plugin provides syntax highlighting -- if there is a `syntax/` directory, it provides syntax highlighting. The directory name IS the declaration.

**Oh My Zsh parallel:** A plugin exists if `$ZSH/plugins/{name}/{name}.plugin.zsh` exists. Discovery is: scan `plugins/` for directories containing a `.plugin.zsh` file. The user's `.zshrc` `plugins=(...)` array is the config, not the manifest.

**GNU Stow parallel:** Each "package" (subdirectory) defines what it provides by its directory structure. The directory layout mirrors the target filesystem. No manifest.

**Verdict for dotconfigs:** This is what we already do. `discover_hooks()` scans `plugins/{name}/hooks/` for `*.sh` and `*.py` files. `discover_skills()` scans `commands/` for `*.md`. The filesystem IS the manifest. v3.0 should formalise this convention, not replace it.

**Confidence:** HIGH -- this pattern is the most battle-tested and the simplest.

### Pattern B: Per-Module Metadata File

**Used by:** Homebrew (Formula Ruby class), npm (package.json per module)
**How it works:** Each module has a small metadata file alongside it.

```
plugins/claude/hooks/
  block-destructive.sh
  block-destructive.module.json    # {"description": "...", "scope": "both", ...}
```

**Trade-offs:**
- PRO: Rich metadata per module (description, default scope, dependencies)
- CON: Two files per module, metadata drifts from reality
- CON: Must parse JSON in bash for every module (slow, fragile)
- CON: Over-engineers what the filesystem already communicates

**Verdict for dotconfigs:** Not recommended. Metadata like "description" can be embedded in the file itself (the `# DESCRIPTION:` comment pattern already exists in hooks). Deploy target is a user choice, not module metadata.

**Confidence:** HIGH -- this is demonstrably more complex for no real benefit in our case.

### Pattern C: Central Manifest File

**Used by:** VSCode (package.json `contributes`), Android (AndroidManifest.xml)
**How it works:** A single file in the plugin root declares all modules.

```json
// plugins/claude/manifest.json
{
  "modules": {
    "hooks": ["block-destructive.sh", "post-tool-format.py"],
    "skills": ["commit", "pr-review", "squash-merge"],
    "templates": ["base.json", "hooks.json"]
  }
}
```

**Trade-offs:**
- PRO: Single source of truth for what a plugin provides
- CON: Must be kept in sync with filesystem (they will drift)
- CON: Adding a new module requires editing two places (the file + the manifest)
- CON: The filesystem already IS this manifest

**Verdict for dotconfigs:** Not recommended. This duplicates the filesystem. If `discover_hooks()` already returns the same list, the manifest adds zero value and creates a sync problem.

**Confidence:** HIGH -- the VSCode model makes sense for extensions distributed as packages (where you cannot scan the filesystem at install time), but dotconfigs modules are local files.

### Pattern D: DESCRIPTION File Per Plugin (Already Exists)

**Used by:** dotconfigs v2.0, Debian packages (DESCRIPTION)
**How it works:** A single text file in the plugin root provides human-readable description.

```
plugins/claude/DESCRIPTION
  → "Claude Code configuration (CLAUDE.md, settings, hooks, skills)"
```

**Verdict for dotconfigs:** Keep this. It is already there and useful for `dotconfigs list`. But it describes the plugin, not individual modules. That is the right level of abstraction.

---

## 2. Manifest/Registry Patterns (Ranked by Simplicity)

How does the system know what is available and what the user has chosen?

### Pattern A: Filesystem Discovery + User Config File (RECOMMENDED)

**Used by:** Oh My Zsh, Dotbot, GNU Stow (via command-line args)
**How it works:** Available modules = filesystem scan. Enabled modules + targets = config file.

**Oh My Zsh model:**
```
# Available: scan ~/.oh-my-zsh/plugins/*/
# Enabled: plugins=(git docker node) in .zshrc
# Deploy target: implicit (sourced into shell)
```

**Dotbot model:**
```yaml
# Available: files in dotfiles repo
# Enabled + targets: install.conf.yaml
- link:
    ~/.vimrc: vimrc
    ~/.config/nvim: config/nvim
```

**dotconfigs v3.0 equivalent:**
```
Available:  discover_hooks(), discover_skills(), etc. (filesystem scan)
Enabled:    JSON config file lists which modules are active
Targets:    JSON config file specifies where each module deploys
```

This is the right pattern because:
1. Discovery is already implemented and working
2. The config file only records USER DECISIONS, not system facts
3. Adding a new module = drop a file in the directory. Config is optional until deploy.

**Confidence:** HIGH

### Pattern B: Static Manifest That Drives Everything

**Used by:** npm (package.json), Cargo (Cargo.toml)
**How it works:** The manifest is the SSOT. If it is not in the manifest, it does not exist.

**Why wrong for dotconfigs:** npm/Cargo manifests serve a different purpose -- they define dependencies to download from a remote registry. dotconfigs modules are local files. The filesystem is inherently the SSOT for local files. A manifest that duplicates the filesystem is a lie waiting to happen.

**Confidence:** HIGH

### Pattern C: Database/Registry

**Used by:** Homebrew (formula index), Docker (image registry)
**How it works:** A database tracks metadata, versions, availability.

**Why wrong for dotconfigs:** Massive over-engineering. We have ~20 modules total across 2 plugins. A database is for thousands of packages with versioning and dependency resolution. We have none of those problems.

**Confidence:** HIGH

---

## 3. Config File Patterns for "What to Deploy Where"

This is the core v3.0 design question. How does the user specify deployment targets per module?

### Pattern A: Dotbot-Style Destination-to-Source Mapping (RECOMMENDED)

**Used by:** Dotbot
**Core idea:** The config is a mapping. Key = where it goes. Value = where it comes from.

```yaml
# Dotbot
- link:
    ~/.vimrc: vimrc
    ~/.config/nvim/init.vim: nvim/init.vim
```

**Adapted for dotconfigs JSON:**
```json
{
  "version": "3.0",
  "modules": {
    "claude": {
      "hooks": {
        "block-destructive.sh": {
          "enabled": true,
          "targets": {
            "global": "~/.claude/hooks/block-destructive.sh",
            "project": ".claude/hooks/block-destructive.sh"
          }
        },
        "post-tool-format.py": {
          "enabled": true,
          "targets": {
            "global": "~/.claude/hooks/post-tool-format.py"
          }
        }
      },
      "skills": {
        "commit": {
          "enabled": true,
          "targets": {
            "global": "~/.claude/commands/commit.md"
          }
        }
      }
    }
  }
}
```

**Trade-offs:**
- PRO: Explicit per-module targeting
- PRO: Supports both global and project scope simultaneously
- CON: Verbose for many modules with identical patterns
- CON: Lots of path repetition

**Confidence:** HIGH for the concept, but the verbosity needs solving.

### Pattern B: Convention + Override (RECOMMENDED HYBRID)

**Used by:** GNU Stow (directory mirroring), Cargo (convention with Cargo.toml overrides)
**Core idea:** Conventions provide defaults. Config only records overrides.

```json
{
  "version": "3.0",
  "claude": {
    "deploy_target": "~/.claude",
    "hooks": {
      "enabled": ["block-destructive.sh", "post-tool-format.py"],
      "scope": "global"
    },
    "skills": {
      "enabled": ["commit", "pr-review", "squash-merge", "simplicity-check"],
      "scope": "global"
    },
    "claude_md": {
      "sections": ["communication", "simplicity", "documentation", "git", "code-style"],
      "scope": "global"
    },
    "settings": {
      "enabled": true,
      "scope": "global"
    }
  },
  "git": {
    "hooks": {
      "scope": "project"
    },
    "config": {
      "scope": "global"
    }
  }
}
```

**Convention rules (hardcoded, not configured):**
- hooks deploy to `{deploy_target}/hooks/{filename}`
- skills deploy to `{deploy_target}/commands/{filename}.md`
- claude_md sections assemble into `{deploy_target}/CLAUDE.md`
- settings deploy to `{deploy_target}/settings.json`
- git hooks deploy to `.git/hooks/{filename}` (project) or `~/.dotconfigs/git-hooks/{filename}` (global)
- git config uses `git config --global` (global) or `git config --local` (project)

**The convention eliminates per-file paths.** The user only specifies:
1. Which modules are enabled (array of names)
2. What scope they deploy to (global/project/both)
3. The base deploy target (one path per plugin, already captured in v2.0)

**This is essentially what the .env file already stores, but in JSON.**

**Trade-offs:**
- PRO: Minimal config -- no per-file path specifications
- PRO: Conventions match what deploy.sh already does
- PRO: Easy for wizards to generate (just arrays and enums)
- PRO: Per-module scope granularity without per-module paths
- CON: Cannot handle truly custom deploy paths (edge case)

**Confidence:** HIGH -- this mirrors the existing v2.0 behaviour almost exactly.

### Pattern C: .env-Style Flat Key-Value (Current v2.0 Pattern)

**Used by:** dotconfigs v2.0
**How it works:**
```
CLAUDE_HOOKS_ENABLED="block-destructive.sh post-tool-format.py"
CLAUDE_SKILLS_ENABLED="commit pr-review squash-merge"
CLAUDE_DEPLOY_TARGET="~/.claude"
```

**Why evolve beyond this:**
- Cannot represent nested structure (scope per module type)
- Space-separated arrays are fragile in bash
- No per-project config variant (`.env` is global only)
- Already generating `.dotconfigs.json` for project configs, so JSON is already in play

**Verdict:** .env for global config is fine for v3.0 but the module-level config should be JSON. The `.dotconfigs.json` file already exists for project-level config. Unify by having both global and project configs use JSON.

**Confidence:** HIGH

---

## 4. Scope Handling Patterns (Global vs Project vs Both)

### How Other Tools Handle Scope

**Claude Code itself:**
- `~/.claude/settings.json` (global)
- `.claude/settings.json` (project, shareable)
- `.claude/settings.local.json` (project, private)
- Global and project both active simultaneously. Project overrides global.

**Git:**
- `~/.gitconfig` (global)
- `.git/config` (local/project)
- Both active simultaneously. Local overrides global.

**ESLint (flat config):**
- Single `eslint.config.js` at project root
- No global config file
- Config arrays cascade within the file (not across files)

**Oh My Zsh:**
- Global only (`.zshrc` plugins array)
- No per-project concept

### The Scope Model for dotconfigs v3.0

Based on how the target tools (Claude Code, Git) actually work, scope is a deployment decision:

| Module Type | Global Target | Project Target | Can Be Both? |
|-------------|--------------|----------------|--------------|
| Claude hooks | `~/.claude/hooks/` | `.claude/hooks/` | Yes |
| Claude skills | `~/.claude/commands/` | `.claude/commands/` | Yes |
| Claude settings | `~/.claude/settings.json` | `.claude/settings.local.json` | Yes |
| CLAUDE.md | `~/.claude/CLAUDE.md` | `./CLAUDE.md` | Yes |
| Git hooks | `~/.dotconfigs/git-hooks/` (via core.hooksPath) | `.git/hooks/` | Mutually exclusive* |
| Git config | `~/.gitconfig` | `.git/config` | Yes (local overrides global) |

*Git hooks: `core.hooksPath` is global and overrides ALL per-project hooks. They cannot coexist. This is a Git limitation, not a dotconfigs one.

### How This Subsumes v2.0 Phase 10 "Per-Hook Scope Granularity"

The v2.0 UAT noted that git hooks are all-or-nothing for scope (global via `core.hooksPath` or project via `.git/hooks/`). The v3.0 module system naturally solves this:

**For Claude hooks:** Each hook can be independently enabled at global scope, project scope, or both. The config simply lists which hooks are in `global.hooks.enabled` vs `project.hooks.enabled`.

**For Git hooks:** Due to Git's `core.hooksPath` limitation, git hooks remain all-or-nothing for global scope. But the v3.0 config makes this explicit per-plugin rather than hidden in a single .env variable:

```json
{
  "git": {
    "hooks": {
      "scope": "project",
      "enabled": ["pre-commit", "commit-msg", "prepare-commit-msg", "pre-push"]
    }
  }
}
```

The user can also choose `"scope": "global"` to use `core.hooksPath`, with the config documenting the trade-off.

**Confidence:** HIGH -- this directly maps to how the underlying tools work.

---

## 5. Wizard Integration Patterns

### Pattern A: Wizard as JSON Generator (RECOMMENDED)

**Used by:** `npm init` (generates package.json), Angular CLI (generates angular.json)
**Core idea:** The wizard asks questions and writes a JSON config file. The deploy command reads the JSON.

```
User flow:
  dotconfigs global-configs claude
    → wizard asks which hooks, skills, sections to enable
    → wizard asks scope (global/project/both)
    → wizard writes config JSON
    → user runs: dotconfigs deploy
    → deploy reads config JSON, creates symlinks
```

**npm parallel:**
```
npm init
  → asks name, version, description, etc.
  → writes package.json
  → user runs: npm install
  → install reads package.json, downloads dependencies
```

**This is exactly the v2.0 pattern, but with JSON instead of .env:**
```
v2.0: wizard → .env → deploy reads .env
v3.0: wizard → config.json → deploy reads config.json
```

**Confidence:** HIGH -- this is the natural evolution of what already works.

### Pattern B: Wizard That Deploys Directly

**Used by:** dotconfigs v2.0 project.sh (currently broken -- mixes config and deploy)
**Core idea:** The wizard both configures AND deploys in one step.

**Why NOT recommended for v3.0:**
- Conflates two concerns (deciding what to deploy vs deploying it)
- Cannot re-deploy without re-answering questions
- Cannot script deployment without running the wizard
- The v2.0 UAT reported bugs precisely because project.sh tries to do both

**Verdict:** v3.0 should cleanly separate: wizard writes config, deploy reads config.

### Pattern C: Config File Is Directly Editable

**Used by:** Every tool (package.json, Cargo.toml, eslint.config.js)
**Core idea:** Advanced users skip the wizard and edit the JSON directly.

**This should be supported but not required.** The JSON schema should be simple enough that:
1. Wizards can generate it
2. Users can hand-edit it
3. The deploy command does not care how it was created

**Confidence:** HIGH

---

## 6. Recommendations for dotconfigs v3.0

### The Simplest Thing That Works

**Module definition:** Filesystem convention. Drop a file in the right directory, it is a module. No manifest.

**Module metadata:** Inline comments (`# DESCRIPTION:` already exists). Extend with `# SCOPE:` for default scope hints if needed. But this is optional -- the config file is what matters.

**Registry/discovery:** Existing `discover_*()` functions. No changes needed.

**Config file:** JSON. One global config (`~/.dotconfigs/config.json` or similar), one per-project config (`.dotconfigs.json`, already exists). Both use the same schema.

**Config schema (the whole thing):**
```json
{
  "version": "3.0",
  "claude": {
    "hooks": {
      "enabled": ["block-destructive.sh", "post-tool-format.py"],
      "scope": "global"
    },
    "skills": {
      "enabled": ["commit", "pr-review", "squash-merge", "simplicity-check"],
      "scope": "global"
    },
    "claude_md": {
      "sections": ["communication", "simplicity", "documentation", "git", "code-style"],
      "scope": "global"
    },
    "settings": {
      "enabled": true,
      "scope": "global"
    }
  },
  "git": {
    "identity": {
      "name": "Henry Baker",
      "email": "henry@example.com"
    },
    "workflow": {
      "pull_rebase": true,
      "push_default": "simple",
      "fetch_prune": true,
      "init_default_branch": "main"
    },
    "aliases": {
      "enabled": ["unstage", "last", "lg", "amend", "undo", "wip"]
    },
    "hooks": {
      "scope": "project",
      "enabled": ["pre-commit", "commit-msg", "prepare-commit-msg", "pre-push", "post-merge", "post-checkout", "post-rewrite"]
    }
  }
}
```

**Deploy logic:** Convention-based. The deploy command knows that:
- `claude.hooks.enabled` + `scope: global` means symlink from `plugins/claude/hooks/{name}` to `~/.claude/hooks/{name}`
- `claude.hooks.enabled` + `scope: project` means symlink/copy to `.claude/hooks/{name}`
- `git.hooks.enabled` + `scope: project` means symlink to `.git/hooks/{name}`

These conventions are hardcoded in deploy.sh (they already are). The config does not specify paths.

**Wizard flow:**
```
dotconfigs global-configs claude
  → scans plugins/claude/ for available modules
  → presents checkbox menus for hooks, skills, sections
  → asks scope preference
  → writes ~/.dotconfigs/config.json

dotconfigs deploy
  → reads config.json
  → for each enabled module, symlinks to conventional target
  → reports results

dotconfigs project-configs claude /path/to/project
  → reads global config as defaults
  → presents per-module override options
  → writes .dotconfigs.json in project
  → deploys project-scope modules
```

### What Changes from v2.0

| Aspect | v2.0 | v3.0 |
|--------|------|------|
| Config format | .env (flat key-value) | JSON (structured) |
| Module granularity | Per-type (all hooks or none) | Per-module (each hook individually) |
| Scope control | Per-plugin (claude = global, git hooks = project) | Per-module-type (hooks = global, skills = project) |
| Project config | .dotconfigs.json (partial) | .dotconfigs.json (full, same schema as global) |
| Discovery | discover_*() functions | Same functions, no change |
| Deploy logic | Reads .env, hardcoded conventions | Reads JSON, same conventions |
| Wizard output | Writes .env | Writes JSON |

### What Does NOT Change

- Plugin directory structure (`plugins/{name}/`)
- Module file locations (`hooks/`, `commands/`, `templates/`)
- Symlink-based deployment (`backup_and_link()`)
- Discovery functions (`discover_hooks()`, etc.)
- CLI command structure (`dotconfigs deploy`, `dotconfigs status`)
- DESCRIPTION files

### Migration Path (v2.0 .env to v3.0 JSON)

One-time migration: read .env, generate equivalent JSON. Can be automated in a migration command:
```bash
dotconfigs migrate  # reads .env, writes config.json, backs up .env
```

Or simply: re-run `dotconfigs global-configs` which now writes JSON instead of .env.

---

## 7. Anti-Features for v3.0

Things to explicitly NOT build.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Per-module manifest files | Duplicates filesystem, sync burden | Filesystem IS the manifest |
| Module dependency resolution | We have ~20 modules, no circular deps | Document conventions, no resolver |
| Module versioning | Modules live in same repo, git IS the version | Use git commits |
| Schema validation engine | JSON is simple enough to validate with jq | Basic jq checks in deploy |
| Plugin registry/marketplace | Personal tool, not a framework | Document "how to add a plugin" |
| YAML config option | JSON is sufficient, jq available | Stick to one format |
| Module templating/variables | Over-engineering | Modules are static files, use shell substitution if needed |
| Central module database | SQLite, etc. | JSON file is the database |
| Module priority/ordering | Hooks are independent, order does not matter | Deploy in filesystem order |
| Nested module dependencies | Hook A depends on hook B | Not a real problem for our scale |

---

## 8. Feature Dependencies for v3.0

```
Filesystem Discovery (exists)
    |
    v
JSON Config Schema Design
    |
    +---> Global Config Writer (replaces .env wizard)
    |         |
    |         v
    +---> Project Config Writer (replaces project.sh wizard)
    |
    v
Deploy Reads JSON (replaces .env reader)
    |
    +---> Per-module scope resolution
    |
    v
Status Reads JSON (replaces .env reader)
    |
    v
Migration Command (.env -> JSON, optional)
```

**Critical path:** JSON schema design -> config writer -> deploy reader. Everything else is incremental.

---

## 9. Open Questions

1. **Config file location:** `~/.dotconfigs/config.json` or keep alongside the repo (e.g., `.env` location)? The repo location makes it portable (clone and deploy). But it means the config is tied to the repo, not the machine. **Recommendation:** Keep in repo root as `config.json` (replaces `.env`). It is already gitignored.

2. **Per-module scope or per-type scope?** The config schema above uses per-type (all hooks share one scope). Should it support per-module? e.g., `block-destructive.sh` at global + project, but `post-tool-format.py` at project only? **Recommendation:** Start with per-type. Add per-module override later if needed. YAGNI.

3. **Should the JSON subsume ALL .env content?** Including git identity, workflow settings, aliases? Or just module deployment config? **Recommendation:** Yes, subsume everything. One config file to rule them all. The JSON schema above includes git identity, workflow, aliases alongside module config.

4. **How to handle the settings.json assembly?** Currently settings.json is assembled from templates (base + overlay). Should this be a "module" or a separate concern? **Recommendation:** Treat it as a module with `"enabled": true`. The assembly logic stays in deploy.sh. The config just says whether to deploy it.

---

## Confidence Assessment

| Area | Level | Rationale |
|------|-------|-----------|
| Filesystem-as-manifest | HIGH | Pattern used by Vim, Oh My Zsh, GNU Stow, Cargo -- all battle-tested |
| JSON config for user choices | HIGH | npm, Dotbot, Angular, ESLint all use this pattern |
| Convention-based deploy targets | HIGH | GNU Stow, Cargo -- conventions eliminate config |
| Scope model (global/project/both) | HIGH | Directly mirrors how Claude Code and Git actually work |
| Wizard-generates-config pattern | HIGH | npm init is the canonical example, widely understood |
| Migration from .env to JSON | MEDIUM | Straightforward but needs testing with edge cases |
| Per-module scope granularity | MEDIUM | Clear design but may be YAGNI for v3.0 |

---

## Sources

### Module Definition Patterns
- [Oh My Zsh Plugins Wiki](https://github.com/ohmyzsh/ohmyzsh/wiki/plugins) -- plugin discovery via filesystem convention
- [Zsh Plugin Standard](https://wiki.zshell.dev/community/zsh_plugin_standard) -- formalised plugin naming conventions
- [Vim Plugin Layout with Pathogen](https://learnvimscriptthehardway.stevelosh.com/chapters/43.html) -- directory structure IS the declaration
- [Vim 8 Native Pack System](https://medium.com/@paulodiovani/installing-vim-8-plugins-with-the-native-pack-system-39b71c351fea) -- filesystem convention without plugin manager
- [VSCode Extension Manifest](https://code.visualstudio.com/api/references/extension-manifest) -- package.json `contributes` field pattern (central manifest)
- [VSCode Contribution Points](https://code.visualstudio.com/api/references/contribution-points) -- how extensions declare capabilities

### Manifest/Registry Patterns
- [GNU Stow Manual](https://www.gnu.org/software/stow/manual/stow.html) -- filesystem mirroring, no manifest needed
- [Using GNU Stow for Dotfiles](https://systemcrafters.net/managing-your-dotfiles/using-gnu-stow/) -- package = directory, target = convention
- [chezmoi Design FAQ](https://www.chezmoi.io/user-guide/frequently-asked-questions/design/) -- metadata in filenames, no central manifest
- [Cargo Manifest Format](https://doc.rust-lang.org/cargo/reference/manifest.html) -- auto-discovery with manifest overrides
- [Convention Over Configuration](https://devopedia.org/convention-over-configuration) -- the principle behind filesystem-as-manifest

### Config File Patterns
- [Dotbot GitHub](https://github.com/anishathalye/dotbot) -- YAML/JSON config for link targets, the canonical dotfiles deploy config
- [Dotbot Bootstrap Guide](https://www.elliotdenolf.com/blog/bootstrap-your-dotfiles-with-dotbot) -- install.conf.yaml examples
- [ESLint Flat Config](https://eslint.org/blog/2022/08/new-config-system-part-2/) -- single config file, pattern-based scoping
- [ESLint Configuration Files](https://eslint.org/docs/latest/use/configure/configuration-files) -- flat cascade within one file

### Scope Patterns
- [chezmoi Daily Operations](https://www.chezmoi.io/user-guide/daily-operations/) -- source state vs target state model
- [Homebrew Formula Cookbook](https://docs.brew.sh/Formula-Cookbook) -- per-platform conditional declarations

### Wizard/Config Generation Patterns
- [npm init Documentation](https://docs.npmjs.com/cli/v8/commands/npm-init/) -- wizard generates config file
- [Creating a package.json](https://docs.npmjs.com/creating-a-package-json-file/) -- interactive + skip-questionnaire modes
- [init-package-json](https://github.com/npm/init-package-json) -- the library behind npm init

### Dotfiles Management (General)
- [Dotfiles Utilities](https://dotfiles.github.io/utilities/) -- survey of dotfile management tools
- [chezmoi Quick Start](https://www.chezmoi.io/quick-start/) -- source-to-target mapping approach
- [yadm](https://yadm.io/) -- filesystem-based, no manifest approach

---

*Research complete. The v3.0 module system is a natural evolution: formalise filesystem conventions already in use, replace .env with JSON config, and let conventions handle deploy targets. No new infrastructure patterns needed.*
