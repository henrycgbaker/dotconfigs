## Thinking Mode

- Always use extended thinking for complex architecting problems and decision-making. 
- Don't use use extended thinking unless requsted when in conversation / writing docs / straightforward tasks

## Communication Style

- Concise during execution, detailed when asked. Ask questions freely if unclear or better alternatives exist.
- Brief one-line updates; skip preamble, report results only.
- Brief error updates, then try alternatives.
- After completion, explain work and how it fits the wider architecture.
- Include diagrams where relevant.

## Language

- British English (e.g., "colour", "analyse") in prose only. American English in code, variables, functions, APIs.
- Use `-` not `--` or `—` (em dash) in prose. Never use em dashes.

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

Workflow: Feature branches (`feature/*`, `fix/*`, `refactor/*`, `docs/*`) + squash merge to main. Commit freely on branches (WIP, notes, experiments fine), squash merge with clean conventional commit, delete branch. Use `/commit` and `/squash-merge`.

Be accretive with commits on branches/PRs. New review feedback, polish, /simplify findings, follow-up fixes - these go in new commits, not amends. Branches squash-merge, so commit count is free during review and discrete commits make changes visible to the reviewer. Amend only for tiny cosmetic fixes to a freshly-pushed commit (typo in message, fixing a stray whitespace) or when the user explicitly asks. "Yes" to "push when ready" is not "yes, amend" - confirm explicitly before amending.

Merges to main: Always via squash-merge PR (`/squash-merge`). Branch protection enforces CI pass. No direct pushes to main.

Commits (main/squash): `type(scope): description` - types: feat, fix, docs, refactor, test. Subject <72 chars, imperative mood. No AI attribution. Never include phase numbers, milestone IDs, or GSD workflow references in commit messages.

Hooks: Per-project via `.git/hooks/`. Install with `dotconfigs project .` or manually:
`cp ~/.dotconfigs/git-hooks/{pre-commit,commit-msg,pre-push} .git/hooks/ && chmod +x .git/hooks/*`
- Pre-commit: Identity check, secrets scan, block main commits, Ruff format+lint on staged files
- Commit-msg: Blocks AI attribution
- Pre-push: Fast lint + format check, force-push protection (tests + types run in CI)

Exclusions: Add CLAUDE.md and .claude/ to `.git/info/exclude` in projects (not .gitignore).

Do NOT comment directly on GitHub, unless requested to explicitly.

Rebasing a stale PR: if a PR branch has diverged from main by more than a handful of merges, check `git log origin/main..HEAD` and `git log HEAD..origin/main` before `git rebase origin/main`. Commits on the branch that duplicate work already merged on main (similar titles, overlapping file changes) need to be explicitly dropped via `git rebase -i origin/main` with `drop` directives - don't rely on conflict resolution to sort it out. When conflicts arise from review-polish commits that only exist on main, take main's version rather than trying to merge the two forms.

Missing-work diagnosis: When a user says "I thought we did X" or "this seems to have got lost", the FIRST step is `git fetch origin` - do not reason about main from stale local refs. Then check `git log origin/main` and `gh pr list --state merged --search "<keyword>"`. In a squash-merge workflow, merged PRs create new commits on main with different SHAs; the original source-branch commits persist in the loose object store as "dangling" and this is the normal post-merge state, NOT evidence of loss. Before ever concluding work is lost from `git fsck --lost-found --unreachable` output, diff the dangling commits' content against `origin/main` to check for overlap - in a squash-merge repo they are almost always already integrated.

## Code Style

- Python preferences: `pathlib.Path` over `os.path`, `X | None` over `Optional[X]`, f-strings, 3.10+ type hint syntax
- Ruff auto-formats via git pre-commit hook - don't manually review formatting
