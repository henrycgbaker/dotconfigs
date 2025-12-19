---
name: dependency-auditor
description: Audit Python dependencies for security vulnerabilities and outdated packages. Use for security scanning, dependency updates, or compliance checks.
allowed-tools: Bash, Read, Edit
---

# Dependency Auditor

Audit and manage Python dependencies for security and updates.

## When to Use
- Security vulnerability scanning
- Checking for outdated packages
- Before releases or deployments
- Compliance audits

## Process

### 1. Security Scan
```bash
# Using pip-audit (recommended)
pip-audit

# Specific requirements file
pip-audit -r requirements.txt

# JSON output for CI
pip-audit --format json
```

### 2. Check Outdated
```bash
# List outdated packages
pip list --outdated

# Show available versions
pip index versions <package>
```

### 3. Analyze Dependencies
```bash
# Show dependency tree
pip show <package>

# Full dependency tree (install pipdeptree)
pipdeptree

# Check for conflicts
pip check
```

### 4. Update Dependencies
```bash
# Update single package
pip install --upgrade <package>

# Update all (careful!)
pip list --outdated --format=freeze | grep -v '^\-e' | cut -d = -f 1 | xargs -n1 pip install -U
```

## Security Scanning

### Known Vulnerability Databases
- PyPI Advisory Database
- GitHub Security Advisories
- OSV (Open Source Vulnerabilities)

### Common Vulnerabilities
- SQL injection in ORMs
- XML parsing vulnerabilities
- Deserialization issues
- Path traversal in file handling

### Fix Strategies
1. **Update**: Install patched version
2. **Replace**: Use alternative package
3. **Mitigate**: Add protective code
4. **Accept**: Document risk if unavoidable

## Best Practices

### Pin Versions
```
# requirements.txt
package==1.2.3        # Exact version
package>=1.2.3,<2.0   # Compatible range
```

### Lock Files
```bash
# Generate lock file
pip-compile requirements.in -o requirements.txt

# Update lock file
pip-compile --upgrade requirements.in
```

### Regular Audits
- Run `pip-audit` in CI pipeline
- Schedule weekly dependency reviews
- Subscribe to security advisories for critical deps

## pyproject.toml Updates

When updating dependencies in pyproject.toml:
```toml
[project]
dependencies = [
    "package>=1.2.3,<2.0",  # Add version constraints
]

[project.optional-dependencies]
dev = [
    "pytest>=7.0",
    "ruff>=0.1",
]
```

## CI Integration

```yaml
# GitHub Actions example
- name: Audit dependencies
  run: |
    pip install pip-audit
    pip-audit --strict
```
