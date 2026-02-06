# Testing Patterns

**Analysis Date:** 2026-02-06

## Test Framework

**Status:** No automated test framework configured

This is a tool/framework codebase for Claude agents and commands, not a traditional application. Testing occurs through:
- Manual validation of agent behavior via Claude Code
- Hook validation through real git operations
- Command validation through actual GSD workflow execution
- Integration testing via end-to-end project phases

**Why No Unit Tests:**
- Primary artifacts are Markdown documentation files (agent definitions, command specs)
- Python/JavaScript scripts are minimal, focused hooks with clear dependencies
- Testing these requires Claude environment or git integration (not automatable with standard frameworks)

## Test File Organization

**Test Location:**
No dedicated test directory exists. Hooks and scripts are tested in context:
- `hooks/` - Scripts tested through actual git operations
- `agents/` - Agent definitions tested through Claude Code execution
- `commands/` - Commands tested through `/gsd:*` command invocation

**Naming:**
Hook scripts follow naming pattern: descriptive name + language extension
- `post-tool-format.py` - Python post-tool hook
- `block-sensitive.py` - Python pre-tool hook
- `gsd-statusline.js` - JavaScript status display
- `gsd-check-update.js` - JavaScript version check

## Test Structure

**Python Script Pattern:**
```python
#!/usr/bin/env python3
"""Module docstring explaining purpose and exit codes."""

import json
import sys
from pathlib import Path

def helper_function() -> type:
    """Helper docstring."""
    # Implementation

def main() -> int:
    """Main entry point. Returns exit code."""
    try:
        # Core logic
        return 0
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1

if __name__ == "__main__":
    sys.exit(main())
```

**JavaScript Script Pattern:**
```javascript
#!/usr/bin/env node
// Single-responsibility comment

const fs = require('fs');
const path = require('path');

// Setup constants
const homeDir = os.homedir();
const configFile = path.join(homeDir, '.claude', 'config.json');

// Main execution block
try {
    let input = '';
    process.stdin.on('data', chunk => input += chunk);
    process.stdin.on('end', () => {
        // Process input
        const result = JSON.parse(input);
        // Perform operation
        process.stdout.write(output);
    });
} catch (e) {
    // Silent fail or log to stderr
}
```

**Shell Script Pattern:**
```bash
#!/bin/bash
# Script description
set -e  # Exit on error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOME_DIR="$HOME"

# Helper functions
helper_function() {
    local param="$1"
    if [ condition ]; then
        echo "Action"
    fi
}

# Main execution
echo "Starting operation..."
helper_function "value"
echo "Completed"
```

## Validation Patterns

**Python Hook Validation:**
Test by running the hook in the actual environment it will be used:

1. **Pre-tool hook validation** (blocks operations):
   ```bash
   echo '{"tool_name":"Read","tool_input":{"file_path":".env"}}' | python3 hooks/block-sensitive.py
   # Should return exit code 2 (blocked)
   ```

2. **Post-tool hook validation** (formats files):
   ```bash
   echo '{"tool_name":"Write","tool_input":{"file_path":"test.py"}}' | python3 hooks/post-tool-format.py
   # Should return exit code 0 (success)
   ```

**JavaScript Hook Validation:**
Test by providing stdin JSON and checking stdout:

1. **Status display validation**:
   ```bash
   echo '{"model":{"display_name":"Claude"},"workspace":{"current_dir":"/home"},"context_window":{"remaining_percentage":50}}' | node hooks/gsd-statusline.js
   # Should output formatted status line
   ```

2. **Version check validation**:
   ```bash
   node hooks/gsd-check-update.js
   # Should create cache file with version info
   ```

**Shell Script Validation:**
Test by running and checking for expected artifacts:

1. **Setup script validation**:
   ```bash
   bash setup.sh
   # Should create symlinks in ~/.claude/
   # Should not fail on existing files (backups them)
   ```

2. **Deployment script validation**:
   ```bash
   bash deploy-remote.sh user@host
   # Should sync files via rsync or git
   ```

## Mocking Patterns

**Python:** No mocking library used. Instead:

**File system mocking:**
- Use `Path.exists()` checks before operations
- Skip operations gracefully if file doesn't exist
- Pattern from `post-tool-format.py`:
  ```python
  if not Path(file_path).exists():
      return 0  # Skip if file doesn't exist after Write/Edit
  ```

**Subprocess mocking:**
- Catch `FileNotFoundError` when tool isn't installed (e.g., ruff)
- Fail gracefully instead of raising error
- Pattern from `post-tool-format.py`:
  ```python
  try:
      subprocess.run(["ruff", "format", file_path], capture_output=True, timeout=30)
      return True
  except FileNotFoundError:
      return True  # Ruff not installed, skip silently (non-blocking hook)
  ```

**JavaScript:** No mocking. Instead:

**File system checks:**
- Use `fs.existsSync()` before reading
- Catch errors and continue silently
- Pattern from `gsd-statusline.js`:
  ```javascript
  if (fs.existsSync(todosDir)) {
      try {
          const files = fs.readdirSync(todosDir);
          // Process files
      } catch (e) {
          // Silently fail on file system errors
      }
  }
  ```

**Process spawning:**
- Use `spawn()` with `stdio: 'ignore'` for background operations
- Don't wait for result; let fail silently
- Pattern from `gsd-check-update.js`:
  ```javascript
  const child = spawn(process.execPath, ['-e', code], {
      stdio: 'ignore',
      windowsHide: true
  });
  child.unref();  // Don't wait for completion
  ```

## Input Validation

**Python Pattern:**
Extract and validate in dedicated function:
```python
def get_file_path_from_input(tool_input: dict) -> str | None:
    """Extract file path from tool input."""
    for key in ["file_path", "path", "file"]:
        if key in tool_input:
            return tool_input[key]
    return None  # Return None if not found
```

Then check before use:
```python
file_path = get_file_path_from_input(tool_input)
if not file_path:
    return 0  # Skip if no path found
```

**JavaScript Pattern:**
Optional chaining for safe access:
```javascript
const model = data.model?.display_name || 'Claude';
const remaining = data.context_window?.remaining_percentage;
if (remaining != null) {
    // Safe to use remaining
}
```

## Test Coverage

**Coverage Requirements:** None enforced

This codebase focuses on:
- Agent correctness (validated through execution traces)
- Hook functionality (validated through git integration)
- Command behavior (validated through GSD workflow testing)

Code coverage tools (pytest, istanbul) are not applicable here.

## Test Types

**Hook Validation (Python):**
Each hook is tested by:
1. Providing valid input JSON on stdin
2. Checking exit code and side effects
3. Verifying graceful failure on missing dependencies

Files to test:
- `hooks/post-tool-format.py` - Auto-format Python files after Write/Edit
- `hooks/block-sensitive.py` - Block access to sensitive files

**Hook Validation (JavaScript):**
Each hook is tested by:
1. Providing JSON input on stdin
2. Checking stdout output
3. Verifying no crashes on malformed input

Files to test:
- `hooks/gsd-statusline.js` - Render status display
- `hooks/gsd-check-update.js` - Check for updates in background

**Agent Behavior Validation:**
Agents are tested through Claude Code execution:
1. Spawn agent with test plan
2. Verify execution follows process
3. Check artifacts (commits, SUMMARY.md, etc.)

Agents in `agents/` directory:
- `gsd-executor.md` - Execute plans atomically
- `gsd-codebase-mapper.md` - Map codebase and write docs
- `gsd-planner.md` - Create implementation plans
- `gsd-phase-researcher.md` - Research phase context

**Command Validation:**
Commands are tested through user invocation:
1. Run `/gsd:command` in Claude Code
2. Verify output and side effects
3. Check state file updates

Commands in `commands/gsd/` directory:
- `execute-phase.md` - Execute all plans in phase
- `plan-phase.md` - Create phase implementation plan
- `map-codebase.md` - Analyze codebase

## Common Patterns

**Stdin/Stdout Testing (Python):**
```bash
# Test JSON input handling
echo '{"tool_name":"Read","tool_input":{"file_path":"test.py"}}' | python3 script.py
echo "Exit code: $?"
```

**Stdin/Stdout Testing (JavaScript):**
```bash
# Test JSON input handling and output
echo '{"key":"value"}' | node script.js > output.txt
cat output.txt
```

**Exit Code Validation:**
```bash
# Test success
bash script.sh && echo "SUCCESS" || echo "FAILED"

# Test failure modes
script.sh; code=$?
if [ $code -eq 0 ]; then echo "Success"; elif [ $code -eq 2 ]; then echo "Blocked"; fi
```

**File Operations Testing:**
Before running hooks in git, test manually:
```bash
# Test by running hook on actual Python file
python3 hooks/post-tool-format.py < <(echo '{"tool_name":"Write","tool_input":{"file_path":"test.py"}}')
python test.py  # Verify it's valid Python
```

## Pre-commit Hook Testing

**Hook Configuration:** `.git/hooks/` (installed by setup.sh)

Test the pre-commit workflow:
```bash
# Stage a Python file
git add test.py

# Commit (hooks run automatically)
git commit -m "test: commit"

# Verify file was formatted by ruff
git diff HEAD~1 test.py  # Should show formatting changes
```

## Validation Checklist

**Before Committing:**
- [ ] Python code passes: `ruff format` and `ruff check --fix`
- [ ] Shell scripts tested manually: `bash script.sh`
- [ ] JSON files valid: `python3 -m json.tool file.json`
- [ ] Markdown files follow heading hierarchy

**When Adding New Hook:**
- [ ] Hook handles JSON parse errors gracefully
- [ ] Hook returns correct exit codes (0 for success/skip, 2 for block)
- [ ] Hook doesn't crash on edge cases (missing files, invalid JSON, etc.)
- [ ] Hook tested with representative input

**When Adding New Agent:**
- [ ] Agent frontmatter valid YAML
- [ ] Agent process steps numbered clearly
- [ ] Code examples use correct language markers
- [ ] Links to referenced files are accurate

---

*Testing analysis: 2026-02-06*
