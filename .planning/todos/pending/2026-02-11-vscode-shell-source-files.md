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
