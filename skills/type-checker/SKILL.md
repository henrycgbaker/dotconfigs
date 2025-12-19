---
name: type-checker
description: Run MyPy type checking and help fix type errors. Use when type hints are missing, incorrect, or MyPy reports errors.
allowed-tools: Bash, Read, Edit, Grep
---

# Type Checker

Run MyPy and fix type annotation issues.

## When to Use
- MyPy reports type errors
- Adding type hints to existing code
- Validating type safety of changes

## Process

### 1. Run Type Check
```bash
mypy <file_or_directory> --show-error-codes
```

### 2. Analyze Errors
Common error types:
- `[arg-type]`: Wrong argument type
- `[return-value]`: Wrong return type
- `[assignment]`: Incompatible assignment
- `[attr-defined]`: Missing attribute
- `[no-untyped-def]`: Missing type hints

### 3. Fix Types
Use Python 3.10+ syntax:
```python
# Good
def process(items: list[str]) -> dict[str, int]:
    result: dict[str, int] = {}
    return result

# For optional
def get_value(key: str) -> str | None:
    ...
```

### 4. Verify
```bash
mypy <file> --strict
```

## Type Hint Patterns

### Collections
```python
list[str]           # not List[str]
dict[str, int]      # not Dict[str, int]
set[int]            # not Set[int]
tuple[int, str]     # fixed length
tuple[int, ...]     # variable length
```

### Unions and Optional
```python
str | int           # not Union[str, int]
str | None          # not Optional[str]
```

### Callable
```python
from collections.abc import Callable
Callable[[int, str], bool]  # (int, str) -> bool
```

### TypeVar for Generics
```python
from typing import TypeVar
T = TypeVar("T")
def first(items: list[T]) -> T: ...
```
