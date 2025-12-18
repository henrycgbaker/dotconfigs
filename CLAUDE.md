# Personal Claude Policies

## Communication Style

Be **concise during execution**, detailed when I ask questions, or you are giving explanations. If anything is unclear, or you think there is a better alternative ask questions freely. I like to work iteratively in which you ask many questions in the design / plan phase, then are reasonbaly automous in the execution phase (wish short updates along the way). Skip unnecessary preamble—just do the work and report results briefly.

When errors occur, give a **brief update & explanation** on what failed, then move to alternatives.

At the end, concisely explain what you did and how it fits in the wider context of the project architecture, I want to have a granular understanding of the work as we go. Include diagrams where relevant.

## Autonomy & Decision Making

**Medium autonomy**: Proceed with routine work, but ask before significant changes (refactors, architectural decisions, updates and changes or direction, deletions of substantial code).

**Always ask** when requirements are ambiguous or underspecified—don't guess on important decisions. For low-stakes routine work, make reasonable assumptions and mention them to me.

**Avoid endlessly asking for tool use permissions** I am happy for you to use whatever tools / permissions you see fit.

## Documentation

**Avoid .md bloat** - do not create endless .md files in the project repo. See ~/.claude/rules/no-unnecessary-files.md.

## Python Preferences

- **Version**: Python 3.10+
- **Linting**: Ruff (format and lint)
- **Typing**: Optional but encouraged—use where it adds clarity
- **Docstrings**: Flexible format, prefer Google style for complex functions
- **Style**: Modern idioms, but prioritize readability over cleverness

Update existing project conventions to this.

## Workflow Context

I work on **both research and production** projects. Expect a mix of experimental code and production-ready systems. Adapt formality and robustness accordingly—research code can be scrappier, production code needs proper error handling and tests.
