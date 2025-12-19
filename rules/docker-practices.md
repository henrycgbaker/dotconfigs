# Docker Best Practices

> Applied when working with Dockerfiles and docker-compose.

## Base Images
- Pin specific versions (e.g., `python:3.11-slim` not `python:latest`)
- For GPU workloads: use `nvidia/cuda:*-runtime-ubuntu*` base images
- Prefer `-slim` variants for smaller images

## Multi-stage Builds
- Use multi-stage builds to separate build and runtime dependencies
- Copy only necessary artifacts to final stage
- Label build stages clearly

## Security
- Run as non-root user when possible
- Don't store secrets in images (use runtime env vars or secrets)
- Use `.dockerignore` to exclude sensitive files
- Avoid `sudo` in containers unless explicitly required

## GPU Containers
- Set `NVIDIA_VISIBLE_DEVICES` appropriately
- Use `--gpus` flag or `deploy.resources.reservations.devices` in compose
- Consider memory limits for GPU workloads

## Compose
- Use named volumes for persistent data
- Define explicit networks for service isolation
- Use `depends_on` with health checks for startup ordering
- Environment variables in `.env` files (not committed)
