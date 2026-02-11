# Quick Task 004: Fix UAT Deploy Provenance + Project Wizard

Closes two remaining UAT gaps from v2.0-integrated-UAT.md:

## Plans

| Plan | Gap | Severity | Files |
|------|-----|----------|-------|
| 004-01 | Deploy output missing source file paths (test 12) | minor | lib/symlinks.sh, plugins/claude/deploy.sh |
| 004-02 | Project-configs wizard broken (test 13) | major | dotconfigs, plugins/claude/project.sh, plugins/claude/templates/settings/hooks.json |

## Root Causes

**004-01:** All deploy echo statements use display name only, never print source path.

**004-02:** Three sub-issues:
1. `cmd_project_configs` all-plugins mode uses `while read < <(discover)` which consumes stdin, starving wizard_yesno of terminal input
2. CLAUDE.md builder creates hardcoded boilerplate instead of assembling from user's CLAUDE_MD_SECTIONS
3. hooks.json template references `$CLAUDE_PROJECT_DIR/plugins/claude/hooks/` instead of `.claude/hooks/`

## Wave Structure

Both plans are Wave 1 (independent, no shared files).
