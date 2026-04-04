# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| 1.x     | Yes       |

## Reporting a Vulnerability

If you discover a security vulnerability, please report it responsibly:

1. **Do not** open a public GitHub issue
2. Email the maintainer or use GitHub's private vulnerability reporting feature
3. Include a description of the vulnerability and steps to reproduce
4. Allow reasonable time for a fix before public disclosure

## Security Considerations

This project generates bash scripts that modify the local filesystem (Wine prefix). The scripts:

- Validate all file paths to prevent path traversal attacks
- Never execute with elevated privileges (no `sudo` in scripts)
- Pin all external downloads to verified sources (GitHub API only)
- Use `set -euo pipefail` for strict error handling in all bash scripts
