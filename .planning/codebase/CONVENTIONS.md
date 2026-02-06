# Coding Conventions

**Analysis Date:** 2026-02-06

## Naming Patterns

**Files:**
- Bash scripts: `kebab-case.sh` (e.g., `setup.sh`, `deploy-remote.sh`, `sync-project-agents.sh`)
- Python scripts: `kebab-case.py` with shebang (e.g., `post-tool-format.py`, `block-sensitive.py`)
- JavaScript scripts: `kebab-case.js` with shebang (e.g., `gsd-statusline.js`, `gsd-check-update.js`)
- Markdown documentation: `kebab-case.md` for commands/agents (e.g., `gsd-executor.md`, `execute-phase.md`)
- Configuration files: Exact names without extensions (e.g., `settings.json`, `CLAUDE.md`)

**Functions (Python):**
- `snake_case` for all function names (e.g., `get_file_path_from_input()`, `format_python_file()`, `is_sensitive()`)
- Single responsibility: Short, focused functions
- Pattern: `verb_noun()` or `is_adjective()` or `get_object()`

**Functions (JavaScript/Shell):**
- `camelCase` for JavaScript function names (e.g., `readFileSync`, `parseInput`, `handleError`)
- `snake_case` for shell function names in scripts (e.g., `backup_and_link()`)
- Avoid function definitions in shell; prefer imperative scripts with conditionals

**Variables:**
- Python: `snake_case` throughout (e.g., `file_path`, `home_dir`, `sensitive_patterns`)
- JavaScript: `camelCase` for variables (e.g., `homeDir`, `cacheFile`, `sessionId`)
- Shell: `UPPER_CASE` for exported variables/constants (e.g., `SCRIPT_DIR`, `CLAUDE_DIR`, `MODEL_PROFILE`)
- Shell: `lower_case` for local variables in functions

**Types (Python):**
- Type hints required on all public function signatures
- Use modern Python 3.10+ syntax: `str | None` instead of `Optional[str]`, `list[str]` instead of `List[str]`
- Pattern: `def function(param: type) -> return_type:`
- Examples: `def format_python_file(file_path: str) -> bool:`, `def get_file_path_from_input(tool_input: dict) -> str | None:`

**Agent/Command Names:**
- Prefix format: `gsd-<name>` for agents (e.g., `gsd-executor`, `gsd-codebase-mapper`)
- Command format: `gsd:<action>` (e.g., `gsd:execute-phase`, `gsd:map-codebase`)
- Descriptive and action-oriented

## Code Style

**Formatting:**
- Python: `ruff` (100 character line length limit)
- JavaScript: No enforced formatter; use consistent spacing (2-space indentation in examples)
- Shell: No enforced formatter; use consistent spacing (2-space indentation, `set -e` at script start)
- Markdown: Consistent heading levels, code fence formatting

**Linting:**
- Python: `ruff check` enforces code quality
- Tools are deterministic; never ask Claude to manually review style
- Auto-fix enabled: `ruff format && ruff check --fix` before commit

**Pre-commit Hooks:**
Location: `.git/hooks/` (installed via `setup.sh`)
- Python files: Auto-format and fix with ruff
- Pre-commit hook runs on `git commit` (non-blocking)
- Post-tool-use hook auto-formats after Write/Edit operations

## Import Organization

**Python Order:**
1. Standard library imports (`json`, `sys`, `subprocess`, `pathlib`, `re`)
2. Third-party imports (minimal; `ruff` not imported, only called via subprocess)
3. Local/relative imports (rare in this codebase)

Pattern from `post-tool-format.py`:
```python
import json
import subprocess
import sys
from pathlib import Path
```

**JavaScript/Node.js Order:**
1. Core Node modules (`fs`, `path`, `os`, `child_process`)
2. No external dependencies in hooks
3. All imports as `const x = require('module')`

Pattern from `gsd-statusline.js`:
```javascript
const fs = require('fs');
const path = require('path');
const os = require('os');
```

**Shell:**
- No import system; source with `. file.sh`
- Declare dependencies at top of script
- Used in: `setup.sh`, `deploy-remote.sh`

**No Path Aliases:**
This codebase does not use TypeScript aliases or path mappings.

## Error Handling

**Python Patterns:**
- Graceful degradation: Try-except with specific exceptions, fail open where safe
- Pattern: Exit code 0 (success) for non-blocking hooks; non-zero for failures
- Examples from `post-tool-format.py`:
  ```python
  try:
      subprocess.run(["ruff", "format", file_path], capture_output=True, timeout=30)
      return True
  except FileNotFoundError:
      return True  # Ruff not installed, skip silently
  except subprocess.TimeoutExpired:
      print("Ruff formatting timed out", file=sys.stderr)
      return False
  except Exception as e:
      print(f"Ruff formatting error: {e}", file=sys.stderr)
      return False
  ```

- Pattern: JSON parsing with fallback
  ```python
  try:
      data = json.load(sys.stdin)
  except json.JSONDecodeError:
      return 0  # Skip on parse error (fail open)
  ```

**JavaScript Patterns:**
- Silent fail on errors; don't break the application
- Pattern: Catch-all with no logging (statusline hook must not break display)
- Example from `gsd-statusline.js`:
  ```javascript
  try {
      const data = JSON.parse(input);
      // ... process data
  } catch (e) {
      // Silent fail - don't break statusline on parse errors
  }
  ```

- Pattern: Optional chaining and nullish coalescing
  ```javascript
  const model = data.model?.display_name || 'Claude';
  const remaining = data.context_window?.remaining_percentage;
  ```

**Shell Patterns:**
- Set error mode: `set -e` at script start (exit on first error)
- Pattern: Function calls with conditional execution
  ```bash
  if [ -e "$dest" ] && [ ! -L "$dest" ]; then
      echo "Backing up existing $name to $name.backup"
      mv "$dest" "$dest.backup"
  fi
  ```

- Pattern: Use `[ -f file ]` for file checks, `[ -d dir ]` for directory checks

**Validation:**
- Validate at system edges only (file I/O, CLI input, subprocess output)
- Trust internal code
- Pattern: Exit early on invalid conditions
  ```python
  if not file_path:
      return 0  # Skip if no file path
  if not Path(file_path).exists():
      return 0  # Skip if file doesn't exist
  ```

## Logging

**Framework:**
- Python: `print()` to stdout, errors to `sys.stderr`
- JavaScript: `console.log()` for normal output, no console output in statusline hook
- Shell: `echo` for output, error messages to stdout/stderr

**Patterns:**
- Silent failures for non-critical operations (hooks)
- Pattern: Only log errors that matter
  ```python
  print(f"Ruff formatting error: {e}", file=sys.stderr)
  ```

- Pattern: Descriptive messages with context
  ```bash
  echo "Installing dotclaude configuration..."
  echo "Source: $SCRIPT_DIR"
  echo "Target: $CLAUDE_DIR"
  ```

- Pattern: Skip messages when operations are redundant
  ```bash
  echo "⊘ settings.json exists (kept local version)"
  ```

## Comments

**When to Comment:**
- Explain WHY, not WHAT (code shows what)
- Non-obvious logic: regex patterns, complex conditionals, performance decisions
- Trade-offs and alternatives considered

**Docstrings/JSDoc:**
- Python: Brief one-liner for simple functions, Google-style for complex
  ```python
  def is_sensitive(file_path: str) -> bool:
      """Check if a file path matches any sensitive pattern."""
  ```

  ```python
  def main() -> int:
      """Format Python files after Write/Edit operations.

      Only processes .py files to avoid unnecessary processing.
      Exit codes:
      - 0: Success (or non-Python file, skipped)
      - Non-zero: Formatting failed (non-blocking)
      """
  ```

- Shell scripts: File-level comment explaining purpose
  ```bash
  #!/bin/bash
  # setup.sh - Install dotclaude configuration via symlinks
  set -e
  ```

- JavaScript: File-level comments for tools and parameters
  ```javascript
  // Claude Code Statusline - GSD Edition
  // Shows: model | current task | directory | context usage
  ```

## Function Design

**Size:**
- Small, focused functions (10-30 lines typical)
- Single responsibility principle
- Examples: `is_sensitive()` (4 lines), `get_file_path_from_input()` (6 lines), `format_python_file()` (19 lines)

**Parameters:**
- Keep to 2-3 parameters max
- Use descriptive names
- Pattern: `function(required_param: type, optional_param: type | None = None) -> ReturnType:`

**Return Values:**
- Boolean for predicates and checks: `is_sensitive()`, `format_python_file()`
- Integer for exit codes: `main()` returns 0 (success) or 2 (block)
- String or None for optional extraction: `get_file_path_from_input()`
- JSON/dict for complex data

## Module Design

**Exports:**
- Python: All public functions defined; no `__all__` export lists used
- Entry point is `if __name__ == "__main__":` calling `main()`
- JavaScript: Single main execution block (not modular)

**Barrel Files:**
- Not used in this codebase
- Each file is independent

**File Organization:**
- One responsibility per file
- Clear entry points: `main()` function
- Related helpers grouped together (e.g., input extraction before main logic)

## Agent Documentation Patterns

**Frontmatter (YAML):**
```yaml
---
name: agent-name
description: Clear, concise description
tools: Read, Write, Edit, Bash, Grep, Glob  # Comma-separated
color: color-name
---
```

**Structure:**
- `<role>` - What the agent does and why
- `<process>` or `<execution_flow>` - Step-by-step instructions with sub-steps
- `<templates>` or `<rules>` - Reusable patterns
- `<critical_rules>` - Must-follow constraints
- Code blocks: Use language specifiers (bash, python, typescript, etc.)

**Language in Agent Docs:**
- Imperative mood for instructions: "Execute tasks", "Check for errors", "Read the plan"
- Second person where applicable: "You will NOT be resumed"
- Prescriptive, not descriptive

## Markdown Documentation

**Heading Hierarchy:**
- `#` - Page title
- `##` - Major sections
- `###` - Subsections
- `####` - Details (rare)

**Code Examples:**
- Use language-specific fence markers
- Show actual patterns from codebase when possible
- Include imports and context

**Tables:**
- Used for comparison and reference (model lookup, phase types, etc.)
- Consistent column alignment

---

*Convention analysis: 2026-02-06*
