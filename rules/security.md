# Security Practices

## Secrets Management
- Never hardcode secrets, API keys, or passwords in code
- Use environment variables for sensitive configuration
- Keep `.env` files out of version control
- Use secrets management (e.g., Docker secrets, vault) for production

## Input Validation
- Validate all external input (user input, API responses, file contents)
- Sanitize data at system boundaries
- Don't trust internal data blindly in public-facing code

## Common Vulnerabilities
- Avoid shell injection: use subprocess with lists, not shell=True
- Avoid path traversal: validate and sanitize file paths
- Avoid SQL injection: use parameterized queries
- Avoid command injection: never interpolate user input into commands

## File Operations
- Use absolute paths or validate relative paths
- Check file permissions before sensitive operations
- Don't follow symlinks blindly in security-sensitive contexts

## Logging
- Never log secrets, tokens, or passwords
- Sanitize PII in logs where possible
- Use structured logging for audit trails
