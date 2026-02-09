---
created: 2026-02-08T20:10
title: Decide whether settings.json should be configurable in wizard
area: ui
files:
  - plugins/claude/templates/settings.json
  - plugins/claude/setup.sh
---

## Problem

Currently Step 2 of the Claude setup wizard just asks "Deploy settings.json? Y/n" without allowing users to configure the permission rules inside it. The template is pre-built with sensible defaults (deny secrets, auto-format Python with Ruff).

Question: Should the wizard offer interactive configuration of settings.json rules, or keep it simple (just deploy the defaults) and document that users must manually edit .env or the deployed file if they want custom rules?

## Solution

TBD — requires UX decision:

**Option A:** Keep wizard simple (current state). Document clearly that settings.json is pre-built and can be customized after deploy by editing the file directly or .env CLAUDE_* variables.

**Option B:** Add Step 2b to wizard for interactive settings.json configuration (deny rules, formatting rules, etc.). More complex wizard but higher initial control.

Decision should balance:
- Simplicity of wizard flow
- User expectation for control
- Documentation clarity on how to customize after deploy
