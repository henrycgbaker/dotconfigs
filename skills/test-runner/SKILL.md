---
name: test-runner
description: Run pytest tests, analyze failures, and help fix broken tests. Use when tests fail, need running, or coverage needs checking.
allowed-tools: Bash, Read, Grep
---

# Test Runner

Run pytest and analyze test results.

## When to Use
- Running test suite
- Tests are failing
- Checking coverage
- Debugging test issues

## Process

### 1. Run Tests
```bash
# All tests
pytest tests/ -v

# Specific file
pytest tests/test_module.py -v

# Specific test
pytest tests/test_module.py::test_function -v

# With coverage
pytest tests/ --cov=src --cov-report=term-missing
```

### 2. Analyze Failures
Look for:
- Assertion errors (expected vs actual)
- Import errors (missing deps)
- Fixture errors (setup issues)
- Timeout errors (slow tests)

### 3. Debug Options
```bash
# Show print statements
pytest -s

# Stop on first failure
pytest -x

# Show locals in traceback
pytest -l

# Run last failed
pytest --lf

# Verbose traceback
pytest --tb=long
```

### 4. Coverage Analysis
```bash
# HTML report
pytest --cov=src --cov-report=html

# Check minimum coverage
pytest --cov=src --cov-fail-under=80
```

## Common Patterns

### Fixtures
```python
@pytest.fixture
def sample_data():
    return {"key": "value"}

def test_something(sample_data):
    assert sample_data["key"] == "value"
```

### Parametrize
```python
@pytest.mark.parametrize("input,expected", [
    (1, 2),
    (2, 4),
])
def test_double(input, expected):
    assert double(input) == expected
```

### Markers
```bash
# Run only marked tests
pytest -m "not slow"
pytest -m "integration"
```

## Troubleshooting

### Import Errors
- Check PYTHONPATH includes src/
- Verify `__init__.py` files exist
- Install package in editable mode: `pip install -e .`

### Fixture Not Found
- Check fixture is in conftest.py or imported
- Verify fixture scope matches test needs

### Flaky Tests
- Add `@pytest.mark.flaky(reruns=3)`
- Check for shared state between tests
- Verify test isolation
