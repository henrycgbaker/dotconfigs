---
phase: 03-settings-hooks-deploy-skills
plan: 01
subsystem: settings-templates
tags: [settings, permissions, templates, security]

requires:
  phases: [01, 02]
  rationale: "Built on Phase 1 foundation (hooks, CLAUDE.md) and Phase 2 optimisation"

provides:
  - Global settings.json with security deny/ask rules
  - Project settings templates (base/python/node)
  - Hooks configuration templates (default/strict/permissive)

affects:
  - phase: 03
    plan: 02
    reason: "deploy.sh will use these templates to scaffold projects"
  - phase: 03
    plan: 03
    reason: "Hooks implementation will reference hooks.conf templates"

tech-stack:
  added: []
  patterns:
    - "Permission-based security model for file access"
    - "Template-based project scaffolding"

key-files:
  created:
    - settings.json
    - templates/settings/base.json
    - templates/settings/python.json
    - templates/settings/node.json
    - templates/hooks-conf/default.conf
    - templates/hooks-conf/strict.conf
    - templates/hooks-conf/permissive.conf
  modified: []

decisions:
  - id: SETT-ENV-ASK
    what: ".env files trigger ask prompt, not deny"
    why: "Strict deny was annoying in practice (per user decision)"
    impact: "Users get prompted before Claude reads .env files"
  - id: SETT-DENY-BUGS
    what: "Shipped deny rules despite Claude Code bugs #6699/#8961"
    why: "Rules currently ineffective but future-proofing for when bugs are fixed"
    impact: "Security layer in place, will activate when bugs resolved"

metrics:
  duration: "1.1 minutes"
  tasks: 2
  commits: 2
  completed: 2026-02-06
---

# Phase 03 Plan 01: Settings & Templates Summary

Settings.json permission model and all configuration templates for deploy.sh scaffolding

## What Was Delivered

Created the global settings.json security layer and complete template library for project scaffolding:

**Global settings.json updates:**
- Deny rules for *.pem, *credentials*, *secret*, .ssh directories
- Ask rules for .env files (moved from deny per user preference)
- Allow rules extended with npm/npx/node for Node.js projects
- Preserved existing allow rules (git, ruff, pytest, pip, python, docker, nvidia-smi)

**Project settings templates:**
- base.json: Minimal security rules (deny pem/credentials/secret, ask for .env)
- python.json: Python-specific allows (ruff, pytest, pip, python) + env vars
- node.json: Node-specific allows (npm, npx, node, pnpm)

**Hooks configuration templates:**
- default.conf: Sensible defaults (conventional commits, branch protection=warn, ruff enabled)
- strict.conf: Enforcement mode (branch protection=block)
- permissive.conf: Relaxed mode (no conventional commits, no branch protection)

All templates are valid JSON/shell and ready for deploy.sh to use when scaffolding projects.

## Task Commits

| Task | Description | Commit | Files |
|------|-------------|--------|-------|
| 1 | Update global settings.json | f8da4de | settings.json |
| 2 | Create settings and hooks-conf templates | 3ccdd05 | templates/settings/*.json, templates/hooks-conf/*.conf |

## Decisions Made

**SETT-ENV-ASK: .env files as ask, not deny**
User feedback indicated strict deny was annoying in practice. Changed .env and .env.* patterns from deny to ask, allowing prompt-based access rather than hard blocking.

**SETT-DENY-BUGS: Ship despite known bugs**
Claude Code issues #6699 and #8961 mean deny rules are currently ineffective. Shipped anyway for future-proofing — when bugs are fixed, security layer will automatically activate.

## Deviations from Plan

None — plan executed exactly as written.

## Technical Notes

**Permission model structure:**
- deny: Hard blocks for sensitive files (certificates, credentials, secrets)
- ask: Prompts for environment files (allows informed access)
- allow: Pre-approved commands (git, python, npm, docker, etc.)

**Template merge strategy:**
Base settings are applied first, then language-specific overlays merge in their allow rules and env vars. This enables deploy.sh to build complete settings.json files from composable pieces.

**Hooks.conf design:**
Shell-sourceable configuration files that deploy.sh can copy and hooks can source. Variables like BRANCH_PROTECTION and CONVENTIONAL_COMMITS control hook behaviour without code changes.

## Verification Results

All verification checks passed:
- settings.json validates as JSON
- All template JSON files validate
- All hooks.conf files source cleanly in bash
- Deny rules include pem/credentials/secret patterns
- .env patterns in ask, not deny
- Template count: 6 new files created

## Dependencies for Next Plans

**Blocks:**
- Plan 03-02 (deploy.sh): Requires these templates to scaffold projects
- Plan 03-03 (hooks): Requires hooks.conf templates for configuration

**Provides:**
- Global security model for all Claude Code sessions
- Reusable templates for consistent project setup
- Configuration presets for flexible hook behaviour

## Next Phase Readiness

Ready for Plan 03-02 (deploy.sh implementation). All templates are in place and validated. No blockers.

## Self-Check: PASSED
