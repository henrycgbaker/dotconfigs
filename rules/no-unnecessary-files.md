# No Unnecessary Markdown Files

Do not proactively create standalone .md files for explanations, summaries, or implementation notes.

## Always OK
- README.md, CLAUDE.md, CHANGELOG.md
- Plan files in `.claude/plans/`
- TODO tracking via TodoWrite
- Inline code comments and docstrings
- Any .md file explicitly requested

## Avoid
- Ad-hoc explanation files (`NOTES.md`, `HOW_IT_WORKS.md`, `SUMMARY_OF_WORK.md`, `WORK_PLAN.md` etc.)
- Implementation plans or summaries not asked for
- Reference guides created "just in case"

When in doubt, do the work and concisely explain in-terminal, rather than document what you're about to do.

This does NOT apply for explicitly requested documentation files.
