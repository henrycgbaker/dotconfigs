# Git Exclusion Rules for CLAUDE.md

## Per-Project Exclusion (Preferred)

Use `.git/info/exclude` for project-specific CLAUDE.md files instead of `.gitignore`.

**Rationale:**
- `.gitignore` is tracked and shared - not appropriate for personal documentation
- `.git/info/exclude` is local-only, like global gitignore but per-repository
- Keeps project documentation private without polluting the repo's gitignore

## Setup for New Projects

When starting work on a new project:

```bash
# Add CLAUDE.md exclusions to .git/info/exclude
echo "CLAUDE.md" >> .git/info/exclude
echo "claude_*.md" >> .git/info/exclude
```

Or manually edit `.git/info/exclude` to include:

```gitignore
# Personal Claude documentation (local only)
CLAUDE.md
claude_*.md
```

## Global vs Local Exclusions

| File | Purpose | Tracked? | Scope |
|------|---------|----------|-------|
| `~/.gitignore_global` | User-wide patterns (OS files, editor config) | No | All repos |
| `.gitignore` | Project patterns (build artifacts, deps) | **Yes** | Shared with team |
| `.git/info/exclude` | Personal patterns (notes, local tools) | No | This repo only |

**CLAUDE.md belongs in `.git/info/exclude`** because:
- It's personal documentation, not a project requirement
- Different users may or may not use Claude
- Should not appear in project's tracked .gitignore

## Automation

When Claude creates a CLAUDE.md in a new project, it should automatically add the exclusion rule to `.git/info/exclude`.

## Verification

Check what's excluded:

```bash
# Test if CLAUDE.md would be ignored
git check-ignore -v CLAUDE.md

# Should show:
# .git/info/exclude:1:CLAUDE.md    CLAUDE.md
```
