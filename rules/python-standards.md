# Python Standards

> Applied when working with Python files.

## Formatting
- Ruff as formatter (100 char line length)
- Run `ruff format` and `ruff check --fix` before committing

## Type Hints
- Required for all public function signatures
- Use Python 3.10+ syntax: `list[str]` not `List[str]`
- Use `X | None` not `Optional[X]`
yes
## Docstrings
- Google-style for complex functions
- Brief one-liner for simple/obvious functions
- Include Args, Returns, Raises sections where helpful

## Imports
- Sort with isort/ruff (stdlib, third-party, local)
- Prefer explicit imports over `from x import *`

## Style
- Prefer `pathlib.Path` over `os.path`
- Use f-strings for formatting
- Use context managers for resource handling
- Avoid mutable default arguments

## Tooling (Deterministic Enforcement)

Use automated tools rather than manual review. Pre-commit hook enforces these automatically.

**Required Commands:**
```bash
ruff format .          # Format all files (100 char line length)
ruff check --fix .     # Fix linting issues
```

**Run Before Commit:**
- Hook auto-runs on `git commit` (via pre-commit hook)
- Or run manually: `ruff format && ruff check --fix`
- Fixes are idempotent and deterministic

**No Manual Style Review:**
- Don't ask Claude to check code style
- Don't manually review formatting
- Let tools handle it—they're consistent and fast
