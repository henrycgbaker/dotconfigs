---
description: Show Docker container status and resource usage
allowed-tools: Bash
---

# Docker Status

Show current Docker container status and resource usage.

## Commands to Run

```bash
# Running containers with resource usage
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Resource usage
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"

# Recently stopped containers
docker ps -a --filter "status=exited" --format "table {{.Names}}\t{{.Status}}\t{{.CreatedAt}}" | head -10
```

## Summary Format

Present results as:
1. **Running Containers**: Name, status, ports
2. **Resource Usage**: CPU%, memory, network I/O
3. **Recently Stopped**: Any containers that exited recently (potential issues)

Flag any concerns:
- Containers restarting frequently
- High CPU/memory usage
- Unhealthy containers
- Containers that exited with non-zero codes
