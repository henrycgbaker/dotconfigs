# claude

[← docs](../../README.md#documentation) · [Plugins](../plugins.md) · Reference

Manages Claude Code configuration. Catalogued under three categories - `hooks`, `skills`, `config`.

| Category | Items | Target(s) | Method |
|----------|-------|-----------|--------|
| hooks | `_hook-common` + 14 event hooks | `~/.claude/hooks/<name>.sh` | symlink |
| skills | `commit`, `squash-merge`, … (9) | `~/.claude/skills/<name>` + `.claude/skills/<name>` | symlink |
| config | `settings` | `~/.claude/settings.json` | [merge](../deploy-methods.md#the-settingsjson-case-why-merge-exists) |
| config | `claude-md` | `~/.claude/CLAUDE.md` | symlink |
| config | `output-style` | `~/.claude/output-styles/concise-execution.md` | symlink |

## What each hook actually does

| Hook | What it blocks/does |
|------|----------------------|
| `block-rm-rf-root` | Blocks `rm -rf /` or `rm -rf ~` (full filesystem wipe) |
| `block-force-push` | Blocks a force-push unless explicitly confirmed |
| `block-hard-reset` | Blocks `git reset --hard` without confirmation |
| `block-git-clean` | Blocks `git clean` (would delete untracked files) without confirmation |
| `block-drop-table` | Blocks `DROP TABLE` in any SQL surface |
| `block-chmod-777` | Blocks `chmod 777` (world-writable permissions) |
| `block-sensitive-write` | Blocks `Write`/`Edit` on `.pem`, `credentials*`, `.env.production`, SSH private keys |
| `block-ai-pr-attribution` | Blocks AI attribution ("Co-Authored-By: Claude", "🤖 Generated with...") in commit messages, PR titles/bodies, and GitHub MCP calls |
| `block-gh-comment` | Blocks commenting on GitHub issues/PRs unless explicitly asked |
| `facade-check` | Verifies every facade `__all__` entry has an external consumer (catches dead re-exports) |
| `inject-context` | Injects project context at session start |
| `session-start-env` | Sets up session environment at start |
| `session-end-log` | Logs session summary at end |
| `pre-compact-snapshot` | Snapshots state before a context compaction |
| `notify` | Sends a notification on specific events (e.g. needing input) |

`_hook-common` is a sourced helper library, not an event hook (no `wiring`). Full table with
descriptions and Event/Matcher: [ROSTER](../ROSTER.md).

## Skills

`/commit`, `/squash-merge`, `/check-resolution`, `/preflight-merge`, `/rebase-stacked-prs`,
`/branch-cleanup`, `/pr-create`, `/fix-pr-feedback`, `/diagnose-missing-work` - each a
`skills/<name>/SKILL.md`. Their dual target deploys them globally **and** lets them be installed
per-repo.

## Output style

`concise-execution` - the default execution-mode style; carries the communication/language rules
(terse output, no unsolicited summaries, etc.).

`settings.json` uses `merge` (not symlink) because Claude Code writes permission grants into it -
see [Deploy methods](../deploy-methods.md). There is no `claude-hooks.conf`: a hook is on when its
item is `true` in `deploy.json`; to disable one, set it `false`.

## Hook wiring and scope

Unlike git, Claude Code **does** read a machine-wide config: a hook is *activated* by a `hooks`
block in `~/.claude/settings.json`, which fires in **every** directory. A hook **script** in
`~/.claude/hooks/` does nothing on its own - only a `settings.json` entry pointing at it makes it
run.

That entry is **not hand-maintained**. Each event hook's manifest entry carries a `wiring` field
(`{ event, matcher?, if?, timeout? }`, or an array of them). On every machine `deploy`, dotconfigs
synthesises the `settings.json` `hooks` block from the `wiring` of exactly the hooks selected in
`deploy.json`:

> **Single toggle, no dangling refs.** Selecting a hook symlinks its script *and* wires it;
> deselecting it (setting the item `false` in `deploy.json`) removes both. There is no separate
> wiring step, no static `hooks` block in `plugins/claude/settings.json`, and no way for a wired
> command to point at a script that isn't deployed.

All Claude hooks are wired at machine scope, so the guards protect even non-repo directories from
a single source of truth.

## Related

- [Plugins overview](../plugins.md)
- [Manifest format](../manifest.md)
- [Deploy methods](../deploy-methods.md)
- [ROSTER.md](../ROSTER.md) - generated hook/skill reference
