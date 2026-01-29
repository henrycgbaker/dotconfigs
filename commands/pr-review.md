---
description: Review current branch changes for PR readiness
allowed-tools: Bash, Read, Grep, Glob
---

# PR Review

Review current branch changes against main for PR readiness.

## Process

### 1. Gather Context
```bash
# Current branch and status
git branch --show-current
git status

# Changes vs main
git log main..HEAD --oneline
git diff main...HEAD --stat
```

### 2. Review Changes
- Read modified files
- Check for code quality issues
- Look for security concerns
- Verify test coverage

### 3. Checklist

**Code Quality**:
- [ ] Code follows project style (Ruff passing) - use deterministic tools for this
- [ ] Type hints present where needed
- [ ] No obvious bugs or logic errors
- [ ] No hardcoded secrets or credentials

**Testing**:
- [ ] Tests added for new functionality
- [ ] Existing tests still pass
- [ ] Edge cases considered

**Documentation**:
- [ ] Code comments where needed
- [ ] Docstrings for public APIs
- [ ] README updated if needed
- [ ] local / modular CLAUDE updated if needed 

**Git Hygiene**:
- [ ] Commits follow conventional format
- [ ] No merge commits from main
- [ ] Commit messages are meaningful

### 4. Output Format

Provide:
1. **Summary**: What this PR does (1-2 sentences)
2. **Changes**: Key files and what changed
3. **Concerns**: Any issues found
4. **Suggestions**: Improvements before merging
5. **Ready?**: Yes/No with reasoning
