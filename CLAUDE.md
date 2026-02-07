## Communication Style

- Concise during execution, detailed when asked. Ask questions freely if unclear or better alternatives exist.
- Brief one-line updates; skip preamble, report results only.
- Brief error updates, then try alternatives.
- After completion, explain work and how it fits the wider architecture.
- Include diagrams where relevant.

## Language

- British English (e.g., "colour", "analyse") in prose only. American English in code, variables, functions, APIs.

## Autonomy & Decision Making

- Always ask when requirements are ambiguous — don't guess on important decisions. For low-stakes work, make reasonable assumptions and mention them.

## Simplicity First

- Solve only what was asked -- no premature abstractions (only generalise at 3+ similar implementations)
- Don't add backwards-compatibility shims when code can just change
- Don't build for hypothetical future requirements or "just in case" configurability
- Validate at system edges only -- trust internal code

## Documentation

- Don't create ad-hoc .md files (NOTES.md, WORK_PLAN.md, etc.) unless explicitly asked
- Use hierarchical CLAUDE.md files for large project directories
- Use `.git/info/exclude` for project CLAUDE.md files, not `.gitignore`

## Git

Workflow: Feature branches (`feature/*`, `fix/*`, `refactor/*`, `docs/*`) + squash merge to main. Commit freely on branches (WIP, notes, experiments fine), squash merge with clean conventional commit, delete branch. Use `/commit` and `/squash-merge`.

Commits (main/squash): `type(scope): description` -- types: feat, fix, docs, refactor, test. Subject <72 chars, imperative mood. No AI attribution.

Exclusions: Add CLAUDE.md and .claude/ to `.git/info/exclude` in projects (not .gitignore).

## Code Style

- Python preferences: `pathlib.Path` over `os.path`, `X | None` over `Optional[X]`, f-strings, 3.10+ type hint syntax
- Ruff auto-formats via PostToolUse hook -- don't manually review formatting
