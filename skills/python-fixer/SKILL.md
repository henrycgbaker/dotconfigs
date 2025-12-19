---
name: python-fixer
description: Fix Python linting and formatting issues using Ruff. Use when Python files have style violations, import sorting issues, or need auto-fixing.
allowed-tools: Bash, Read, Edit
---

# Python Linter/Fixer

Automatically fix Python linting and formatting issues using Ruff.

## When to Use
- Python file has linting errors
- Code style needs fixing (formatting, imports)
- After writing/editing Python code that may have issues

## Process

### 1. Check for Issues
```bash
ruff check --output-format=text <file>
```

### 2. Auto-fix Fixable Issues
```bash
ruff check --fix <file>
```

### 3. Format Code
```bash
ruff format <file>
```

### 4. Verify
```bash
ruff check <file>
ruff format --check <file>
```

## Common Fixes
- Import sorting (I001)
- Unused imports (F401)
- Line length (E501) - via formatting
- Trailing whitespace
- Missing newlines at EOF
- Upgrade syntax to Python 3.10+ (UP)

## Configuration
Ruff is configured via `pyproject.toml` or `ruff.toml` in the project root.
