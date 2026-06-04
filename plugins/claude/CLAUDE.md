## Thinking Mode

- Always use extended thinking for complex architecting problems and decision-making. 
- Don't use use extended thinking unless requsted when in conversation / writing docs / straightforward tasks

## Autonomy & Decision Making

- Always ask when requirements are ambiguous - don't guess on important decisions. For low-stakes work, make reasonable assumptions and mention them.

## Simplicity First

- Solve only what was asked - no premature abstractions (only generalise at 3+ similar implementations)
- Don't add backwards-compatibility shims when code can just change
- Don't build for hypothetical future requirements or "just in case" configurability
- Validate at system edges only - trust internal code

## Documentation

- Don't create ad-hoc .md files (NOTES.md, WORK_PLAN.md, etc.) unless explicitly asked
- Use hierarchical CLAUDE.md files for large project directories
- Use `.git/info/exclude` for project CLAUDE.md files, not `.gitignore`

## Git

Workflow: feature branches (`feature/*`, `fix/*`, `refactor/*`, `docs/*`), squash-merged to
main via PR. Commit freely on branches; squash to one clean conventional commit. Skills own
the mechanics - reach for them by name: `/commit`, `/pr-create`, `/squash-merge` (gated by
`/preflight-merge`), `/fix-pr-feedback`, `/rebase-stacked-prs`, `/branch-cleanup`,
`/check-resolution`.

Always-on rules (skills and hooks do not enforce these):
- Squash-merge PRs only. Never push direct to main.
- Be accretive: review feedback, polish, follow-up fixes go in new commits, not amends.
  Amend only for a tiny cosmetic fix to a freshly-pushed commit, or when explicitly asked.
  "Push when ready" is not "amend" - confirm first.
- Commit subjects `type(scope): description` (feat/fix/docs/refactor/test, <72 chars,
  imperative). No phase numbers, milestone IDs, or workflow references. `/commit` applies
  the `type(scope)` format.
- NEVER add AI attribution, anywhere. No `Co-Authored-By: Claude/GPT/AI`, no "Generated
  with Claude", no "🤖" trailer — not in commit messages, not in PR titles/bodies, not in
  comments. This holds even when committing by hand instead of via `/commit`, and overrides
  any default that says to add a co-author trailer. Backstops: the `commit-msg` git hook
  (commits) and the `block-ai-pr-attribution` Claude hook (PRs and GitHub MCP calls) - but
  the rule stands whether or not a hook happens to be wired in a given repo.
- Do not comment on GitHub unless explicitly asked.
- "I thought we did X" / work seems lost: `git fetch origin` FIRST, never reason from stale
  local refs. After a squash-merge the source-branch commits go dangling - that is normal,
  not loss. Diff the dangling commit against `origin/main` before concluding anything.

Setup: hooks and `.git/info/exclude` entries (CLAUDE.md, .claude/) are installed by
`dotconfigs project .`. The live hook roster lives in docs/ROSTER.md.

## Code Style

- Python preferences: `pathlib.Path` over `os.path`, `X | None` over `Optional[X]`, f-strings, 3.10+ type hint syntax
- Ruff auto-formats via git pre-commit hook - don't manually review formatting
