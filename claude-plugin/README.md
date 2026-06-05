# dots — native Claude Code plugin (generated)

> **Generated artifact — do not edit by hand.** This whole directory is rebuilt
> by `scripts/build-claude-plugin.sh` from `plugins/claude/` (which is the single
> source of truth). Edit the source there and re-run the build; any manual change
> here is wiped on the next build.

This is the [`plugins/claude/`](../plugins/claude/) configuration — safety hooks,
git-workflow skills, and the concise-execution output style — packaged as an
installable **Claude Code plugin** named `dots`. It is committed so it can be
installed without cloning dotconfigs or running the symlink deploy.

## Install (from inside Claude Code)

```
/plugin marketplace add henrycgbaker/dotconfigs
/plugin install dots
```

Installed this way the skills are **namespaced** — `/dots:commit`,
`/dots:squash-merge`, etc. (a full `dotconfigs deploy` installs them un-namespaced).

## Two distribution paths, one source

| Path | What it does |
|------|--------------|
| `dotconfigs deploy` | symlinks `plugins/claude/` into `~/.claude/` (the main path; hooks wired into `~/.claude/settings.json`) |
| this `dots` plugin  | a native Claude Code plugin install — no clone/deploy needed |

## What's in here

- `.claude-plugin/plugin.json` — generated manifest (name/version/description/author).
- `hooks/hooks.json` — the hook wiring, **synthesised** from each hook's `wiring` in
  `plugins/claude/manifest.json` (the same source the deploy engine uses), with commands
  repointed at `${CLAUDE_PLUGIN_ROOT}`.
- `hooks/*.sh` — relative symlinks back to `plugins/claude/hooks/`.
- `skills/`, `output-styles/` — relative symlinks to `plugins/claude/`.
- `settings.json` — the non-hooks portion of `plugins/claude/settings.json`.

To refresh after editing the source: `scripts/build-claude-plugin.sh`.
