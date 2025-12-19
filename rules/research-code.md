# Research Code Standards

## Reproducibility
- Set random seeds explicitly for all random operations
- Log all hyperparameters and configuration
- Pin dependency versions in requirements.txt or pyproject.toml
- Document hardware/environment used for experiments

## Seed Setting
```python
import random
import numpy as np
import torch

def set_seed(seed: int = 42):
    random.seed(seed)
    np.random.seed(seed)
    torch.manual_seed(seed)
    if torch.cuda.is_available():
        torch.cuda.manual_seed_all(seed)
```

## Experiment Tracking
- Log experiment parameters at start
- Track metrics over time (loss, accuracy, etc.)
- Save model checkpoints with metadata
- Use tools like MLflow, W&B, or simple JSON logs

## Data Versioning
- Document data sources and preprocessing steps
- Consider DVC or similar for large dataset versioning
- Track dataset statistics (size, distribution, splits)

## Results
- Save raw results, not just aggregates
- Include confidence intervals or error bars
- Document any manual interventions or anomalies
- Make figures reproducible from saved data
