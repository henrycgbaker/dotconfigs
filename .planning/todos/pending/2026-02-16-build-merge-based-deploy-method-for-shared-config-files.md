---
created: 2026-02-16T16:29:13.596Z
title: Build merge-based deploy method for shared config files
area: tooling
files:
  - lib/deploy.sh
  - plugins/claude/manifest.json
  - plugins/claude/settings.json
---

## Problem

Some deployed config files (notably `~/.claude/settings.json`) are legitimately written to by external tools (GSD, Claude Code itself). The three current deploy methods each have issues for this case:

- **symlink**: External tools mutate the repo SSOT directly — any write to the target silently changes the source. Discovered when GSD injected a `SessionStart` hook with a hardcoded server path into `plugins/claude/settings.json` via the symlink at `~/.claude/settings.json`.
- **copy**: Dumb overwrite (`cp -p`) — blows away all runtime additions on each deploy. Currently used as a stopgap after switching settings.json away from symlink.
- **append**: Only adds content, doesn't handle structured JSON.

None of these preserve the SSOT while respecting runtime additions from other tools.

## Solution

Add a `"method": "merge"` option in `lib/deploy.sh` for v4. Implementation:

1. **jq-based deep merge** — SSOT keys always win, but runtime-only keys in the target are preserved
2. Strategy: `jq -s '.[0] * .[1]' <target> <source>` (target as base, source overlaid) — or the reverse depending on desired precedence
3. Consider a `merge_strategy` field: `"ssot-wins"` (default — source keys override target) vs `"target-preserves"` (only add missing keys from source)
4. Should handle the case where target doesn't exist yet (fall back to plain copy)

Primary use case: `settings.json` where dotconfigs owns the base config (permissions, sandbox, env) but GSD/Claude Code add hooks, statusLine, etc. at runtime.

Broader applicability: any JSON/YAML config where multiple tools need to coexist at the same target path.
