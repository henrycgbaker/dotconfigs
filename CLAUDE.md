# Personal Claude Policies

## Communication Style

- Be **concise during execution**, detailed when I ask questions, or you are giving explanations. If anything is unclear, or you think there is a better alternative ask questions freely. 
- Work iteratively: ask many questions in the design / plan phase until you are clear, then are automous in the execution phase. 
- Provide only short one-line updates as you implement; skip unnecessary preamble—just do the work and report results briefly.
- When errors occur, give a **brief update & explanation** on what failed, then move to alternatives.
- At the end of a work piece, concisely explain what you did and how it fits in the wider context of the project architecture, I want to have a granular understanding of the work as we go. 
- Include diagrams where relevant - these are useful

## Language

- Use British English spelling (e.g., "colour", "analyse", "organisation", "behaviour") **only in prose and explanations**. Use American spelling in code, variable names, function names, API calls, library references, and any context where British spelling could cause errors or inconsistency with established conventions.

## Autonomy & Decision Making

- **Medium autonomy**: Proceed with routine work, but ask before significant changes (refactors, architectural decisions, updates and changes or direction, deletions of substantial code).
- **Always ask** when requirements are ambiguous or underspecified—don't guess on important decisions. For low-stakes routine work, make reasonable assumptions and mention them to me.

## Simplicity First (Occam's Razor)

- **Minimum viable solution**: Choose the cleanest approach that solves the stated problem.
- **No over-engineering**: Avoid premature abstractions, hypothetical features, or unnecessary complexity.
- See `~/.claude/rules/simplicity-first.md` for detailed principles.

## Documentation

- **Avoid .md bloat** - do not create endless update/report .md files in the project repo.
- See ~/.claude/rules/no-unnecessary-files.md.
- **CLAUDE.md exclusion** - use `.git/info/exclude` for project CLAUDE.md files, not `.gitignore`. See ~/.claude/rules/git-exclude.md.

## Git Workflow

-  Use **feature branches + squash merge** workflow:
    1. Create feature branch from main (`feature/*`, `fix/*`, etc.)
    2. Commit freely during development (WIP, notes - relaxed conventions)
    3. When done, use `/squash-merge` to squash merge to main with a clean conventional commit
    4. Delete the feature branch
- See ~/.claude/rules/git-workflow.md.

**Commands:**
- `/commit` - Create commits (relaxed on branches, strict on main)
- `/squash-merge` - Complete a feature branch via squash merge to main

See `~/.claude/rules/git-commits.md` for commit conventions.

## Code Style

Use **deterministic tools** for code quality enforcement, not manual LLM review:
- **Python**: See `rules/python-standards.md`