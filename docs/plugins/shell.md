# shell

[← docs](../../README.md#documentation) · [Plugins](../plugins.md) · Reference

Shell initialisation and aliases for both bash and zsh. Machine scope only. `init.sh` and
`aliases.sh` are shell-agnostic - `init.sh` parameterises tool setup on the running shell - so
both shells get the same aliases and tooling. Auto-wired into `~/.zshrc` and `~/.bashrc` via
managed blocks, so there's nothing to source by hand. If a machine's login shell is bash (common
on domain-joined accounts where `chsh` is blocked), `bashrc-handoff` execs into zsh from
`~/.bashrc` when zsh is installed; when it isn't (or the handoff is skipped via
`DOTCONFIGS_NO_ZSH_HANDOFF=1`), `bashrc-wiring` (a second managed block, ordered after the
handoff) sources `init.sh` + `aliases.sh` so bash is still fully configured.

| Item | Source | Target |
|------|--------|--------|
| `init` | `plugins/shell/init.sh` | `~/.dotconfigs/shell/init.sh` |
| `aliases` | `plugins/shell/aliases.sh` | `~/.dotconfigs/shell/aliases.sh` |
| `zshrc-wiring` | `plugins/shell/templates/zshrc-managed-block` | `~/.zshrc` (managed block) |
| `bashrc-handoff` | `plugins/shell/templates/bashrc-zsh-handoff` | `~/.bashrc` (managed block) |
| `bashrc-wiring` | `plugins/shell/templates/bashrc-managed-block` | `~/.bashrc` (managed block) |

Every tool below is individually guarded (`command -v` / file-existence checks) - a machine
missing one just skips that line silently, it doesn't break the rest of the shell.

## What `init.sh` actually configures

| Tool | What it gives you |
|------|--------------------|
| **starship** | The prompt itself - shows current dir, git branch/status, language/tool versions (conda env, node, python, …), and command duration, all themeable via `~/.config/starship.toml`. Without it you get zsh's bare default prompt. |
| **zoxide** | A smarter `cd`. Tracks directories you actually visit (frecency-ranked) so `z proj` jumps straight to `~/Documents/repositories/dotconfigs` without typing the full path. |
| **fzf** | Fuzzy-finding wired into the shell: `Ctrl-R` fuzzy-searches command history, `Ctrl-T` fuzzy-finds a file to insert at the cursor, and tab-completion gets fuzzy matching. Found either via the git-installer layout (`~/.fzf.zsh` / `~/.fzf.bash`) or apt's package layout (`/usr/share/doc/fzf/examples/`), picking the file for the running shell. |
| **thefuck** | The `fuck` alias - re-runs your previous command with an auto-corrected typo (e.g. `gt status` → `git status`). |
| **conda** (miniconda/anaconda/miniforge/mambaforge) | Activates whichever is actually installed's shell hook, so `conda activate <env>` and env switching work in every new shell - not just a login shell that happened to run the installer's setup once. |
| **zsh-autosuggestions** (zsh only) | As you type, suggests the rest of a command (greyed out) based on your history - accept with `→`. Skipped under bash, which has no drop-in equivalent. |
| **zsh-syntax-highlighting** (zsh only) | Colours the command line as you type - green for a valid command, red for one that doesn't exist - *before* you hit enter. Must load last; loading anything after it can break the highlighting. Skipped under bash. |

## What `aliases.sh` actually configures

| Alias/export | What it does |
|---|---|
| `cat` → `bat`/`batcat` | Syntax-highlighted, line-numbered file viewing instead of plain `cat`. Debian/Ubuntu ships the binary as `batcat` (name conflict with an older package) - detected and aliased accordingly. |
| `ls` → `eza --icons --group-directories-first` | Modern `ls` replacement - file-type icons, directories sorted first. |
| `claude` → `~/.claude/local/claude` | Shortcut to Claude Code's native-installer binary, if that install layout is present. |
| `ultrawide-default` / `ultrawide-full` | `displayplacer` presets for this Mac's specific ultrawide monitor (hardcoded display UUID - personal hardware, not portable). |
| `grafana-tunnel` | `ssh -fNL 3000:localhost:3000 dsl` - opens an SSH port-forward to a personal Grafana instance reachable through the `dsl` host. |
| `home` | `cd /opt/ds01-infra` - jumps to the ds01 infra checkout (personal path, not portable). |
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
