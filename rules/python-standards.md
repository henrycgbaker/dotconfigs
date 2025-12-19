# Python Standards

> Applied when working with Python files.

## Formatting
- Ruff as formatter (100 char line length)
- Run `ruff format` and `ruff check --fix` before committing

## Type Hints
- Required for all public function signatures
- Use Python 3.10+ syntax: `list[str]` not `List[str]`
- Use `X | None` not `Optional[X]`

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
