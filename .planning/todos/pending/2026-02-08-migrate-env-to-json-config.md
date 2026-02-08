---
created: 2026-02-08T17:50
title: Migrate from .env to JSON config files
area: tooling
files:
  - .env
  - .env.example
  - plugins/claude/setup.sh
  - plugins/git/setup.sh
  - plugins/claude/deploy.sh
  - plugins/git/deploy.sh
---

## Problem

Current configuration uses `.env` files with KEY=VALUE pairs for both global and project-level config. This limits structure (no nesting, no arrays, no types) and requires shell `source` parsing. A JSON-based config would allow richer structure, better tooling support, and consistency with `.dotconfigs.json` which already exists for project metadata.

Proposed architecture:
- **Project config:** `.dotconfigs/config.json` in project repo root — read by dotconfigs to apply project-level settings
- **Global config:** `dotconfigs/config.json` in the dotconfigs repo — deploy reads this to apply global settings
- Both follow same schema, project overrides global

## Solution

TBD — future phase. Would require:
- Define JSON config schema
- Migrate setup wizards to write JSON instead of .env
- Migrate deploy scripts to read JSON instead of sourcing .env
- Migration path for existing .env users
- Consider `jq` dependency or pure-bash JSON parsing
