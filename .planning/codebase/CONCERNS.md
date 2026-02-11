# Codebase Concerns

**Analysis Date:** 2026-02-10

## Critical Issues (Blocking)

### 1. Project Config Wizard Broken — Functions Not Available in Plugin Context

**Issue:** The project-configs wizard fails to execute interactive prompts because `wizard_yesno()` and related functions from `lib/wizard.sh` are not accessible within the plugin execution context.

**Files:**
- `plugins/claude/project.sh` (lines 221, 230, 276, 314, 388, 428, 506)
- `lib/wizard.sh` (defines wizard functions)

**Problems:**
- Wizard prompts at lines 221/230/276/314/388/428/506 fall through silently or return invalid-input errors
- Functions from `lib/wizard.sh` are not sourced in the plugin's execution environment
- Plugin context does not inherit wizard functions from main dotconfigs script

**Impact:**
- Users cannot interactively configure project-level settings
- Project scaffolding produces non-functional output (broken symlinks, missing configurations)
- Deployment to new projects fails silently with garbled prompts

**Fix approach:**
- Source wizard functions in `plugins/claude/project.sh` at start of execution
- Add explicit source statement: `source "$SCRIPT_DIR/../lib/wizard.sh"` or pass via environment
- Test wizard availability before prompting with `type wizard_yesno > /dev/null || error "..."`
- Document required function sourcing in plugin architecture guidelines

---

### 2. Project CLAUDE.md Builder Uses Hardcoded Boilerplate Instead of Global Sections

**Issue:** When creating project-level CLAUDE.md, the code generates static boilerplate instead of assembling sections from the user's configured global CLAUDE.md.

**Files:**
- `plugins/claude/project.sh` (lines 388-407)

**Problems:**
- Lines 388-407 write hardcoded project instructions instead of using `_claude_build_md()` function
- Global configuration (`CLAUDE_MD_SECTIONS` from global setup) is ignored
- Project CLAUDE.md does not include user's custom guidelines, exclusions, or conventions
- Generated file is minimal and unhelpful for project-specific configuration

**Impact:**
- Project scaffolding produces useless template files
- Users must manually edit CLAUDE.md after project-configs completes
- Project inherits none of the global configuration decisions

**Fix approach:**
- Replace hardcoded boilerplate (lines 388-407) with call to `_claude_build_md()` function
- Pass `CLAUDE_MD_SECTIONS` into the builder to include user's selected sections
- Append project-specific overrides after global content (e.g., project-level tool restrictions)
- Add test case verifying CLAUDE.md contains global sections plus project additions

---

### 3. Project-Level settings.json References Non-Existent Hook Paths

**Issue:** The hooks.json template contains paths pointing to `$CLAUDE_PROJECT_DIR/plugins/claude/hooks/` which do not exist in target projects.

**Files:**
- `plugins/claude/templates/settings/hooks.json`

**Problems:**
- Hook command paths reference `plugins/claude/hooks/` from dotconfigs source tree
- Target projects have hooks deployed to `.claude/hooks/` directory
- Settings assembler references broken paths, causing hook execution failures
- Path variables not interpolated correctly; hardcoded paths assume specific directory layout

**Impact:**
- Deployed project settings cannot execute hooks (command not found errors)
- Claude Code cannot trigger pre/post-tool hooks in projects using project-configs scaffold
- Hook failures are silent; users won't know hooks aren't running

**Fix approach:**
- Update `hooks.json` template to use relative path: `~/.claude/hooks/` or project-relative `./.claude/hooks/`
- Replace hardcoded `$CLAUDE_PROJECT_DIR` with actual relative path during assembly
- Add path validation in deploy.sh: verify hook files exist before deploying settings
- Document hook deployment and path expectations in project scaffold documentation

---

## Major Issues (Degraded Functionality)

### 4. Deploy Output Lacks Source Provenance Information

**Issue:** Deploy messages show only target file paths, omitting the source file path needed for SSOT (single source of truth) verification.

**Files:**
- `plugins/claude/deploy.sh` (8 echo statements)
- `lib/symlinks.sh` (lines 111, 118, 126, 152)

**Problems:**
- Echo statements use `$name` (target filename only) instead of source path
- Users cannot verify which template generated which deployed file
- Deployments become harder to audit and troubleshoot
- Symlink creation hides the mapping between source and destination

**Impact:**
- Reduced visibility into deployment process
- Harder to debug which template file caused configuration issues
- Users cannot trace deployed settings back to source

**Fix approach:**
- Update all deploy echo statements to include source path: `"${source_path} → ${target_path}"`
- Modify `backup_and_link()` in `lib/symlinks.sh` to print mapping
- Add consistent format: `"Deployed: plugins/claude/templates/settings.json → ~/.claude/settings.json"`
- Add `--verbose` flag to show intermediate processing steps

---

### 5. Git Plugin Hook Section Lacks Granular Scope Control

**Issue:** The git plugin wizard presents hook configuration as all-or-nothing but users need per-hook granularity (location: global, project, disabled).

**Files:**
- `plugins/git/setup.sh` (lines 280-410 hook configuration section)

**Problems:**
- Hook configuration only offers on/off toggle; cannot choose individual hook location
- Users cannot set some hooks to project scope and others to global scope
- No option to disable specific hooks (e.g., disable post-merge but enable pre-commit)
- UI doesn't explain tracked vs untracked hook locations

**Impact:**
- Cannot customize hook behaviour per-project or per-team
- Users forced to accept all hooks or disable entirely
- No way to opt-out of specific enforcement (e.g., disabling secrets check for repos with test credentials)

**Fix approach:**
- Add per-hook menu: "Configure each hook individually? [y/n]"
- If yes, iterate: `"post-commit hook: [1] global [2] project [3] disabled"`
- Store per-hook locations in `.env` with suffixes: `GIT_HOOK_PRE_COMMIT_LOCATION=project`
- Document hook precedence: project hook > global hook > disabled
- Add test case for mixed hook configurations

---

### 6. Git Plugin Edit Mode Display Parsing Broken for Items 7+

**Issue:** The edit mode for git plugin configuration has a parsing bug that causes garbled labels and non-functional selection beyond item 6.

**Files:**
- `plugins/git/setup.sh` (line 500+, display parsing section)

**Problems:**
- Edit mode shows numbered menu of current configuration values
- Labels become garbled and misaligned after item 6
- Selection input validation fails; entering valid numbers is rejected
- Display parsing likely uses incorrect field separator or index calculation

**Impact:**
- Users cannot edit hook configuration in re-run mode
- Configuration must be reset and re-run from scratch to change settings
- Error messages ("Invalid input") appear even with valid input

**Fix approach:**
- Debug display parsing logic; likely issue in loop that generates numbered menu
- Verify field separator handling (colon-delimited or space-delimited?)
- Add test case with mock input to verify 10+ items render correctly
- Add verbose debug mode: `bash -x plugins/git/setup.sh` should show parsing steps
- Consider simplifying display format to avoid parsing complexity

---

## Data Integrity Issues

### 7. Deploy Output Idempotency Not Fully Validated

**Issue:** Repeat deployments correctly show "Unchanged" status but lack full verification that target files match source.

**Files:**
- `plugins/claude/deploy.sh`
- `lib/symlinks.sh`

**Problems:**
- No checksum comparison between source and target
- Filesystem timestamp changes could cause re-deployment of unchanged content
- Symlink targets are not validated (symlink could point to wrong file but report unchanged)
- No warning if target file differs from source (manual user edit gone undetected)

**Impact:**
- Silent drift between source templates and deployed files possible
- Users could accidentally modify deployed files and have no visibility
- No way to detect configuration corruption

**Fix approach:**
- Add checksum comparison before reporting "Unchanged": compute `sha256sum` of source and target
- Store checksum in deployment metadata file (e.g., `.claude/deploy-manifest.json`)
- Warn if deployed file differs from source without --force flag
- Add `--verify` flag to audit existing deployments against sources
- Document deployment state tracking approach

---

### 8. Project-Configs Scaffold Generates Orphaned Configuration Files

**Issue:** Generated CLAUDE.md, settings.json, and hooks.json may reference non-existent source files or use paths that don't work in the target project context.

**Files:**
- `plugins/claude/project.sh` (scaffold generation)
- `plugins/claude/templates/` (template files)

**Problems:**
- Generated files assume target project structure matches dotconfigs structure
- Path variables in templates (e.g., `$CLAUDE_PROJECT_DIR`) not interpolated for target
- Generated .dotconfigs.json excluded by default (recent fix, but implications unclear)
- No validation that generated files reference valid tools, paths, or commands

**Impact:**
- Project scaffolding produces files that won't work without manual editing
- Users must understand Claude Code internals to fix generated configuration
- Configuration breaks on Claude updates or when project structure differs

**Fix approach:**
- Add validation step in project.sh: verify all referenced paths exist post-generation
- Generate .dotconfigs.json with actually-available tools in target project
- Document target-project path assumptions
- Add `--validate` flag to check generated files before deployment
- Create test fixture: run project-configs on test project, verify all paths work

---

## Configuration Management Issues

### 9. Git Hook Identity Enforcement Hardcoded

**Issue:** Identity validation in git hooks is hardcoded to specific user (henrycgbaker), blocking contributions from other team members.

**Files:**
- `plugins/git/hooks/commit-msg` (identity check logic)
- `plugins/git/setup.sh` (configuration section)

**Problems:**
- Hardcoded identity check prevents other users from committing
- Identity is not configurable per-repository via git config
- No way to add team member identities or use team email addresses
- Setup wizard doesn't prompt for identity configuration (assumes global git config is correct)

**Impact:**
- Multi-person teams cannot use repo-specific hooks with identity enforcement
- Workaround: disable hooks entirely or edit checked-in hook files
- Identity check is security-theater if not properly configured per-team

**Fix approach:**
- Store identity in `.git/config`: `[dotclaude] allowed_authors = user1@example.com,user2@example.com`
- Read from git config in hook before checking identity
- Wizard should prompt: "Allow commits from [git config user.email]? [y/n]" with option to add team emails
- Document identity configuration in hook setup instructions
- Add test case: simulate commit with different author identity

---

## Testing & Validation Gaps

### 10. No Integration Tests for Project Scaffold Generation

**Issue:** Project-configs scaffold generation has no automated tests, making it fragile to changes.

**Files:**
- `plugins/claude/project.sh` (scaffold generation)
- `tests/` (test directory)

**Problems:**
- No test suite for project-configs output validation
- Wizard function availability issues went undetected in development
- Hook path issues in settings.json not caught until UAT
- CLAUDE.md builder issues only discovered through user feedback

**Impact:**
- Regressions in project scaffold easily introduced
- Feature changes break project-configs silently
- User-facing issues discovered late (UAT vs development)

**Fix approach:**
- Add comprehensive test suite in `tests/test-project-configs.sh`:
  - Verify wizard functions are available
  - Validate CLAUDE.md includes expected sections
  - Check settings.json hook paths point to valid locations
  - Verify all template variables are interpolated
- Add test fixtures: sample .env with various configurations
- Run project-configs on test project, verify output is functional
- Add pre-commit hook to run tests

---

### 11. No Validation of Plugin Interdependencies

**Issue:** Plugins depend on shared lib functions but sourcing is not consistently handled, leading to missing-function errors at runtime.

**Files:**
- `plugins/claude/project.sh` (calls wizard functions)
- `plugins/git/project.sh` (may have similar issues)
- `lib/wizard.sh`, `lib/symlinks.sh` (shared functions)

**Problems:**
- Plugin execution context doesn't guarantee lib functions are available
- No static validation that called functions are exported/sourced
- Error messages are unhelpful when functions are missing
- Plugin README/documentation doesn't explain dependency on lib

**Impact:**
- Runtime errors when plugins call unavailable functions
- Plugin portability is fragile; moving plugins breaks them
- Hard to debug function availability issues

**Fix approach:**
- Document function dependencies in each plugin
- Add validation at plugin start: check all required functions exist, error clearly if missing
- Create shared function export mechanism (e.g., `_export_functions` in main dotconfigs)
- Test plugins in isolated execution context to catch sourcing issues
- Update plugin development guidelines with sourcing requirements

---

## Architecture & Design Concerns

### 12. Multiple Agents Perform Overlapping Verification (GSD)

**Issue:** Plan-checker, verifier, and executor have overlapping verification responsibilities without clear role boundaries.

**Files:**
- `.planning/quick/002-fix-git-wizard-bug-restructure-cli-setup/` (ongoing work)
- `agents/gsd-plan-checker.md`
- `agents/gsd-verifier.md`
- `agents/gsd-executor.md`

**Problems:**
- Plan-checker validates predictive (will plan work?)
- Verifier validates confirmatory (did execution work?)
- Executor has internal verification (valid plan execution?)
- Relationship between phases not documented; unclear what happens on disagreement

**Impact:**
- Redundant verification work
- Ambiguous phase failure diagnosis
- No unified verification report or audit trail

**Fix approach:**
- Document verification philosophy: design → predictive → execution → confirmatory
- Clarify plan-checker is gate (blocks execution), verifier is audit (can restart)
- Create VERIFICATION.md template with structured output format
- Executor verification is internal only; reports to verifier, not blocking

---

## Performance & Scaling Concerns

### 13. Plan Dependency Resolution Could Be Inefficient

**Issue:** Wave-based dependency resolution in GSD execute orchestrator scales linearly (O(n)) but documentation is unclear about implementation.

**Files:**
- `.planning/quick/002-fix-git-wizard-bug-restructure-cli-setup/` (ongoing work)
- `commands/gsd/execute-phase.md`

**Problems:**
- No dependency graph structure; resolution described but not implemented detail clear
- Circular dependencies not detected until runtime
- Context for wave tracking not persisted between phases
- Large phase sets could cause orchestrator context overflow

**Impact:**
- Projects with 50+ plans may have execution delays
- Circular dependencies cause hangs or errors without clear messaging
- Large plans exceed context budgets without warning

**Fix approach:**
- Build dependency graph once at phase start using topological sort
- Implement cycle detection; fail fast on circular dependencies
- Cache wave assignments in `.planning/phase-X-waves.json`
- Validate all dependencies exist before execution starts
- Add `--validate-deps` flag to check dependencies without executing

---

## Known Workarounds & Deferred Issues

### 14. Claude Code Security Issues Bypassing Deny Rules

**Issue:** Claude Code has known bugs (#6699, #8961) where deny rules are ineffective; security layer shipped anyway as future-proofing.

**Files:**
- `plugins/claude/templates/settings/` (deny rules)
- `.planning/phases/03-settings-hooks-deploy-skills/03-01-SUMMARY.md` (documented)

**Problems:**
- `.env` and `.env.*` files currently not blocked despite deny rules
- Deny rules will only activate when Claude Code bugs are fixed
- No warning that security is partially ineffective in current version

**Impact:**
- `.env` files with secrets could be read by Claude if prompt is crafted to bypass rules
- Users should not rely on deny rules for critical secret protection
- Risk depends on Claude Code version and bug fix timeline

**Fix approach:**
- Document this limitation in setup wizard: "Note: deny rules ineffective until Claude Code vX.Y+"
- Add ask rules as fallback: prompt user before accessing sensitive patterns
- Recommend: store truly critical secrets outside .env (use credential managers)
- Monitor Claude Code releases for bug fixes; update documentation when fixed
- Add validation test: confirm deny rules are enforced in Claude Code version check

---

## Technical Debt

### 15. Post-Tool Format Hook Uses Python Subprocess Without Error Handling

**Issue:** The post-tool-format hook spawns Python subprocess but has weak error handling for Python execution failures.

**Files:**
- `plugins/claude/hooks/post-tool-format.py`

**Problems:**
- Hook does not validate Python version compatibility
- Subprocess calls do not capture stderr or handle exceptions
- Hook silently fails if Python dependencies missing or syntax error
- No logging of hook execution or failures

**Impact:**
- Tool output formatting errors go unnoticed
- Hook failures won't appear in Claude logs; users unaware of problems
- Debugging hook issues requires manual bash -x inspection

**Fix approach:**
- Add Python version check at start: require Python 3.8+
- Wrap subprocess calls in try/except with clear error messages
- Add logging: output errors to stderr if hook fails
- Document required Python dependencies and versions
- Add pre-deployment validation: test hook syntax before deploy

---

## Minor Issues & Improvements

### 16. Unclear Deployment State Visibility

**Issue:** Users cannot easily determine what's deployed vs. what's pending without running full deploy command.

**Files:**
- `plugins/claude/deploy.sh`
- `lib/symlinks.sh`

**Problems:**
- `status` command output doesn't show file paths or deployment state
- No manifest of deployed files (e.g., `.claude/deploy-manifest.json`)
- Users must infer state from directory listing

**Impact:**
- Harder to troubleshoot deployment issues
- Users don't know what was deployed last
- Audit trail of deployments missing

**Fix approach:**
- Create deployment manifest: `.claude/deploy-manifest.json` with file list + checksums
- Enhance `status` command to show deployment state vs. source state
- Add `--list-deployed` flag to show all deployed files with timestamps
- Document manifest format for users

---

*Concerns audit: 2026-02-10*
