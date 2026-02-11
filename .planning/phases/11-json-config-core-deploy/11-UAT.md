---
status: diagnosed
phase: 11-json-config-core-deploy
source: 11-01-SUMMARY.md, 11-02-SUMMARY.md, 11-03-SUMMARY.md
started: 2026-02-11T23:00:00Z
updated: 2026-02-11T23:10:00Z
---

## Current Test

[testing complete]

## Tests

### 1. Deploy All Modules
expected: Run `dotconfigs deploy --dry-run`. Output lists all 12 modules from global.json (4 claude, 3 git, 3 vscode, 2 shell) with source → target paths and method. No errors.
result: pass

### 2. Deploy Single Group
expected: Run `dotconfigs deploy claude --dry-run`. Output shows only the 4 claude modules (hooks, settings, skills, claude-md). No git/vscode/shell modules appear.
result: pass

### 3. Deploy Invalid Group
expected: Run `dotconfigs deploy nonexistent --dry-run`. Output shows "No modules found" or similar message. No crash or error.
result: pass

### 4. Paths With Spaces
expected: In the `dotconfigs deploy --dry-run` output, VS Code modules show correct target paths containing "Application Support" (with space). No quoting errors or broken paths.
result: skipped
reason: vscode source files don't exist yet (Phase 12) — parser handled paths without crash but actual symlink creation untestable

### 5. Project Init
expected: In a test project directory (any git repo), run `dotconfigs project-init`. Creates `.dotconfigs/project.json` from template. File contains source+target config entries.
result: issue
reported: "template is incomplete — missing vscode/shell keys. Should show all available groups so users can see what's available. Should be auto-generated from global.json as SSOT."
severity: minor

### 6. Project Deploy
expected: After project-init, run `dotconfigs project` from that project directory. Deploys modules from `.dotconfigs/project.json` with targets relative to the project root.
result: pass

### 7. Auto-Exclude .dotconfigs
expected: After project-init or project deploy, `.dotconfigs/` appears in the project's `.git/info/exclude` file. Running `git status` in the project does not show `.dotconfigs/` as untracked.
result: pass

### 8. Help Text
expected: Run `dotconfigs help`. Output includes the `deploy`, `project`, and `project-init` commands with brief descriptions.
result: pass

## Summary

total: 8
passed: 6
issues: 1
pending: 0
skipped: 1

## Gaps

- truth: "project-init template includes all available groups/modules from global.json"
  status: failed
  reason: "User reported: template is incomplete — missing vscode/shell keys. Should show all available groups so users can see what's available. Should be auto-generated from global.json as SSOT."
  severity: minor
  test: 5
  root_cause: "cmd_project_init copies static project.json.example (line 638 of dotconfigs). This file was hand-written with only claude and git groups. Not generated from global.json."
  artifacts:
    - path: "dotconfigs"
      issue: "cmd_project_init (line 638) uses static jq copy from project.json.example"
    - path: "project.json.example"
      issue: "Hand-written template with only claude/git — missing vscode/shell"
  missing:
    - "Generate project.json from global.json at init time, converting absolute targets to project-relative paths"
    - "Remove static project.json.example in favour of dynamic generation"
  debug_session: ""
