# Claude Code Configuration Pitfalls

Research document identifying common pitfalls when configuring Claude Code setups, based on real issues found in a 94-file dotclaude repository that became over-engineered.

---

## 1. Context Management Pitfalls

### 1.1 Bloated CLAUDE.md Causing Instruction-Following Degradation

**The Problem:**
- Large CLAUDE.md files (500+ lines) loaded into every conversation consume significant context window
- As context fills, Claude's ability to follow specific instructions degrades
- Users add more rules to compensate for degradation, creating a vicious cycle
- The "instruction bloat death spiral": poor performance → more rules → worse performance

**Warning Signs:**
- CLAUDE.md over 200 lines
- Repetitive instructions in different sections
- Instructions that restate framework defaults
- Claude ignoring or forgetting specific rules
- Needing to repeat instructions mid-conversation

**Prevention Strategy:**
1. **Modular documentation** - Split into multiple files, load only relevant sections
2. **Infer over instruct** - Trust Claude to infer reasonable behaviour; only specify exceptions
3. **Regular audits** - Review every 2-3 months, remove redundant/unused rules
4. **Metrics** - Track rule count and character count as key health indicators

**Implementation Phase:**
- **Design:** Define maximum size limits (200 lines for global, 100 for project)
- **Build:** Use modular structure with linked documents
- **Maintain:** Quarterly review process with removal bias

**Real Example:**
This dotclaude repo had 7 rules files (464 total lines) always loaded, plus agent definitions. Much of this repeated Claude's default behaviour (e.g., "use British spelling in prose" when Claude already does this, "don't create unnecessary files" when Claude naturally avoids this).

---

### 1.2 Rules Files Loaded Unconditionally Eating Baseline Context

**The Problem:**
- Settings like `~/.claude/CLAUDE.md` or `includeFiles` in settings load into *every* conversation
- Even single-purpose rules (e.g., Python standards) burn context in non-Python sessions
- Context window is fixed; every unconditional rule reduces space for actual work
- 7 rules files × 66 lines average = ~460 lines of constant overhead

**Warning Signs:**
- Rules files for specific languages loaded globally
- Workflow documentation loaded for tasks you rarely do
- Context window filling before complex work begins
- Multiple "how to" guides in always-loaded files

**Prevention Strategy:**
1. **Conditional loading** - Use project-specific CLAUDE.md for specialized rules
2. **Just-in-time documentation** - Link to external docs instead of embedding
3. **Tool over instruction** - Use hooks/settings instead of prose rules where possible
4. **The 80/20 rule** - Global rules should apply to 80%+ of your work

**Implementation Phase:**
- **Design:** Categorize rules as "universal" vs "contextual"
- **Build:** Move contextual rules to project-level or on-demand files
- **Maintain:** Challenge each global rule quarterly: "Is this needed in every session?"

**Real Example:**
```
rules/python-standards.md (171 lines) - loaded even in bash/JS projects
rules/git-workflow.md (131 lines) - loaded even when not using git
rules/modular-claude-docs.md (67 lines) - instructions for writing docs, needed 2% of time
```

Better approach: Python standards in project CLAUDE.md for Python projects only.

---

### 1.3 MCP Servers Adding Tool Definitions Even When Idle

**The Problem:**
- Every MCP server adds tool definitions to context window on session start
- Tools remain in context even if never used in that session
- Multiple MCP servers compound the problem exponentially
- Tool descriptions can be verbose (10-50 lines each)

**Warning Signs:**
- Multiple MCP servers configured
- Context window shows high baseline usage before any work
- Slow session initialization
- Tools listed that you rarely/never use

**Prevention Strategy:**
1. **Enable selectively** - Only configure MCP servers you use daily
2. **Project-specific MCP** - Use project settings.json for specialized servers
3. **Lazy loading** - Future framework feature: load MCP tools on-demand
4. **Regular review** - Disable unused servers monthly

**Implementation Phase:**
- **Design:** Audit MCP server usage patterns
- **Build:** Move specialized servers to project configs
- **Maintain:** Track server usage, remove unused after 1 month

**Example Impact:**
- 5 MCP servers × 8 tools each × 15 lines per tool = ~600 lines baseline context
- If you only use 2 servers regularly, 75% is waste

---

### 1.4 Not Using /clear Between Unrelated Tasks

**The Problem:**
- Context accumulates across unrelated tasks in single session
- Previous task context pollutes current task understanding
- Claude may reference irrelevant information from earlier in conversation
- Long sessions hit context limits faster

**Warning Signs:**
- Claude references files/concepts from unrelated earlier tasks
- Context window nearly full when starting new work
- Confusion about which task is current
- Performance degradation in long sessions

**Prevention Strategy:**
1. **Task boundaries** - Use `/clear` when switching between unrelated tasks
2. **Dedicated sessions** - Start fresh session for major new work
3. **Habit formation** - Make `/clear` part of mental task-switching ritual
4. **Context awareness** - Check context window before complex tasks

**Implementation Phase:**
- **User training:** Document when to use `/clear` in global CLAUDE.md
- **Workflow:** Build into standard operating procedure
- **Monitoring:** Notice when NOT clearing causes issues

**Rule of Thumb:**
Clear context when:
- Switching projects
- Moving from debugging to new feature
- Changing languages/frameworks
- Starting work >30 min after last task

---

## 2. Hook Pitfalls

### 2.1 Pre-commit vs Commit-msg Timing (Which Hook Sees What Data When)

**The Problem:**
- `pre-commit` runs *before* commit message exists, but hook reads COMMIT_EDITMSG from *previous* commit
- Reading COMMIT_EDITMSG in pre-commit gives stale data
- `commit-msg` runs after message is written but before commit is finalized
- Confusion about which hook should validate what leads to broken validation

**Warning Signs:**
- Pre-commit hook tries to validate commit message content
- Hooks fail with "file not found" intermittently
- First commit after clone fails differently than subsequent commits
- Validation triggers on wrong commit content

**Prevention Strategy:**
1. **Clear responsibility split:**
   - `pre-commit`: staged files, repository state, code quality
   - `commit-msg`: message format, attribution, conventional commit rules
2. **Never read COMMIT_EDITMSG in pre-commit** - it's stale data
3. **Test timing** - Verify hooks with fresh repository clones

**Implementation Phase:**
- **Design:** Document hook responsibility boundaries
- **Build:** Place validations in correct hooks
- **Test:** Verify in fresh repo and after failed commits

**Real Example:**
```bash
# In pre-commit hook (WRONG - reads stale previous commit message):
COMMIT_MSG_FILE="$REPO_ROOT/.git/COMMIT_EDITMSG"
if [ -f "$COMMIT_MSG_FILE" ]; then
    COMMIT_MSG=$(cat "$COMMIT_MSG_FILE")  # This is PREVIOUS commit
    if echo "$COMMIT_MSG" | grep -qiE 'AI-assisted'; then
        echo "ERROR: AI attribution detected"
        exit 1
    fi
fi
```

This fails on the *second* commit if the *first* had attribution, not on the current commit.

**Correct Approach:**
- Move all commit message validation to `commit-msg` hook
- Pre-commit should only validate staged changes and repo state

---

### 2.2 Fail-Open vs Fail-Closed on Hook Errors

**The Problem:**
- Fail-open (errors allow operation) creates security holes
- Fail-closed (errors block operation) creates usability disasters
- Choosing wrong default for each hook type causes frustration or vulnerabilities
- Parse errors, missing dependencies, or permission issues hit users differently

**Warning Signs:**
- Hooks with inconsistent error handling philosophy
- Users bypassing hooks due to frequent false failures
- Security-critical validations that fail silently
- Broken commits passing through due to hook errors

**Prevention Strategy:**
1. **Risk-based decision:**
   - **Fail-closed:** Security (sensitive files), code quality (linting)
   - **Fail-open:** Convenience features (formatting, stats), informational checks
2. **Graceful degradation:** Log warning and continue if tool unavailable
3. **Clear error messages:** When failing closed, explain what broke and how to fix
4. **Escape hatch:** Document `--no-verify` for emergency overrides

**Implementation Phase:**
- **Design:** Classify each hook as security/quality (fail-closed) vs convenience (fail-open)
- **Build:** Implement appropriate error handling for each
- **Test:** Verify behavior when dependencies missing or inputs malformed

**Real Example:**
```python
# Fail-open for sensitive file check (WRONG for security):
def main() -> int:
    try:
        data = json.load(sys.stdin)
    except json.JSONDecodeError:
        return 0  # Allow on parse error - fails open!
```

If hook input is malformed, sensitive files become accessible. Should fail-closed:

```python
except json.JSONDecodeError:
    print("ERROR: Failed to parse hook input", file=sys.stderr)
    return 2  # Block operation on parse error
```

**Decision Matrix:**
| Hook Purpose | Fail Mode | Rationale |
|--------------|-----------|-----------|
| Block sensitive files | Closed | Security critical |
| AI attribution check | Closed | Policy enforcement |
| Code formatting | Open | Convenience, not critical |
| Test runs | Closed | Quality gate |
| Metrics/stats | Open | Informational only |

---

### 2.3 Complex Hook Scripts vs Simple settings.json Deny Rules

**The Problem:**
- Users build 100-line Python hooks for functionality available in 3 lines of settings.json
- Complex hooks harder to debug, maintain, and reason about
- Hooks run slower than built-in framework checks
- Bug surface area increases dramatically

**Warning Signs:**
- Hook file over 50 lines for simple validation
- Reimplementing pattern matching that settings.json provides
- Multiple hooks doing similar checking
- Hooks failing in ways that settings.json wouldn't

**Prevention Strategy:**
1. **Settings-first rule:** Try settings.json before writing hook
2. **Use built-in permissions:** `deny`, `allow`, `ask` for file/command patterns
3. **Hooks for gaps only:** Write hooks only for logic framework can't express
4. **Complexity audit:** If hook >30 lines, check if settings can replace it

**Implementation Phase:**
- **Design:** Map requirements to settings capabilities first
- **Build:** Use settings for pattern matching, hooks for complex logic only
- **Refactor:** Convert existing hooks to settings where possible

**Real Example:**

Current approach - 102-line Python hook:
```python
#!/usr/bin/env python3
# 102 lines of code to block sensitive files
SENSITIVE_PATTERNS = [
    r"\.env$",
    r"\.ssh/",
    r"credentials",
    # ... 30+ patterns
]

def is_sensitive(file_path: str) -> bool:
    return any(pattern.search(path_str) for pattern in COMPILED_PATTERNS)
# ... more code ...
```

Better approach - settings.json (8 lines):
```json
{
  "permissions": {
    "deny": [
      "Read(.env)",
      "Read(.env.*)",
      "Read(**/.ssh/**)",
      "Read(**/*_key)",
      "Read(**/*_secret)",
      "Read(**/credentials*)"
    ]
  }
}
```

**Benefits of settings approach:**
- 94% less code (8 lines vs 102)
- Framework-maintained (no custom regex bugs)
- Faster execution (compiled, not runtime Python)
- Clear declarative syntax
- Better error messages

**When Hooks Are Appropriate:**
- Dynamic validation (file content analysis)
- External tool integration (running linters)
- Stateful checks (comparing to previous commits)
- Complex business logic (multi-condition rules)

---

### 2.4 Hook Maintenance Burden

**The Problem:**
- Hooks are code that needs testing, debugging, and updates
- As requirements grow, hooks become mini-applications
- No version control for installed hooks (they live in .git/hooks)
- Breaking changes in hook dependencies (Python/Node versions, libraries)
- Bit rot - hooks written once, forgotten, then fail mysteriously

**Warning Signs:**
- Hooks not updated in >6 months
- Different hook versions across team members
- Hooks failing after system updates
- No tests for hook logic
- Hardcoded paths or assumptions

**Prevention Strategy:**
1. **Minimize hooks:** Each hook is technical debt
2. **Template pattern:** Keep hooks in version control (githooks/), copy to .git/hooks/
3. **Dependency declaration:** Document required tools/versions
4. **Regular testing:** Run hooks in CI or test manually quarterly
5. **Simplicity bias:** Remove hooks that aren't actively preventing bugs

**Implementation Phase:**
- **Design:** Cost-benefit for each proposed hook
- **Build:** Template in repo, install script, version check in hook
- **Maintain:** Quarterly review, remove unused, update dependencies

**Maintenance Checklist (Quarterly):**
- [ ] Does this hook still serve its purpose?
- [ ] Has it failed or been bypassed recently?
- [ ] Are dependencies up to date?
- [ ] Could settings.json replace it?
- [ ] Is documentation current?

**Real Example:**
This dotclaude repo has:
- `githooks/pre-commit` (133 lines) - template
- `githooks/commit-msg` (39 lines) - template
- Manual copy to `.git/hooks/` required
- No automated sync between template and installed version
- Agent sync feature (disabled) still in code but unmaintained

Better: Use setup.sh to install, add version check to detect drift.

---

## 3. Configuration Pitfalls

### 3.1 Over-Engineering Config (Building for Hypothetical Future)

**The Problem:**
- "What if we need to..." thinking leads to unused flexibility
- Configurable systems for scenarios that never materialize
- Maintenance burden of complexity exceeds benefit
- Simple needs buried under abstraction layers
- 80% of code serves 5% of use cases

**Warning Signs:**
- Configuration options never changed from defaults
- Abstraction layers with single implementations
- "Future-proof" systems for hypothetical requirements
- More time maintaining config than using it
- Dead code paths for "maybe someday" features

**Prevention Strategy:**
1. **Build for now:** Solve current problem, not imagined future
2. **YAGNI principle:** You Aren't Gonna Need It
3. **Three-instance rule:** Only generalize after third similar use case
4. **Simplicity bias:** Choose less flexible, more simple solution
5. **Deletion review:** Regularly remove unused config options

**Implementation Phase:**
- **Design:** Question every "what if" - is it real or imagined?
- **Build:** Hardcode first, parameterize only when needed
- **Refactor:** Remove unused abstraction when actual need emerges

**Real Example:**

Over-engineered agent sync (300 lines):
```bash
# Bidirectional sync between projects and dotclaude
# Remote SSH support
# Nested directory handling
# Status diffing
# README auto-generation
# Project registry
```

Reality:
- Sync disabled in pre-commit (line 80: "Over-engineering")
- Never used in 6+ months
- GSD agents better managed per-project
- Complex remote sync never needed
- 300 lines of dead weight

**What Was Actually Needed:**
Nothing. GSD framework handles agent distribution. The "problem" was imaginary.

**Red Flags in Design Phase:**
- "This will let us..."
- "Flexible enough to handle..."
- "Future-proof architecture for..."
- "Enterprise-ready system with..."
- "Configurable pipeline to support..."

**Right-Sized Alternative:**
If sync was actually needed: single command to copy specific agents manually, not automated bidirectional system.

---

### 3.2 Hardcoded Values That Should Be Configurable

**The Problem:**
- Personal values embedded in shared scripts
- Config breaks when used by different person/machine
- Scripts work on author's machine, fail elsewhere
- Name, email, paths hardcoded in hooks or setup
- Shared config becomes personal, or personal becomes unnecessarily shared

**Warning Signs:**
- Absolute paths in scripts (e.g., `/Users/henrybaker/...`)
- Names/emails in hook validation
- "Works on my machine" syndrome
- Setup requires editing source files
- Config fails on different OS/environment

**Prevention Strategy:**
1. **Environment variables:** Use `$USER`, `$HOME`, `git config` instead of literals
2. **Deploy-time config:** Pass values to setup.sh, not embedded in scripts
3. **Test cross-platform:** Verify on different user account
4. **Read from git config:** Get identity from `git config user.name` instead of hardcoding
5. **Detect, don't assert:** Check environment, adapt rather than fail

**Implementation Phase:**
- **Design:** Identify all personal/system-specific values
- **Build:** Replace with env vars, config reads, or detection
- **Test:** Run as different user, on different machine

**Real Example:**

Hardcoded identity in pre-commit hook:
```bash
# --- Identity Check ---
EXPECTED_NAME="henrycgbaker"
EXPECTED_EMAIL="henry.c.g.baker@gmail.com"

ACTUAL_NAME=$(git config user.name)
ACTUAL_EMAIL=$(git config user.email)

if [ "$ACTUAL_NAME" != "$EXPECTED_NAME" ]; then
    echo "ERROR: Git user.name is '$ACTUAL_NAME', expected '$EXPECTED_NAME'"
    exit 1
fi
```

**Problems:**
- Hook only works for one person
- Can't be used in shared repo
- Can't be used on different machines with different git config
- Author's personal details in shared template

**Better Approach (Deploy-Time Config):**
```bash
# In setup.sh:
read -p "Git user.name for this repo: " GIT_NAME
read -p "Git user.email for this repo: " GIT_EMAIL

# Write to .git/config (local, not tracked):
git config user.name "$GIT_NAME"
git config user.email "$GIT_EMAIL"

# Hook verifies consistency, not hardcoded value:
if [ -z "$(git config user.name)" ]; then
    echo "ERROR: Git user.name not configured"
    echo "Fix with: git config user.name 'Your Name'"
    exit 1
fi
```

**Or Even Better (No Validation):**
Just trust git config. If someone commits with wrong identity, they'll notice. Don't build enforcement for non-problem.

---

### 3.3 Duplicating Framework Functionality (GSD)

**The Problem:**
- Copying framework agents into local repo
- Agents drift from upstream as framework improves
- Bug fixes and improvements don't propagate
- Maintenance burden of keeping in sync
- Larger repo with duplicated content
- Confusion about which version is authoritative

**Warning Signs:**
- Agents or commands copied from framework
- Version mismatches between framework and local
- Framework updates don't affect local agents
- Local modifications to framework code
- Unclear which version to edit when bugs found

**Prevention Strategy:**
1. **Use framework directly:** Import/reference, don't copy
2. **Extend, don't duplicate:** Add project-specific agents alongside framework ones
3. **Upstream improvements:** Contribute fixes to framework, not local forks
4. **Version lock:** Pin framework version, upgrade deliberately
5. **Clear separation:** Project agents separate from framework agents

**Implementation Phase:**
- **Design:** Identify framework vs custom functionality
- **Build:** Delete duplicates, reference framework
- **Maintain:** Track framework updates, upgrade periodically

**Real Example:**

This dotclaude repo has 11 GSD agents in `/agents/`:
```
agents/gsd-codebase-mapper.md      (1,232 lines)
agents/gsd-debugger.md             (457 lines)
agents/gsd-executor.md             (875 lines)
agents/gsd-integration-checker.md  (550 lines)
agents/gsd-phase-researcher.md     (841 lines)
agents/gsd-plan-checker.md         (862 lines)
agents/gsd-planner.md              (913 lines)
agents/gsd-project-researcher.md   (901 lines)
agents/gsd-research-synthesizer.md (256 lines)
agents/gsd-roadmapper.md           (605 lines)
agents/gsd-verifier.md             (778 lines)
Total: 8,685 lines
```

**Problems:**
- These are GSD framework agents - duplicated here
- Framework updates don't propagate
- Repo bloated with framework code
- Drift between this copy and framework version
- Which to edit when issues found?

**Correct Approach:**
- GSD framework ships agents
- Users invoke them via `/gsd:plan`, `/gsd:execute`, etc.
- No duplication needed
- Framework updates automatically improve agents
- Project-specific customization via project CLAUDE.md, not agent copies

**Exception (Legitimate Duplication):**
If you're:
- Developing a framework (need to modify core agents)
- Heavily customizing behaviour (not just config)
- Working offline without framework access

Then document why duplication exists and how to sync.

---

### 3.4 Dead Code Accumulation

**The Problem:**
- Features disabled but code remains
- "Just in case" mentality prevents deletion
- Comments mark dead code instead of removing it
- Maintenance burden of understanding what's active
- Confusion about what's actually running
- Code reviewed and maintained unnecessarily

**Warning Signs:**
- Commented-out blocks over 10 lines
- Config options that disable features
- "TODO: remove this" comments over 6 months old
- Files with "old" or "backup" in name
- Conditional compilation that's always one branch

**Prevention Strategy:**
1. **Delete, don't disable:** Git preserves history, deletion is safe
2. **Regular pruning:** Quarterly review for dead code
3. **Removal bias:** When in doubt, delete it
4. **One-way doors:** Mark genuinely experimental code clearly
5. **Version control trust:** Don't fear deletion, history is permanent

**Implementation Phase:**
- **Design:** Mark experimental code explicitly
- **Build:** Delete immediately when feature abandoned
- **Maintain:** Quarterly scan for commented code, disabled features

**Real Example:**

In block-sensitive.py:
```python
SENSITIVE_PATTERNS = [
    # Environment files
    # r"\.env$",           # COMMENTED OUT
    # r"\.env\.",          # COMMENTED OUT
    # r"\.env\..*",        # COMMENTED OUT
    # Secrets directories
    r"/secrets/",
    r"\.ssh/",
```

.env patterns commented out because permissions in settings.json handle it. But 102-line hook still exists. Both are dead weight.

In pre-commit hook (lines 79-86):
```bash
# --- Agent Sync (dotclaude only) ---
# Disabled: Over-engineering - agents managed manually per project
# if [ -x "$REPO_ROOT/sync-project-agents.sh" ]; then
#     echo "🔄 Syncing project agents..."
#     "$REPO_ROOT/sync-project-agents.sh" pull 2>/dev/null
#     git add "$REPO_ROOT/project-agents/" 2>/dev/null || true
#     echo "✅ Agent sync complete"
# fi
```

Feature disabled, but code preserved. Also, sync-project-agents.sh (300 lines) still in repo.

**What Should Happen:**
1. Delete commented patterns from block-sensitive.py
2. Delete entire block-sensitive.py (settings.json replaces it)
3. Delete commented agent sync from pre-commit
4. Delete sync-project-agents.sh entirely
5. Update documentation to remove references

**Recovery If Needed:**
```bash
# "Oh no, I need that feature back!"
git log --all --full-history -- path/to/file.sh
git show <commit>:path/to/file.sh > file.sh
```

Git history makes deletion safe. Dead code makes active code confusing.

---

## 4. Deployment Pitfalls

### 4.1 Symlink vs Copy Confusion (When Each Breaks)

**The Problem:**
- Symlinks require source repo to exist at fixed path
- Copies don't auto-update when template changes
- Wrong choice for each scenario causes maintenance pain
- Broken symlinks harder to debug than stale copies
- Cross-platform symlink issues (Windows, network drives)

**Warning Signs:**
- Hooks stop working after moving directories
- Changes to template don't affect installed version
- "File not found" errors for hooks
- Inconsistent hook behavior across team
- Setup script sometimes works, sometimes doesn't

**Prevention Strategy:**
1. **Decision matrix:**
   - **Copy:** Hooks (.git/ not tracked, rarely updated)
   - **Symlink:** Shared configs (settings.json, frequent updates)
2. **Document choice:** Explain why symlink vs copy in README
3. **Verify installation:** Setup script checks if link/copy succeeded
4. **Cross-platform testing:** Verify on macOS, Linux, Windows

**Implementation Phase:**
- **Design:** Choose based on update frequency and tracking
- **Build:** Setup script implements correct approach
- **Test:** Verify after directory moves, updates

**Decision Matrix:**

| File | Track in Git? | Update Frequency | Solution |
|------|---------------|------------------|----------|
| Git hooks | No (.git/hooks/) | Rare (stable scripts) | **Copy** template → .git/hooks/ |
| settings.json | No (user-specific) | Rare (stable config) | **Copy** template → ~/.claude/ |
| CLAUDE.md | Yes (repo-specific) | Frequent (evolving) | **Symlink** or direct edit |
| Hooks themselves | Yes (githooks/) | Rare (fix bugs) | Track template, copy on setup |

**Real Example:**

What breaks with symlinks:
```bash
# Install with symlink:
ln -sf ~/Repositories/dotclaude/githooks/pre-commit .git/hooks/pre-commit

# User moves repo:
mv ~/Repositories/dotclaude ~/Projects/configs/dotclaude

# Symlink breaks (absolute path no longer valid):
.git/hooks/pre-commit → ~/Repositories/dotclaude/githooks/pre-commit (broken)
```

What breaks with copies:
```bash
# Install with copy:
cp githooks/pre-commit .git/hooks/pre-commit

# Fix bug in template:
vim githooks/pre-commit  # (update template)
git commit -m "fix: correct hook error handling"

# Installed version still has bug:
.git/hooks/pre-commit  # (old version, not auto-updated)
```

**Best Practice for Hooks:**
1. Keep template in githooks/ (tracked)
2. Copy to .git/hooks/ on setup (not tracked)
3. Document that manual update required after template changes
4. Or: setup.sh checks template hash, warns if .git/hooks/ outdated

---

### 4.2 Cross-Platform Path Issues

**The Problem:**
- Unix paths (/) vs Windows paths (\)
- Case-sensitive (Linux) vs insensitive (macOS/Windows)
- Home directory expansion ($HOME vs %USERPROFILE%)
- Line endings (LF vs CRLF)
- Permission differences (chmod +x)

**Warning Signs:**
- Scripts work on macOS, fail on Linux or Windows
- "Command not found" on some platforms
- Paths with hardcoded separators
- Hooks don't execute (missing +x)
- Git config errors about line endings

**Prevention Strategy:**
1. **Path construction:** Use `path.join()` (Python), `path/to/file` (JavaScript)
2. **Home directory:** Use `~` or `$HOME`, not `/Users/username`
3. **Line endings:** Configure `.gitattributes` for shell scripts
4. **Shebang portability:** Use `#!/usr/bin/env bash`, not `#!/bin/bash`
5. **Test matrix:** Verify on multiple platforms before release

**Implementation Phase:**
- **Design:** Identify platform-specific code
- **Build:** Use portable constructs
- **Test:** Run on macOS, Linux, Windows (WSL)

**Real Example:**

Platform-specific issue in statusline hook:
```javascript
const homeDir = os.homedir();  // ✅ Portable
const todosDir = path.join(homeDir, '.claude', 'todos');  // ✅ Portable

// WRONG (Unix-specific):
const todosDir = homeDir + '/.claude/todos';  // Breaks on Windows
```

**Line Ending Issues:**
```bash
# On Windows checkout:
#!/usr/bin/env bash\r\n    # ← CRLF breaks shebang
echo "test"\r\n

# Error: /usr/bin/env: 'bash\r': No such file or directory
```

**Fix in .gitattributes:**
```
# Ensure shell scripts always have LF, even on Windows
*.sh text eol=lf
githooks/* text eol=lf
```

**Portable Path Construction:**

| Bad | Good |
|-----|------|
| `$HOME/.claude/hooks` | `~/.claude/hooks` |
| `/Users/henry/...` | `$HOME/...` or `~` |
| `path + '/' + file` | `path.join(path, file)` |
| `#!/bin/bash` | `#!/usr/bin/env bash` |

---

### 4.3 Settings Precedence Surprises

**The Problem:**
- Settings.json exists at multiple levels: global (~/.claude/), project (./.claude/settings.json)
- Merge behavior not intuitive (some fields override, some merge)
- User surprised when project setting doesn't take effect
- Hooks or permissions applied from unexpected location
- Difficult to debug which setting is active

**Warning Signs:**
- "I set this but it doesn't work"
- Unexpected hook execution
- Permissions different than configured
- Settings in multiple files with unclear winner
- Behavior differs between projects unexpectedly

**Prevention Strategy:**
1. **Document precedence:** Explain in setup README
2. **Single source truth:** Minimize use of multi-level settings
3. **Debug command:** Provide way to dump effective settings
4. **Merge semantics:** Know which fields merge (hooks) vs override (env)
5. **Explicit wins:** Be explicit rather than relying on precedence

**Implementation Phase:**
- **Design:** Choose appropriate settings level for each config
- **Build:** Document precedence clearly
- **Debug:** Add settings inspection tool

**Precedence Rules (approximate):**
1. Project `.claude/settings.json` (most specific)
2. Global `~/.claude/settings.json` (user defaults)
3. Framework defaults (fallback)

**Merge Behavior:**
| Field | Behavior |
|-------|----------|
| `hooks` | Merge arrays (both apply) |
| `permissions.deny` | Merge arrays (most restrictive) |
| `env` | Override (project replaces global) |
| `sandbox.enabled` | Override (project wins) |

**Real Example:**

Global settings.json:
```json
{
  "permissions": {
    "deny": ["Read(.env)", "Read(**/.ssh/**)"]
  }
}
```

Project settings.json:
```json
{
  "permissions": {
    "deny": ["Read(secrets.yml)"]
  }
}
```

**Expected:** Deny .env, .ssh, AND secrets.yml
**Actual:** Deny only secrets.yml (override, not merge)

**Fix:** Understand merge semantics, or include all patterns in project settings.

**Debug Effective Settings:**
```bash
# Currently no built-in command, but you can:
# 1. Check global: cat ~/.claude/settings.json
# 2. Check project: cat ./.claude/settings.json
# 3. Merge mentally based on documented precedence
```

---

### 4.4 Remote Deployment Complexity

**The Problem:**
- Deploying to remote machines (SSH, servers, containers)
- Network access required for sync
- Authentication setup (SSH keys, tokens)
- Different user accounts, paths, permissions
- Version drift between local and remote
- Over-engineered sync systems that never get used

**Warning Signs:**
- Complex sync scripts for rarely-accessed remotes
- SSH hardcoded in automation
- Manual copying between machines
- "It works locally but not on server"
- Deployment scripts >100 lines for simple config

**Prevention Strategy:**
1. **Question need:** Do you really need config on remote?
2. **Manual is fine:** For rare deployment, manual copy acceptable
3. **Infrastructure as code:** Use Ansible/Terraform for real remote config
4. **Dotfiles pattern:** Standard Unix dotfiles approach, not custom sync
5. **Git as transport:** Clone repo on remote, not custom sync protocol

**Implementation Phase:**
- **Design:** Assess frequency and justify automation
- **Build:** Use standard tools (git, rsync) not custom scripts
- **Maintain:** Remove if unused for 3+ months

**Real Example:**

Over-engineered remote sync in sync-project-agents.sh:
```bash
# Remote source (ssh)
if [[ "$source" == *:* ]]; then
    local host="${source%%:*}"
    local path="${source#*:}"
    log_info "  $project: Pulling from $host:$path"

    # Get list of agent files
    files=$(ssh -n "$host" "ls -1 $path/*.md 2>/dev/null" || true)

    for file in $files; do
        local basename=$(basename "$file")
        ssh -n "$host" "cat $file" > "$dest/$basename"
        log_info "    Pulled: $basename"
    done
fi
```

**Problems:**
- 60+ lines for SSH sync
- Hardcoded remote paths
- No authentication setup docs
- Never actually used (disabled in pre-commit)
- Standard `rsync` would be simpler if actually needed

**Right-Sized Alternatives:**

If rarely needed (1-2 times):
```bash
# Just manually copy:
scp remote:~/.claude/settings.json ~/.claude/settings.json
```

If frequently needed:
```bash
# Standard rsync:
rsync -avz remote:~/.claude/ ~/.claude/
```

If infrastructure-scale:
```yaml
# Ansible playbook:
- name: Deploy Claude config
  copy:
    src: files/settings.json
    dest: ~/.claude/settings.json
```

**Decision Matrix:**
| Frequency | Users | Solution |
|-----------|-------|----------|
| Once | 1 | Manual `scp` |
| Weekly | 1-3 | Script with `rsync` |
| Continuous | Team | Infrastructure as Code |
| Never | 0 | **Don't build it** |

---

## 5. Git Hook Pitfalls (Advanced)

### 5.1 Hooks Not Tracked by Git (Template Drift)

**The Problem:**
- Git hooks live in `.git/hooks/` which is never tracked
- Template in repo (githooks/) can diverge from installed version
- Team members have different hook versions
- Bug fixes to template don't auto-deploy
- No way to know if installed hook matches template

**Warning Signs:**
- "Works on my machine" hook issues
- Team members bypassing hooks due to bugs
- Old hook versions causing false positives
- Updates to githooks/ not propagated
- Setup.sh rarely re-run after clone

**Prevention Strategy:**
1. **Template pattern:** Source of truth in `githooks/` (tracked)
2. **Install script:** `setup.sh` copies template to `.git/hooks/`
3. **Version markers:** Hook includes version or hash for detection
4. **Update check:** Hook warns if template newer than installed
5. **Documentation:** README explains template vs installed distinction

**Implementation Phase:**
- **Design:** Template in repo, install process documented
- **Build:** setup.sh with reinstall option
- **Maintain:** Reminder to reinstall after template updates

**Real Example:**

Current state:
```
githooks/pre-commit       (template, tracked)
.git/hooks/pre-commit     (installed, not tracked)
```

Problems:
- Update githooks/pre-commit → .git/hooks/ unchanged
- Different team members run setup.sh at different times
- No detection of drift

**Better Approach:**

Add version to template:
```bash
#!/bin/bash
# Version: 2.1.0
# Last updated: 2026-02-06
```

Check on execution:
```bash
HOOK_VERSION="2.1.0"
TEMPLATE="$REPO_ROOT/githooks/pre-commit"
if [ -f "$TEMPLATE" ]; then
    TEMPLATE_VERSION=$(grep "^# Version:" "$TEMPLATE" | cut -d' ' -f3)
    if [ "$HOOK_VERSION" != "$TEMPLATE_VERSION" ]; then
        echo "⚠️  Hook outdated: v$HOOK_VERSION (template: v$TEMPLATE_VERSION)"
        echo "Update with: ./setup.sh"
    fi
fi
```

Or hash-based:
```bash
HOOK_HASH=$(sha256sum "$0" | cut -d' ' -f1)
TEMPLATE_HASH=$(sha256sum "$TEMPLATE" | cut -d' ' -f1)
if [ "$HOOK_HASH" != "$TEMPLATE_HASH" ]; then
    echo "⚠️  Hook outdated. Update with: ./setup.sh"
fi
```

---

### 5.2 Stale COMMIT_EDITMSG Reads (Timing Bug)

**The Problem:**
- COMMIT_EDITMSG contains message from *previous* commit, not current
- Pre-commit hook runs before new message written
- Reading COMMIT_EDITMSG in pre-commit validates wrong commit
- Fails on second commit if first had issues, even though second doesn't
- Intermittent failures that seem inexplicable

**Warning Signs:**
- Validation fails on commit *after* problematic one
- First commit in fresh clone passes, second fails
- Error messages reference content not in current commit
- Failures disappear after deleting COMMIT_EDITMSG

**Prevention Strategy:**
1. **Never read COMMIT_EDITMSG in pre-commit** - data is stale
2. **Use commit-msg hook** for all commit message validation
3. **Check file timestamps** if must read in pre-commit
4. **Test with fresh clone** to catch timing issues

**Implementation Phase:**
- **Design:** Document which hook validates what
- **Build:** Place message validation in commit-msg only
- **Test:** Verify with sequence of commits in fresh repo

**Real Example (Bug in Current Pre-commit):**

```bash
# In pre-commit hook (lines 89-107):
COMMIT_MSG_FILE="$REPO_ROOT/.git/COMMIT_EDITMSG"

if [ -f "$COMMIT_MSG_FILE" ] && [ ! -f "$REPO_ROOT/.git/SQUASH_MSG" ]; then
    COMMIT_MSG=$(cat "$COMMIT_MSG_FILE")    # ← BUG: This is PREVIOUS commit

    if echo "$COMMIT_MSG" | grep -qiE 'AI-assisted'; then
        echo "ERROR: AI attribution detected"
        exit 1
    fi
fi
```

**Failure Scenario:**
```bash
# First commit (AI attribution):
git commit -m "feat: new feature

Co-Authored-By: Claude"

# Pre-commit runs - COMMIT_EDITMSG doesn't exist yet, passes

# Second commit (clean):
git commit -m "docs: update readme"

# Pre-commit runs - COMMIT_EDITMSG has PREVIOUS message ("Co-Authored-By: Claude")
# ERROR: AI attribution detected ← WRONG, current commit is clean!
```

**Fix:**
Move validation to commit-msg hook where it belongs:

```bash
# In commit-msg hook:
COMMIT_MSG_FILE=$1  # Passed as argument, contains CURRENT message
COMMIT_MSG=$(cat "$COMMIT_MSG_FILE")

if echo "$COMMIT_MSG" | grep -qiE 'AI-assisted|Co-Authored-By'; then
    echo "ERROR: AI attribution detected"
    exit 1
fi
```

---

### 5.3 Identity Hardcoding (Portability)

**The Problem:**
- Git user.name and user.email hardcoded in hooks
- Hook only works for specific person
- Can't share config with team or across machines
- Alternative identities (work vs personal) blocked

**Warning Signs:**
- Hook contains literal name/email
- Setup requires editing hook source
- Different team members can't use same hook
- Fails on CI/CD systems

**Prevention Strategy:**
1. **Read from git config** instead of hardcoding
2. **Validate existence, not value** - check git config is set, not what it's set to
3. **Deploy-time configuration** if validation truly needed
4. **Remove validation entirely** if solving non-problem

**Implementation Phase:**
- **Design:** Decide if identity validation actually needed
- **Build:** Use git config, env vars, or deploy-time input
- **Test:** Run as different user, different machine

**Real Example (Current Bug):**

```bash
# --- Identity Check ---
EXPECTED_NAME="henrycgbaker"
EXPECTED_EMAIL="henry.c.g.baker@gmail.com"

ACTUAL_NAME=$(git config user.name)
ACTUAL_EMAIL=$(git config user.email)

if [ "$ACTUAL_NAME" != "$EXPECTED_NAME" ]; then
    echo "ERROR: Git user.name is '$ACTUAL_NAME', expected '$EXPECTED_NAME'"
    exit 1
fi
```

**Problems:**
- Personal name hardcoded in shared template
- Can't use this hook if your name isn't "henrycgbaker"
- Breaks on work machine with different identity
- Solves no real problem (git already tracks identity)

**Options to Fix:**

**Option 1: Remove entirely** (best if no real need)
```bash
# Just delete the identity check. Git tracks identity in commits automatically.
# If someone commits with wrong identity, they'll notice and amend.
```

**Option 2: Check for existence, not value**
```bash
if [ -z "$(git config user.name)" ] || [ -z "$(git config user.email)" ]; then
    echo "ERROR: Git identity not configured"
    echo "Fix with: git config user.name 'Your Name'"
    echo "          git config user.email 'you@example.com'"
    exit 1
fi
# Ensures identity is set, but doesn't care what it is
```

**Option 3: Deploy-time configuration**
```bash
# In setup.sh:
read -p "Expected git user.name for this repo: " EXPECTED_NAME
read -p "Expected git user.email for this repo: " EXPECTED_EMAIL

# Write to project config (not hook source):
git config --local dotclaude.expected-name "$EXPECTED_NAME"
git config --local dotclaude.expected-email "$EXPECTED_EMAIL"

# In hook:
EXPECTED_NAME=$(git config dotclaude.expected-name)
EXPECTED_EMAIL=$(git config dotclaude.expected-email)
# Now compare
```

**Recommendation:** Option 1 (remove). Identity validation solves no real problem and creates portability issues.

---

### 5.4 Over-Restrictive Branch Protection

**The Problem:**
- Hooks block legitimate workflows
- Emergency fixes blocked by process
- Policy enforcement that makes work harder
- Bypassing hooks becomes routine
- False positives erode trust in automation

**Warning Signs:**
- Frequent `--no-verify` usage
- Team members complaining about hooks
- Policy exceptions for specific people
- Hooks disabled in CI/CD
- More time fighting hooks than they save

**Prevention Strategy:**
1. **Block errors, not workflows** - validate correctness, don't enforce process
2. **Emergency escape hatch** - document `--no-verify` for legitimate overrides
3. **Warning vs error** - prefer warnings for style, errors for bugs
4. **Branch-specific rules** - strict on main, relaxed on feature branches
5. **User feedback loop** - adjust hooks based on complaints

**Implementation Phase:**
- **Design:** Distinguish between "prevents bugs" and "enforces process"
- **Build:** Implement only bug-preventing hooks
- **Maintain:** Remove or relax hooks that annoy without benefit

**Real Example:**

Current pre-commit (lines 14-30):
```bash
# Allow commits on main if this is a squash merge (SQUASH_MSG exists)
if [ "$CURRENT_BRANCH" = "main" ] && [ ! -f "$REPO_ROOT/.git/SQUASH_MSG" ]; then
    echo "ERROR: Direct commits to 'main' are not allowed"
    echo "Workflow: Create a branch, commit freely, then squash merge when complete"
    exit 1
fi
```

**Questions:**
- Does this prevent bugs? No - it enforces process
- Is the process always right? No - hotfixes sometimes need direct commit
- Will users bypass? Probably - when workflow doesn't fit
- Does it add value? Debatable - document workflow, don't enforce

**Alternative Approach:**

Warning instead of error:
```bash
if [ "$CURRENT_BRANCH" = "main" ]; then
    echo "⚠️  WARNING: Committing directly to main"
    echo "Recommended workflow: feature branch → squash merge"
    echo "Press Ctrl-C to cancel, Enter to continue..."
    read -t 5  # 5 second timeout
fi
```

Or remove entirely:
```bash
# Document workflow in README, trust developers to follow it
# If direct commit happens, code review catches it
```

**Bug Prevention (Keep These):**
- AI attribution blocking (prevents policy violation)
- Sensitive file blocking (prevents security breach)
- Syntax errors (prevents broken code)

**Process Enforcement (Consider Removing):**
- Branch name requirements
- Commit message format (warnings OK)
- Identity validation (if no real need)
- Workflow prescriptions

---

## Summary: Meta-Pitfall Patterns

### The Complexity Trap
- Small problem → Over-engineered solution → Maintenance burden → Dead code
- Prevention: Simplicity bias, YAGNI, regular deletion

### The Context Crunch
- More rules → Less work space → Worse performance → More rules to compensate
- Prevention: Minimize always-loaded content, modular docs, use `/clear`

### The Maintenance Spiral
- Custom code → Bit rot → Bugs → Workarounds → More custom code
- Prevention: Prefer framework features, minimize hooks, regular audits

### The Assumption Avalanche
- Personal config → Hardcoded values → Breaks elsewhere → Special cases
- Prevention: Environment detection, deploy-time config, cross-platform testing

### The Feature Creep
- "What if..." → Unused flexibility → Complex for no benefit → Technical debt
- Prevention: Build for now, three-instance rule, ruthless deletion

---

## Recommended Practices

### Configuration Health Metrics
- **CLAUDE.md size:** <200 lines global, <100 lines project
- **Rules files:** <3 always-loaded files
- **Hook LOC:** <30 lines per hook, prefer settings.json
- **Dead code:** 0 commented blocks >10 lines
- **Duplicated framework code:** 0 lines

### Quarterly Audit Checklist
- [ ] Review CLAUDE.md - remove redundant instructions
- [ ] Check always-loaded rules - move contextual ones to projects
- [ ] Audit hooks - can settings.json replace any?
- [ ] Remove dead code - delete commented blocks
- [ ] Check for framework duplication - delete local copies
- [ ] Verify cross-platform compatibility
- [ ] Test in fresh clone as different user

### Design-Time Questions
- "Is this solving a current problem or hypothetical future?"
- "Can the framework do this already?"
- "Will this be in always-loaded context?"
- "Does this work on different machines/users?"
- "What's the maintenance burden?"
- "Can this be deleted later if unused?"

### Red Flags (Stop and Reconsider)
- "This will be flexible enough to..."
- "Let's make this configurable in case..."
- "We might need this later for..."
- "This is like X but better because..."
- Adding code to solve problem that hasn't happened yet

### Green Flags (Good Decisions)
- "This solves the immediate problem simply"
- "This uses built-in framework features"
- "This can be deleted easily if not needed"
- "This fails fast with clear error messages"
- "This works the same on any machine"

---

## Conclusion

Most configuration pitfalls stem from three root causes:

1. **Over-engineering** - Building for imagined futures instead of current needs
2. **Context bloat** - Loading more instructions than Claude can effectively use
3. **Reinvention** - Duplicating framework functionality with custom code

The antidote is aggressive simplicity: delete liberally, defer complexity, trust the framework, and build only what you need today.

**Key Principle:** Configuration should make Claude Code easier to use, not harder. If config causes more pain than it prevents, delete it.
