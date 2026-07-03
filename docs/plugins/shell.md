# shell

[← docs](../../README.md#documentation) · [Plugins](../plugins.md) · Reference

zsh initialisation and aliases. Machine scope only. Auto-wired into `~/.zshrc` via a managed
block, so there's nothing to source by hand - and if a machine's login shell is bash (common on
domain-joined accounts where `chsh` is blocked), `bashrc-handoff` execs into zsh from `~/.bashrc`
so this activates anyway.

| Item | Source | Target |
|------|--------|--------|
| `init` | `plugins/shell/init.zsh` | `~/.dotconfigs/shell/init.zsh` |
| `aliases` | `plugins/shell/aliases.zsh` | `~/.dotconfigs/shell/aliases.zsh` |
| `zshrc-wiring` | `plugins/shell/templates/zshrc-managed-block` | `~/.zshrc` (managed block) |
| `bashrc-handoff` | `plugins/shell/templates/bashrc-zsh-handoff` | `~/.bashrc` (managed block) |

Every tool below is individually guarded (`command -v` / file-existence checks) - a machine
missing one just skips that line silently, it doesn't break the rest of the shell.

## What `init.zsh` actually configures

| Tool | What it gives you |
|------|--------------------|
| **starship** | The prompt itself - shows current dir, git branch/status, language/tool versions (conda env, node, python, …), and command duration, all themeable via `~/.config/starship.toml`. Without it you get zsh's bare default prompt. |
| **zoxide** | A smarter `cd`. Tracks directories you actually visit (frecency-ranked) so `z proj` jumps straight to `~/Documents/repositories/dotconfigs` without typing the full path. |
| **fzf** | Fuzzy-finding wired into the shell: `Ctrl-R` fuzzy-searches command history, `Ctrl-T` fuzzy-finds a file to insert at the cursor, and tab-completion gets fuzzy matching. Found either via the git-installer layout (`~/.fzf.zsh`) or apt's package layout (`/usr/share/doc/fzf/examples/`). |
| **thefuck** | The `fuck` alias - re-runs your previous command with an auto-corrected typo (e.g. `gt status` → `git status`). |
| **conda** (miniconda/anaconda/miniforge/mambaforge) | Activates whichever is actually installed's shell hook, so `conda activate <env>` and env switching work in every new shell - not just a login shell that happened to run the installer's setup once. |
| **zsh-autosuggestions** | As you type, suggests the rest of a command (greyed out) based on your history - accept with `→`. |
| **zsh-syntax-highlighting** | Colours the command line as you type - green for a valid command, red for one that doesn't exist - *before* you hit enter. Must load last; loading anything after it can break the highlighting. |

## What `aliases.zsh` actually configures

| Alias/export | What it does |
|---|---|
| `cat` → `bat`/`batcat` | Syntax-highlighted, line-numbered file viewing instead of plain `cat`. Debian/Ubuntu ships the binary as `batcat` (name conflict with an older package) - detected and aliased accordingly. |
| `ls` → `eza --icons --group-directories-first` | Modern `ls` replacement - file-type icons, directories sorted first. |
| `claude` → `~/.claude/local/claude` | Shortcut to Claude Code's native-installer binary, if that install layout is present. |
| `ultrawide-default` / `ultrawide-full` | `displayplacer` presets for this Mac's specific ultrawide monitor (hardcoded display UUID - personal hardware, not portable). |
| `grafana-tunnel` | `ssh -fNL 3000:localhost:3000 dsl` - opens an SSH port-forward to a personal Grafana instance reachable through the `dsl` host. |
| `PATH` | Prepends `~/.local/bin` (user-local tool installs) and, on macOS, VS Code's CLI directory. |

## Requirements

This plugin wires up, but does not install, the tools above. On macOS:

```bash
brew install starship zoxide fzf thefuck eza bat zsh-autosuggestions zsh-syntax-highlighting displayplacer
```

On Debian/Ubuntu, `starship`, `zoxide`, and `eza` aren't in the default apt repos (install via
their own installer scripts or a PPA); the rest are:

```bash
sudo apt install fzf thefuck bat zsh-autosuggestions zsh-syntax-highlighting
```

conda is installed via its own installer, not brew/apt.

## Related

- [Plugins overview](../plugins.md)
- [Manifest format](../manifest.md)
- [Deploy methods](../deploy-methods.md)
