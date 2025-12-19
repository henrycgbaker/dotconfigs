---
description: Show GPU status, utilization, and processes
allowed-tools: Bash
---

# GPU Status

Show current GPU status with utilization, memory, and running processes.

## Commands to Run

```bash
# GPU overview
nvidia-smi

# Processes using GPU
nvidia-smi --query-compute-apps=pid,name,used_memory --format=csv

# Detailed GPU info
nvidia-smi --query-gpu=name,memory.total,memory.used,memory.free,utilization.gpu,temperature.gpu --format=csv
```

## Summary Format

Present results as:
1. **GPU Overview**: Model, driver version, CUDA version
2. **Memory**: Used/Total per GPU
3. **Utilization**: GPU % and memory %
4. **Temperature**: Current temps
5. **Processes**: List of processes using GPUs with memory usage

Flag any concerns (high temp >80°C, memory >90%, high utilization without expected workload).
