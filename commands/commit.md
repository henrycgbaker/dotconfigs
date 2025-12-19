---
description: Help create a well-formatted commit
allowed-tools: Bash, Read
argument-hint: [optional message]
---

# Commit Helper

Help create a well-formatted conventional commit.

## Process

### 1. Check Status
```bash
git status
git diff --stat
git diff --cached --stat
```

### 2. Analyze Changes
- Identify what type of change (feat/fix/docs/refactor/test/chore)
- Summarize the change in one line
- Note any breaking changes

### 3. Stage Files
If needed, stage relevant files:
```bash
git add <files>
```

### 4. Create Commit
Format: `type: description`

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation
- `refactor`: Code refactor
- `test`: Tests

*NB: also fine to have no `type` if it's a miscellaneous / 'chore'-style task.*

Example:
```bash
git commit -m "feat: add GPU monitoring command"
```

### 5. Verify
```bash
git log -1 --oneline
```

## Notes
- Keep subject under 72 characters
- Use imperative mood ("Add" not "Added")
- No AI attribution (enforced by hooks)
- Breaking changes: use `!` suffix (e.g., `feat!: change API`)

If $ARGUMENTS provided, use as commit message hint.
