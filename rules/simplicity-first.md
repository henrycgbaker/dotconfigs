# Simplicity First (Occam's Razor)

Always choose the simplest solution that solves the stated problem. Avoid complexity, over-engineering, and hypothetical future scenarios.

## Core Principles

### Minimum Viable Solution
- Solve **only what was asked**, nothing more
- If a task can be done in 3 lines, don't create a utility function
- If a feature doesn't require error handling, don't add it
- If a problem doesn't need abstraction, don't abstract it

### No Premature Abstractions
- **Three lines of code** is better than a one-use helper function
- **One simple loop** is better than a factory pattern for a single case
- **Direct code** is better than over-parameterized utilities
- Only generalize when you actually have **three or more** similar implementations

### No Hypothetical Features
- Don't build for "future requirements" that don't exist
- Don't add configurability "just in case"
- Don't design for scale you haven't reached
- **Don't add backwards-compatibility shims when code can just change** -  this is vital

### Validation Boundaries Only
- Validate at system edges: user input, external APIs, file I/O
- **Trust internal code** — don't validate within your own functions
- Don't add error handling for scenarios that can't happen
- Don't chain defensive checks for framework guarantees

### Design for Current Requirements
- Skip feature flags unless explicitly needed
- Avoid "what if?" scenarios in implementation
- Don't add unused parameters or options
- Remove code that becomes dead weight

## What This Looks Like in Practice

### ❌ Over-engineered
```python
class ConfigurableLogger:
    def __init__(self, level="INFO", format="json", output="file"):
        self.config = {
            "level": level,
            "format": format,
            "output": output
        }

    def log(self, message, metadata=None, backtrace=False):
        # 50 lines of conditional logic for features not used
```

### ✅ Simple
```python
def log(message: str) -> None:
    print(f"[{time.now()}] {message}")
```

## Anti-Patterns to Avoid

1. **Builder patterns for single use** — Just pass args
2. **Abstract base classes for one subclass** — Remove the abstraction
3. **Generic utility functions** — Inline the logic if used once
4. **Feature flags for unreleased work** — Just commit working code
5. **Comprehensive error handling** — Handle what can actually fail
6. **Configuration files for constants** — Hardcode what's static
7. **Dependency injection everywhere** — Only inject what varies

## Decision Framework

Ask yourself:

- **Is this solving the stated problem?** → Keep it
- **Will this code actually be reused?** → Maybe generalize
- **Does this scenario actually happen?** → Handle it
- **Would this be simpler to inline?** → Inline it
- **Am I building for a future I'm guessing at?** → Stop

When in doubt, **start simple** and refactor only when patterns emerge from real code, not imagination.
