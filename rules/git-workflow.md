# Git Worflow standards

- new work should be done on a branch, not main.
- commit freely to branches, then squash merge onto main when a large chunk of validated work complete. Commit history on main should be clean and easy to follow, not many micro-commits

## Branching Strategy (GitHub Flow)

| Branch | Purpose | Example |
|--------|---------|---------|
| `main` | Production-ready, always deployable | - |
| `feature/*` | New features | `feature/add-user-auth` |
| `fix/*` | Bug fixes | `fix/login-validation` |
| `docs/*` | Documentation | `docs/api-reference` |
| `refactor/*` | Code refactoring | `refactor/simplify-auth` |

Branch type prefixes are optional - plain descriptive names are also fine.

## Operational Workflow

### Before Any Git Operation
```bash
git status                    # Current state
git log --oneline -10         # Recent history
git branch --show-current     # Current branch
```

### Commit Workflow
1. Stage only related changes together
2. Write clear commit message (see `/rules/git-commits.md`)
3. Never commit secrets, credentials, or .env files
4. Run pre-commit hooks if configured

### Branch Management
1. Create branches from up-to-date main
2. Use descriptive branch names
3. Delete branches after successful merge
4. Keep branches short-lived when possible

### Merge Strategy
- **Squash merge**: Default for feature branches (1 clean commit per feature)
- **Rebase**: For keeping feature branches up-to-date with main
- **Merge commits**: Only when history preservation is explicitly needed

## Squash Merge Workflow

### Creating a Feature Branch
```bash
git checkout main && git pull
git checkout -b feature/my-feature
```

### During Development
- Commit freely (WIP, notes, experiments)
- No need to follow strict conventions on branches
- Focus on working code, not commit messages

### Completing Work (Squash to Main)
```bash
git checkout main && git pull
git merge --squash feature/my-feature
git commit -m "feat: description of feature"  # Clean conventional commit
git branch -d feature/my-feature
git push
```

> **Tip**: Use `/squash-merge` command to guide through this process interactively.

## Release Management

### Prepare Release
```bash
git checkout main && git pull origin main
git tag -a v1.2.0 -m "Release v1.2.0: Brief description"
git push origin v1.2.0
```

### Generate Release Notes
```bash
git log v1.1.0..HEAD --pretty=format:"- %s" --reverse
```

### CHANGELOG Format (Keep a Changelog)
```markdown
## [Version] - YYYY-MM-DD

### Added
### Changed
### Fixed
### Removed
```

## PR Best Practices
- Descriptive title (conventional commit format)
- Include testing checklist
- Note breaking changes prominently
- Reference related issues

## Safety Guardrails

### Never Without Explicit Request
- Force push to main/master
- Reset pushed commits
- Delete remote branches without verification
- Modify history of shared branches
- Skip pre-commit hooks

### Always Verify Before
- Merging to main
- Tagging releases
- Deleting branches
- Force operations

## Output Format

```
### Operation: [Name]
**Branch**: [current branch]
**Status**: [Success/Failed/Warning]

**Changes Made:**
- [List of changes]

**Next Steps:**
- [Suggested follow-up actions]
```