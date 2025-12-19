---
name: container-inspector
description: Inspect Docker containers for debugging and monitoring. Use when containers have issues, need health checks, or resource monitoring.
allowed-tools: Bash, Grep
---

# Container Inspector

Debug and monitor Docker containers.

## When to Use
- Container not starting or crashing
- Checking container health
- Monitoring resource usage
- Debugging networking issues

## Process

### 1. Check Container Status
```bash
# List running containers
docker ps

# List all containers (including stopped)
docker ps -a

# Container details
docker inspect <container>
```

### 2. View Logs
```bash
# All logs
docker logs <container>

# Follow logs
docker logs -f <container>

# Last N lines
docker logs --tail 100 <container>

# With timestamps
docker logs -t <container>
```

### 3. Resource Usage
```bash
# Real-time stats
docker stats

# Single snapshot
docker stats --no-stream

# Specific container
docker stats <container>
```

### 4. Execute Commands
```bash
# Interactive shell
docker exec -it <container> /bin/bash

# Run command
docker exec <container> ps aux
```

## Docker Compose

### Status
```bash
docker-compose ps
docker-compose logs
docker-compose logs -f <service>
```

### Restart
```bash
docker-compose restart <service>
docker-compose up -d <service>
```

## Common Issues

### Container Won't Start
```bash
# Check exit code
docker ps -a --filter "name=<container>"

# View logs
docker logs <container>

# Check config
docker inspect <container> | grep -A 10 "State"
```

### Out of Memory
```bash
# Check memory limits
docker inspect <container> | grep -i memory

# Check actual usage
docker stats <container> --no-stream
```

### Networking Issues
```bash
# Check network config
docker network ls
docker network inspect <network>

# Check container IP
docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' <container>
```

### GPU Access
```bash
# Check GPU availability
docker exec <container> nvidia-smi

# Verify GPU runtime
docker inspect <container> | grep -i runtime
```

## Cleanup

```bash
# Remove stopped containers
docker container prune

# Remove unused images
docker image prune

# Remove all unused resources
docker system prune
```
