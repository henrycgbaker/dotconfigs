# Architecture: Shell Configuration Management

**Domain:** Shell plugin for dotconfigs (plugins/shell/)
**Researched:** 2026-02-10
**Overall confidence:** HIGH

---

## Executive Summary

A shell plugin for dotconfigs should follow the "sourceable snippet" pattern used by virtually every tool that integrates with the user's shell (Homebrew, nvm, pyenv, Starship, etc.). The plugin generates configuration files in a managed directory (`~/.dotconfigs/shell/`) and injects a single `source` line into the user's `.zshrc`. This is the safest, most predictable approach and aligns with dotconfigs' existing "thin layer, don't replace" philosophy.

The critical architectural decision is **what to manage vs. what to leave alone**. Shell configuration is deeply personal territory. The plugin should manage discrete, well-scoped concerns (aliases, functions, PATH additions, environment variables) while explicitly refusing to manage the user's prompt, plugin manager, shell options, or completions. These latter concerns are tightly coupled to the user's existing setup and attempting to manage them creates conflict risk that far exceeds the value.

---

## 1. What to Manage (Recommended Scope)

### Tier 1: Core (MVP)

| Concern | Why | Complexity | Notes |
|---------|-----|------------|-------|
| **Aliases** | Simple, high-value, low-risk. Users want consistent aliases across machines. | Low | POSIX-compatible subset works in both zsh and bash |
| **Functions** | Natural extension of aliases for multi-step shortcuts. | Low | Keep POSIX-compatible where possible |
| **PATH additions** | Tools installed by dotconfigs or the user's custom bin directories need PATH entries. | Medium | Requires idempotent add-to-PATH helper; order matters |
| **Environment variables** | Tool configuration (EDITOR, PAGER, LANG, etc.) and custom vars. | Low | Simple exports, no secrets |

### Tier 2: Extended (Post-MVP)

| Concern | Why | Complexity | Notes |
|---------|-----|------------|-------|
| **Tool initialisers** | Lines like `eval "$(pyenv init -)"`, `eval "$(starship init zsh)"` | Medium | Ordering-sensitive; must come after PATH setup |
| **Conditional blocks** | Platform-specific config (macOS vs Linux), machine-specific overrides | Medium | Template-based with conditionals |

### What Each Tier Covers

**Aliases** -- simple `alias name='command'` definitions. The git plugin already manages git aliases via `git config`; the shell plugin manages shell-level aliases (e.g., `alias ll='ls -la'`, `alias dc='docker compose'`).

**Functions** -- multi-line shell functions. Example: `mkcd() { mkdir -p "$1" && cd "$1"; }`. These go beyond what aliases can do and are a common dotfiles pattern.

**PATH additions** -- prepend or append directories to PATH. Must be idempotent (no duplicates on re-sourcing). Common entries: `~/bin`, `~/.local/bin`, tool-specific directories.

**Environment variables** -- `export EDITOR=nvim`, `export PAGER=less`, etc. NOT secrets/API keys (those belong in a secrets manager or `.env` files, not shell config).

---

## 2. What NOT to Manage (with Rationale)

### Hard No

| Concern | Why Avoid | Risk Level |
|---------|-----------|------------|
| **Full .zshrc replacement** | Users have years of accumulated config. Replacing it breaks their workflow, loses their customisations, and creates a support nightmare. Oh-my-zsh does this and users regularly lose config. | CRITICAL |
| **Prompt/theme (PS1, Starship, Powerlevel10k)** | Prompt is the most visible, most personal part of shell config. Users who care about it already have a setup. Users who don't won't benefit from management. | HIGH |
| **Plugin managers (oh-my-zsh, zinit, zplug, antidote)** | These are opinionated frameworks that control sourcing order, fpath, completions. Attempting to manage them creates conflicts. A user either uses one or they don't -- dotconfigs should not be in this business. | HIGH |
| **Shell options (setopt/shopt)** | Highly personal, shell-specific, and can break scripts. `setopt AUTO_CD` changes fundamental shell behaviour. Wrong options can make the shell unusable. | HIGH |
| **Completions** | Tightly coupled to shell version, installed tools, and plugin managers. Completions that conflict with existing ones cause subtle, hard-to-debug breakage. | MEDIUM |
| **System-level config** | `/etc/zshrc`, `/etc/profile.d/`, `/etc/paths.d/` -- these require root and affect all users. Out of scope entirely. | CRITICAL |

### Soft No (Acknowledge but Defer)

| Concern | Why Defer | Reconsider When |
|---------|-----------|-----------------|
| **Login shell vs interactive shell differences** | Most users don't understand the distinction. Sourcing from .zshrc covers 99% of use cases (interactive shells). | User requests .zshenv support for non-interactive PATH |
| **Secrets/API keys** | Shell config files are often committed to git. Secrets in shell config is an anti-pattern. | Never -- recommend `pass`, `1Password CLI`, or `.env` files instead |

---

## 3. Deployment Patterns (Ranked)

### Pattern 1: Sourceable Directory (RECOMMENDED)

```
~/.dotconfigs/shell/
  init.zsh            # Entry point: sources all files below in order
  01-path.zsh         # PATH additions (idempotent)
  02-env.zsh          # Environment variables
  03-aliases.zsh      # Aliases
  04-functions.zsh    # Functions
  05-tools.zsh        # Tool initialisers (eval "$(pyenv init -)")
```

**Injection into .zshrc:**
```bash
# --- dotconfigs shell plugin ---
[ -f "$HOME/.dotconfigs/shell/init.zsh" ] && source "$HOME/.dotconfigs/shell/init.zsh"
```

**How it works:**
1. Wizard collects configuration (aliases, PATH dirs, env vars, etc.)
2. Deploy generates numbered files in `~/.dotconfigs/shell/`
3. Deploy adds one source line to `.zshrc` (idempotent, grep-guarded)
4. init.zsh sources all `*.zsh` files in order

**Why this pattern:**
- **Safe:** One line in .zshrc. Easy to remove. Easy to debug.
- **Modular:** Each concern in its own file. User can disable one file without touching others.
- **Ordered:** Numbered prefixes ensure PATH is set before tool initialisers.
- **Idempotent:** Source line uses grep guard; PATH helper prevents duplicates.
- **Familiar:** This is exactly what Homebrew, nvm, pyenv, and Starship do.
- **Debuggable:** User can `cat` any file to see what dotconfigs added.

**Confidence:** HIGH -- this is the established industry pattern.

### Pattern 2: Stow-style Symlinks

Symlink individual files from `plugins/shell/templates/` to `~/.dotconfigs/shell/`.

**Pros:** Matches dotconfigs' existing symlink pattern (claude plugin uses this).
**Cons:** Shell config files are often generated/assembled from wizard input, not static templates. Symlinks to generated files adds complexity without benefit.

**Verdict:** Not recommended for shell config. The claude plugin symlinks because its files are mostly static templates. Shell config is user-driven and assembled from wizard choices.

### Pattern 3: Direct .zshrc Modification

Write aliases, PATH additions, etc. directly into .zshrc between marker comments.

```bash
# BEGIN dotconfigs shell
alias ll='ls -la'
export EDITOR=nvim
# END dotconfigs shell
```

**Pros:** No extra files. Everything visible in one place.
**Cons:** Fragile. Marker-based editing is error-prone. User edits between markers get overwritten. Merge conflicts if user also edits .zshrc. No modularity.

**Verdict:** Not recommended. Too fragile, too invasive.

### Pattern 4: oh-my-zsh custom/ Directory

Place files in `$ZSH_CUSTOM/*.zsh` for automatic sourcing by oh-my-zsh.

**Pros:** Zero injection needed if user has oh-my-zsh.
**Cons:** Only works if user has oh-my-zsh. Creates a hard dependency on a specific plugin manager. Breaks for non-oh-my-zsh users.

**Verdict:** Not recommended as primary pattern. Could be offered as an alternative deployment target if oh-my-zsh is detected, but the primary pattern must work without it.

---

## 4. Shell Startup File Ordering (zsh on macOS)

### The Full Chain

```
ALL SHELLS:
  /etc/zshenv          (system)
  ~/.zshenv            (user)

LOGIN SHELLS (new Terminal.app window, SSH):
  /etc/zprofile        (system) -- macOS runs path_helper here!
  ~/.zprofile          (user)

INTERACTIVE SHELLS (login + subshells):
  /etc/zshrc           (system)
  ~/.zshrc             (user)    <-- dotconfigs hooks in HERE

LOGIN SHELLS (after .zshrc):
  /etc/zlogin          (system)
  ~/.zlogin            (user)

ON EXIT:
  ~/.zlogout           (user)
  /etc/zlogout         (system)
```

### Where dotconfigs Should Hook: `.zshrc`

**Rationale:**

1. **After path_helper:** macOS's `/etc/zprofile` calls `/usr/libexec/path_helper`, which reorders PATH. Any PATH modifications in `.zshenv` or `.zprofile` get shuffled. Hooking into `.zshrc` means our PATH additions come AFTER path_helper and thus take precedence.

2. **Interactive shells only:** Aliases, functions, and most environment variables only matter in interactive shells. `.zshrc` runs for exactly these.

3. **Convention:** Homebrew, nvm, pyenv, rbenv, Starship, and most developer tools add their init lines to `.zshrc`. Users expect this.

4. **Subshells included:** `.zshrc` runs for both login shells (Terminal.app windows) and non-login interactive shells (subshells, tmux panes). This covers all interactive use.

**When NOT .zshrc:**
- If a user needs environment variables available in non-interactive contexts (e.g., cron jobs, scripts with `#!/bin/zsh`), those would need `.zshenv`. This is a rare edge case that can be addressed later if needed.

### The path_helper Problem (macOS-specific)

**Confidence: HIGH** (well-documented, verified across multiple sources)

macOS's `/usr/libexec/path_helper` reads `/etc/paths` and `/etc/paths.d/*`, then reorders PATH to put system paths first. This means:

1. If you set PATH in `.zshenv`, path_helper (called from `/etc/zprofile`) will reorder it
2. Your carefully prepended `/opt/homebrew/bin` ends up after `/usr/bin`
3. System tools shadow Homebrew-installed tools

**Solution:** Set PATH in `.zshrc` (after path_helper has run). The dotconfigs shell plugin sources from `.zshrc`, so this is handled naturally.

---

## 5. Cross-Shell Considerations

### Recommendation: zsh-primary, bash-compatible where free

**Rationale:**
- macOS default shell is zsh since Catalina (2019). The target user is on macOS.
- dotconfigs itself runs in bash 3.2 (macOS system bash), but the USER'S shell is zsh.
- Supporting bash as a first-class target doubles testing surface for limited benefit.
- However, many aliases and functions are POSIX-compatible and work in both shells for free.

### Compatibility Matrix

| Feature | zsh | bash | POSIX sh | Notes |
|---------|-----|------|----------|-------|
| Simple aliases | Yes | Yes | Yes | `alias ll='ls -la'` works everywhere |
| Functions | Yes | Yes | Yes | Basic functions are portable |
| `export VAR=val` | Yes | Yes | Yes | Universal |
| PATH manipulation | Yes | Yes | Yes | String operations are portable |
| `typeset -U PATH` | Yes | No | No | zsh-only duplicate prevention |
| Array syntax | Differs | Differs | No | zsh: `arr=(a b)`, bash: `arr=(a b)` -- same syntax, different indexing |
| Completions | zsh-specific | bash-specific | No | Completely different systems |
| `setopt`/`shopt` | zsh | bash | No | Shell-specific options |

### Practical Approach

1. **Generate `.zsh` files by default** (init.zsh, aliases.zsh, etc.)
2. **Keep alias/function/env content POSIX-compatible** where possible
3. **Use `typeset -U PATH path` in init.zsh** for zsh-native duplicate prevention
4. **If bash support is added later**, generate parallel `.bash` files with `init.bash`
5. **Do not attempt a single file that works in both** -- the shells diverge enough that this creates subtle bugs

### File Extension Convention

```
*.zsh   -- zsh-specific (sourced by init.zsh)
*.bash  -- bash-specific (future, sourced by init.bash)
*.sh    -- POSIX-compatible (could be sourced by either)
```

For MVP, generate `.zsh` files only. The content will be largely POSIX-compatible, but the entry point and any zsh-specific features (typeset -U) are zsh-native.

---

## 6. Idempotent PATH Management

### The Problem

Every time `.zshrc` is sourced (new shell, `source ~/.zshrc`, tmux), PATH additions must not create duplicates. A PATH with 5 copies of `/opt/homebrew/bin` is a real problem users encounter.

### Recommended Implementation

```bash
# In init.zsh (zsh-native approach)
typeset -U PATH path  # zsh built-in: automatically deduplicates

# In 01-path.zsh (belt-and-suspenders helper)
dotconfigs_prepend_path() {
  case ":$PATH:" in
    *:"$1":*) ;;  # already present, skip
    *) PATH="$1:$PATH" ;;
  esac
}

dotconfigs_append_path() {
  case ":$PATH:" in
    *:"$1":*) ;;
    *) PATH="$PATH:$1" ;;
  esac
}

# Usage
dotconfigs_prepend_path "$HOME/bin"
dotconfigs_prepend_path "$HOME/.local/bin"
```

**Why both approaches:**
- `typeset -U PATH` is the zsh-native, elegant solution
- The `case` pattern-match helper is POSIX-compatible and works as a fallback
- Belt-and-suspenders: even if someone sources the file from bash, it still works

### Prepend vs Append

| Strategy | Use When | Example |
|----------|----------|---------|
| **Prepend** | User's tools should take priority over system tools | `~/bin`, `~/.local/bin`, tool shims |
| **Append** | Fallback locations, lower priority | Rarely needed; system paths are already present |

**Default: Prepend.** This matches Homebrew, pyenv, nvm, and virtually every developer tool. User-installed tools should shadow system tools.

### How Other Tools Do It

| Tool | Pattern | Idempotency |
|------|---------|-------------|
| **Homebrew** | `eval "$(/opt/homebrew/bin/brew shellenv)"` | Checks if already in PATH, returns early |
| **nvm** | `source nvm.sh` with NVM_DIR | nvm.sh handles internally |
| **pyenv** | `eval "$(pyenv init -)"` | pyenv generates idempotent shell code |
| **Starship** | `eval "$(starship init zsh)"` | Hook-based, no PATH modification |

---

## 7. Safe .zshrc Injection

### The Injection Pattern

dotconfigs needs to add ONE line to the user's `.zshrc`. This must be:
1. **Idempotent** -- running deploy twice doesn't add two source lines
2. **Detectable** -- can check if already present
3. **Removable** -- user can delete the line without side effects
4. **Safe** -- won't break if the sourced file doesn't exist

### Recommended Implementation

```bash
# The line to inject
SHELL_SOURCE_LINE='[ -f "$HOME/.dotconfigs/shell/init.zsh" ] && source "$HOME/.dotconfigs/shell/init.zsh"'

# The marker comment (for detection)
SHELL_MARKER="# dotconfigs:shell"

# Check if already present
if ! grep -qF "$SHELL_MARKER" "$HOME/.zshrc" 2>/dev/null; then
  printf '\n%s %s\n' "$SHELL_SOURCE_LINE" "$SHELL_MARKER" >> "$HOME/.zshrc"
fi
```

**Key details:**
- The `[ -f ... ] &&` guard means if the init file is missing, nothing breaks
- The marker comment makes detection reliable (grep for comment, not the complex source line)
- Appending (not prepending) to `.zshrc` is safest -- user's existing config runs first
- `printf '\n'` ensures the line starts on a new line even if .zshrc lacks a trailing newline

### Backup Before Modification

```bash
# Always back up before first modification
if [[ ! -f "$HOME/.zshrc.dotconfigs-backup" ]]; then
  cp "$HOME/.zshrc" "$HOME/.zshrc.dotconfigs-backup"
fi
```

This follows the oh-my-zsh pattern (`.zshrc.pre-oh-my-zsh`) but is less invasive since we're appending, not replacing.

---

## 8. Component Architecture

### Directory Layout

```
plugins/shell/
  DESCRIPTION              # Plugin metadata
  setup.sh                 # Wizard: collects aliases, PATH dirs, env vars
  deploy.sh                # Deployment: generates files, injects source line
  project.sh               # Per-project: optional project-specific shell config
  templates/
    init.zsh.tmpl          # Template for init.zsh entry point
    path.zsh.tmpl          # Template for PATH additions
    env.zsh.tmpl           # Template for environment variables
    aliases.zsh.tmpl       # Template for aliases
    functions.zsh.tmpl     # Template for functions

# Deployed to:
~/.dotconfigs/shell/
  init.zsh                 # Sources all numbered files
  01-path.zsh              # PATH additions
  02-env.zsh               # Environment variables
  03-aliases.zsh           # Aliases
  04-functions.zsh         # Functions
```

### Plugin Interface (follows dotconfigs convention)

```
plugin_shell_setup()    -- Wizard: prompts for aliases, PATH dirs, env vars
plugin_shell_deploy()   -- Generates files to ~/.dotconfigs/shell/, injects .zshrc line
plugin_shell_project()  -- Optional: project-specific shell overrides
plugin_shell_status()   -- Reports deployment state, checks .zshrc injection
```

### .env Configuration Keys

```bash
# Shell plugin namespace
SHELL_ALIASES_ENABLED="ll la dc gs"     # Space-separated alias names
SHELL_ALIAS_LL="ls -la"                 # Individual alias definitions
SHELL_ALIAS_LA="ls -A"
SHELL_ALIAS_DC="docker compose"
SHELL_ALIAS_GS="git status"

SHELL_PATH_DIRS="$HOME/bin $HOME/.local/bin"  # Space-separated PATH additions

SHELL_ENV_EDITOR="nvim"                 # Environment variable values
SHELL_ENV_PAGER="less"
SHELL_ENV_LANG="en_GB.UTF-8"

SHELL_FUNCTIONS_ENABLED="mkcd extract"  # Space-separated function names
```

### Data Flow

```
Wizard (setup.sh)
  |
  v
.env (SHELL_* keys)
  |
  v
Deploy (deploy.sh)
  |
  +---> Generate ~/.dotconfigs/shell/*.zsh files
  |
  +---> Inject source line into ~/.zshrc (grep-guarded)
  |
  v
User opens new shell
  |
  v
.zshrc sources init.zsh
  |
  v
init.zsh sources 01-path.zsh, 02-env.zsh, 03-aliases.zsh, 04-functions.zsh
```

---

## 9. Minimal Viable Plugin Recommendation

### Phase 1: Aliases + PATH (Smallest Useful Plugin)

**What to build:**
1. Wizard prompts for aliases (predefined defaults + custom)
2. Wizard prompts for PATH directories to add
3. Deploy generates `~/.dotconfigs/shell/init.zsh`, `01-path.zsh`, `03-aliases.zsh`
4. Deploy injects source line into `.zshrc`
5. Status checks .zshrc injection and file existence

**What to skip in Phase 1:**
- Environment variables (users can add exports manually)
- Functions (power-user feature, can wait)
- Tool initialisers (complex ordering, can wait)
- Bash support (zsh-only for MVP)
- project.sh (per-project shell config -- unclear value initially)

**Why this is enough:**
- Aliases are the number one thing users want consistent across machines
- PATH management is the number one thing users get wrong (duplicates, ordering)
- These two concerns cover 80% of the "I wish my shell config was managed" use case

### Phase 2: Environment Variables + Functions

Add environment variable management and shell function management. By this point the infrastructure (wizard, deploy, init.zsh sourcing) is proven.

### Phase 3: Tool Initialisers + Conditional Blocks

Add the ability to manage `eval "$(tool init zsh)"` lines with proper ordering. Add platform conditionals. This is the power-user tier.

---

## 10. Anti-Patterns to Avoid

### Anti-Pattern 1: Generating a Full .zshrc

**What:** Assembling a complete .zshrc from templates and replacing the user's file.
**Why bad:** Users have years of accumulated config. oh-my-zsh's approach of replacing .zshrc (even with backup) causes regular complaints and lost configuration.
**Instead:** Append one source line. Never touch existing content.

### Anti-Pattern 2: Managing the Prompt

**What:** Setting PS1 or configuring Starship/Powerlevel10k themes.
**Why bad:** Prompt configuration is the most visible, most personal shell setting. Users who care already have it set up. Users who don't won't benefit.
**Instead:** Document how to add Starship init to the tool-initialisers section (Phase 3).

### Anti-Pattern 3: Shell Option Management

**What:** Running `setopt AUTO_CD CORRECT HIST_IGNORE_DUPS` etc.
**Why bad:** Shell options change fundamental behaviour. `AUTO_CD` means typing a directory name `cd`s into it -- this breaks scripts that accidentally match directory names. Wrong options make the shell feel alien.
**Instead:** Don't. Shell options are deeply personal and should stay in the user's .zshrc.

### Anti-Pattern 4: Competing with Plugin Managers

**What:** Managing zsh plugins, completions, or syntax highlighting.
**Why bad:** zinit, antidote, oh-my-zsh each have their own sourcing order, fpath management, and completion setup. Attempting to replicate or integrate with these creates a combinatorial explosion of configurations to support.
**Instead:** Coexist peacefully. The source line in .zshrc works regardless of what plugin manager the user has.

### Anti-Pattern 5: Storing Secrets in Shell Config

**What:** `export OPENAI_API_KEY=sk-...` in the managed aliases/env files.
**Why bad:** Shell config files end up in dotfiles repos, backups, and config management tools. Secrets should never be in files that might be committed.
**Instead:** Document that API keys should use `pass`, `1Password CLI`, `direnv`, or `.env` files. Refuse to store values that look like secrets.

---

## Sources

### Shell Startup Ordering
- [Zsh Introduction: Startup Files](https://zsh.sourceforge.io/Intro/intro_3.html) -- Official zsh documentation
- [Zsh Guide Chapter 2: Startup Files](https://zsh.sourceforge.io/Guide/zshguide02.html) -- Official zsh user guide
- [Moving to zsh: Configuration Files](https://scriptingosx.com/2019/06/moving-to-zsh-part-2-configuration-files/) -- macOS-focused guide
- [How Do Zsh Configuration Files Work?](https://www.freecodecamp.org/news/how-do-zsh-configuration-files-work/) -- FreeCodeCamp reference

### macOS path_helper
- [Properly setting PATH for zsh on macOS](https://gist.github.com/Linerre/f11ad4a6a934dcf01ee8415c9457e7b2) -- Detailed path_helper analysis
- [How PATH is Constructed on macOS](https://0xmachos.com/2021-05-13-zsh-path-macos/) -- PATH construction reference
- [Homebrew Discussion: path_helper reordering](https://github.com/orgs/Homebrew/discussions/4747)

### PATH Management
- [Purifying .bashrc and .zshrc](https://paiml.github.io/bashrs/config/purifying.html) -- Idempotent config patterns
- [Remove Duplicates in zsh PATH](https://tech.serhatteker.com/post/2019-12/remove-duplicates-in-path-zsh/) -- typeset -U approach
- [Homebrew shellenv source](https://github.com/Homebrew/brew/blob/master/Library/Homebrew/cmd/shellenv.sh) -- Idempotent PATH reference implementation

### Configuration Management Tools
- [Chezmoi: Why Use Chezmoi?](https://www.chezmoi.io/why-use-chezmoi/) -- Dotfiles management comparison
- [Chezmoi Comparison Table](https://www.chezmoi.io/comparison-table/)
- [Frictionless Dotfile Management with Chezmoi](https://marcusb.org/posts/2025/01/frictionless-dotfile-management-with-chezmoi/)

### oh-my-zsh Custom Directory
- [Oh My Zsh: Configuration and Customization](https://deepwiki.com/ohmyzsh/ohmyzsh/8-configuration-and-customization)
- [Oh My Zsh Custom Aliases](https://scottwhittaker.net/oh-my-zsh-custom-aliases)

### Zsh Plugin Standards
- [Zsh Plugin Standard](https://wiki.zshell.dev/community/zsh_plugin_standard) -- Best practices for zsh plugins

### Cross-Shell Prompts
- [Starship: Cross-Shell Prompt](https://starship.rs/) -- Example of cross-shell configuration pattern

### Security
- [Securing Zsh: Prevent Plugin-Based Attacks](https://hoop.dev/blog/securing-zsh-how-to-lock-down-your-shell-and-prevent-plugin-based-attacks/)

---

*Architecture research: 2026-02-10*
