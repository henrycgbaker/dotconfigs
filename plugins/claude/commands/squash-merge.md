---
description: Squash merge current branch to main
allowed-tools: Bash, Read
argument-hint: [optional commit message]
---

# Squash Merge Helper

Complete a feature branch by squash merging to main.

## Process

### 1. Pre-flight Checks
```bash
# Verify not on main
git branch --show-current

# Check for uncommitted changes
git status

# Show commits that will be squashed
git log main..HEAD --oneline
```

If on main, abort - nothing to squash merge.

### 2. Review Changes
```bash
# Summary of what will be merged
git diff main...HEAD --stat
```

### 3. Switch to Main and Pull
```bash
git checkout main
git pull
```

### 4. Squash Merge
```bash
git merge --squash <branch-name>
```

### 5. Create Clean Commit
Help craft a conventional commit message summarising all the squashed changes:

```bash
git commit -m "type: description"
```

**Commit message guidance:**
- Use conventional commit format (feat/fix/docs/refactor/test)
- Subject under 72 characters, imperative mood
- Summarise the overall change, not individual commits

### 6. Cleanup
```bash
# Delete the merged branch
git branch -d <branch-name>

# Push to remote
git push
```

## Notes
- If $ARGUMENTS provided, use as commit message hint
- See CLAUDE.md Git section for commit conventions
- Use `git branch -D` if branch wasn't fully merged (force delete)
