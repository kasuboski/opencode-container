# AGENTS.md

This file provides guidelines for agentic coding agents operating in this repository.

## Project Overview

This repository builds a Docker container for OpenCode deployment on Kubernetes. It contains:
- Dockerfile (multi-stage Alpine Linux build)
- mise.toml (build automation with mise tasks)
- versions.yml (version definitions)
- GitHub Actions CI/CD workflow

## Build Commands

```bash
# Multi-arch build and push to registry
mise run build REGISTRY=ghcr.io/user TAG=latest

# Single-arch builds for local testing
TAG=test mise run build-amd64
TAG=test mise run build-arm64

# Push existing image to registry
mise run push

# List available tasks
mise tasks ls
```

Version variables are automatically read from `versions.yml` by mise tasks via template functions.

## CI/CD

GitHub Actions workflow: `.github/workflows/ci.yml`
- Triggers on push to main (when versions.yml, Dockerfile, or workflow changes)
- Triggers on all PRs to main (builds but does not push)
- Builds for linux/amd64 and linux/arm64 platforms
- Uses GitHub Actions cache for faster builds

## Code Style Guidelines

### Dockerfile
- Use multi-stage builds for smaller final image
- Pin Alpine version (e.g., `ARG ALPINE_VERSION=3.23`)
- Use `--no-cache` with apk to reduce image size
- Combine related RUN commands to reduce layers
- Use `ARG` for version variables, `ENV` for runtime variables
- Quote variables in curl URLs to prevent injection
- Use `set -e` for error handling in RUN commands
- Alphabetize packages in apk add for readability

### mise.toml
- Use `[vars]` section for variable definitions
- Use template functions (`{{ exec(...) }}`) for command substitution
- Use `{{ vars.variable_name }}` for variable interpolation
- Define tasks in `[tasks.task-name]` sections
- Use `description` field for task documentation
- Use `run` field for commands (arrays or multi-line strings)

### YAML Files
- Use 2-space indentation
- Alphabetize keys within sections where appropriate
- Use explicit types (strings, not implicit)
- Add comments for non-obvious configurations

### GitHub Actions
- Pin action versions (e.g., `actions/checkout@v4`)
- Use `id` on steps that produce outputs
- Quote template expressions (e.g., `${{ ... }}`)
- Use conditional `if` for push/destructive operations

## Version Management

All component versions are defined in `versions.yml` as the single source of truth:
```yaml
opencode: 1.1.26
bun: 1.1.35
uv: 0.9.21
```

To update versions:
1. Edit `versions.yml`
2. Commit and push to main (CI will auto-build)
3. PRs work the same but do not push images

## Error Handling

- Dockerfile: Use `set -e` at the start of RUN commands
- mise: Tasks run with `set -e` by default
- Shell: Use `&&` to chain commands that should fail together
- Always verify download URLs before use

## Security

- Run container as non-root user (UID 1000, user: opencode)
- Use read-only root filesystem except for mounted volumes
- Never commit secrets; use Kubernetes secrets for passwords
- Use `stringData` for secret values that need encoding

## Important Notes

- This project does not include application code (no tests, no linting)
- The container is built from upstream releases (opencode, bun, uv)
- Versions are NOT configurable at runtime; only at build time
- container-AGENTS.md documents the container environment for LLMs running inside
- README.md contains Kubernetes deployment examples

## File Structure

```
.
├── .dockerignore           # Exclusions for Docker build context
├── .github/
│   └── workflows/
│       └── ci.yml          # GitHub Actions CI/CD pipeline
├── container-AGENTS.md     # Container environment docs for AI assistants
├── Dockerfile              # Multi-stage Alpine Linux build
├── mise.toml              # Build automation tasks
├── README.md               # User-facing documentation
└── versions.yml            # Single source of truth for versions
```

## Working with Versions

When updating component versions:

1. **Edit versions.yml** with new version numbers:
   ```yaml
   opencode: 1.1.27
   bun: 1.1.36
   uv: 0.9.22
   ```

2. **Verify download URLs** exist before committing:
   ```bash
   curl -sI "https://github.com/anomalyco/opencode/releases/download/v1.1.27/opencode-linux-x64-musl.tar.gz" | head -5
   ```

3. **Commit with descriptive message**:
   ```
   Bump opencode to 1.1.27, bun to 1.1.36, uv to 0.9.22
   ```

4. **CI automatically builds** and pushes on main branch

## Docker Build Best Practices

- Always use specific version tags, not `:latest` in production
- Clean up temporary files in the same RUN layer they were created
- Use COPY instead of ADD unless fetching from URL
- Minimize layers by combining related commands
- Pin base image versions for reproducibility

## Common Tasks

### Adding a new dependency to the container

1. Add package to Dockerfile's apk add command (alphabetically sorted)
2. Test with `TAG=test mise run build-amd64`
3. Update versions.yml if version changes
4. Commit and push

### Updating a component version

1. Update version in versions.yml
2. Verify release URL exists
3. Commit and push
4. CI will build and push automatically

### Modifying GitHub Actions workflow

1. Pin all action versions to specific tags (not main/latest)
2. Test changes via PR (workflows run on PRs)
3. Merge to main to deploy changes

## Troubleshooting

### Build failures
- Check Docker daemon is running
- Verify network access for downloading assets
- Ensure buildx is supported: `docker buildx version`

### Multi-arch build issues
- Ensure buildx builder is created: `docker buildx create --use`
- Use `--platform linux/amd64,linux/arm64` explicitly

### Task execution issues
- Ensure mise is installed: `mise --version`
- List available tasks: `mise tasks ls`
- Check task details: `mise tasks info <task-name>`

<!-- opensrc:start -->

## Source Code Reference

Source code for dependencies is available in `opensrc/` for deeper understanding of implementation details.

See `opensrc/sources.json` for the list of available packages and their versions.

Use this source code when you need to understand how a package works internally, not just its types/interface.

### Fetching Additional Source Code

To fetch source code for a package or repository you need to understand, run:

```bash
bunx opensrc <package>           # npm package (e.g., npx opensrc zod)
bunx opensrc pypi:<package>      # Python package (e.g., npx opensrc pypi:requests)
bunx opensrc crates:<package>    # Rust crate (e.g., npx opensrc crates:serde)
bunx opensrc <owner>/<repo>      # GitHub repo (e.g., npx opensrc vercel/ai)
```

<!-- opensrc:end -->
