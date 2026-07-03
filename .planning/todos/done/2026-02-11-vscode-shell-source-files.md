# Create vscode and shell plugin source files

## Context

The vscode and shell plugin manifests now declare global modules, but
the source files they reference don't exist yet. These plugins were
placeholders from v3; v4 should flesh them out.

## Files needed

### vscode
- `plugins/vscode/settings.json`
- `plugins/vscode/keybindings.json`
- `plugins/vscode/snippets/` (directory)

### shell
- `plugins/shell/init.zsh`
- `plugins/shell/aliases.zsh`

## Notes

Until these files exist, `global-deploy` will warn about missing sources
for vscode and shell modules — this is expected and harmless.

## Resolution (07-03)

Shell half done: `plugins/shell/init.zsh`/`aliases.zsh` exist, now reconciled
with actual live usage and auto-wired into `~/.zshrc` via a managed block.

vscode half never happened and isn't just "not yet fleshed out" — no
`plugins/vscode/` manifest exists in the current architecture at all (the
"vscode plugin manifests now declare global modules" premise above no
longer holds). Building it would mean creating the plugin from scratch,
not filling in source files for an existing catalogue entry — a separate,
larger task if still wanted.
