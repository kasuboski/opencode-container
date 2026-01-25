# AGENTS.md

This file provides guidelines for agentic coding agents operating in this repository.

## Project Overview

This repository builds a Docker container for OpenCode deployment on Kubernetes. It contains:
- apko configuration for building Wolfi OS-based images
- melange configuration for building the mise package
- Makefile (build automation)
- versions.yml (version definitions)
- GitHub Actions CI/CD workflow

## Build Commands

```bash
# Install container-structure-test tool (for running tests)
make install-test-tools

# Build mise package only
make build-mise

# Build opencode package only
make build-opencode

# Build both packages (mise and opencode)
make build-packages

# Generate APKINDEX files for local repository
make index-packages

# Clean built packages
make clean-packages

# Build image with apko
make build-local

# Publish image
make publish

# Full build: packages + index + publish
make build

# Run structure tests on local image
make test-structure

# Run structure tests on published image
make test-structure-ci

# Show available targets and current versions
make help
```

The `opencode` package has `mise` as a build-time dependency in `melange/opencode/package.yaml`. This creates a circular dependency when building packages together locally because:

1. Building `mise` package requires Wolfi repository access
2. Building `opencode` package requires `mise` package (not yet built)
3. melange cannot find the local `mise` package when building `opencode`

**Solution in CI/CD:**
The GitHub Actions workflow builds packages sequentially:
1. Builds `mise` package first
2. Then builds `opencode` package (now `mise` is available in local repository)
3. Both packages use `--ignore-signatures` flag to bypass signature verification

**Local workaround:**
To build just the `mise` package locally:
```bash
make build-mise
```

Then manually build `opencode` after (if needed for testing).

### Local Package Repository

The project uses a local package repository for packages built with melange:

```
packages/
├── x86_64/
│   ├── APKINDEX.tar.gz
│   ├── mise-*.apk
│   └── opencode-*.apk
└── aarch64/
    ├── APKINDEX.tar.gz
    ├── mise-*.apk
    └── opencode-*.apk
```

The local repository is referenced in `apko/opencode.yaml` and contains:
- **mise package**: Built from source, installs to `/usr/bin/mise`
- **opencode package**: Built with melange, uses mise to install opencode, packages to `/opt/mise-seed/`

Version variables are read from `versions.yml` via yq:
```bash
OPENCODE_VERSION=$(shell yq e '.opencode' versions.yml)
MISE_VERSION=$(shell yq e '.mise' versions.yml)
```

## CI/CD

### Docker-based Package Building Limitation

**Note:** Docker-based package building is not supported because the chainguard/melange Docker image does not have Wolfi repositories pre-configured. Attempting to run melange in Docker container fails with "must provide at least one repository" error when trying to resolve build dependencies like `lua-5.1-dev`.

The CI/CD workflow uses GitHub Actions (Ubuntu runner) with melange installed directly, so it has full access to system package managers and repositories. This works correctly.

**To build packages locally for testing:**
1. Use GitHub Actions to build packages (PR will create artifacts)
2. Download .apk and APKINDEX.tar.gz files from Actions artifacts
3. Build image locally with `make build-local`

GitHub Actions workflow: `.github/workflows/ci.yml`
- Triggers on push to main (when versions.yml, apko configs, melange configs, or workflow changes)
- Triggers on all PRs to main (builds but does not push)
- Builds for linux/amd64 and linux/arm64 platforms
- Downloads and uses apko and melange CLI tools directly
- Builds local packages, generates APKINDEX files, then builds and publishes image
- Login to ghcr.io registry required (uses GITHUB_TOKEN)

## Code Style Guidelines

### apko YAML
- Use 2-space indentation
- Alphabetize packages in contents.packages
- Use explicit repository URLs
- Define accounts and paths declaratively
- Set entrypoint as command array
- Pin base image version in `contents.repositories`

### melange YAML
- Use 2-space indentation
- Pin package versions explicitly
- Use `uses:` pipeline steps where available
- Set expected-sha256/sha512 for fetch steps
- Use `strip` use to reduce binary size
- Use `test` section for package validation
- **Build-time dependencies**: Use `environment.contents.packages` to list packages needed during build (e.g., for opencode package, mise is listed as a build dependency so it's available to use in pipeline steps)
- **Run installed tools**: Pipeline steps can run commands from packages listed in `environment.contents.packages` (e.g., `mise install opencode@VERSION`)

### Makefile
- Use `:=` for variables read from shell commands
- Define `.PHONY` targets explicitly
- Use tabs for indentation (not spaces)
- Prefix internal variables with `?=` for override capability
- Include help target with variable documentation
- Use `$(shell ...)` for command substitution

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
opencode: 1.1.35
mise: 2026.1.6
# Wolfi packages (bun, uv, git, fd, ripgrep) use latest from repo by default
```

To update versions:
- opencode: Edit `versions.yml`, run `make update-opencode`, rebuild packages and image
- mise: Edit `melange/mise/package.yaml`, rebuild with melange
- Wolfi packages: Edit apko.yaml packages list or pin versions

### Updating opencode Version

Use the `update-opencode` make target to update the opencode package version:

```bash
# Update opencode version in versions.yml (e.g., to 1.1.36)
echo "opencode: 1.1.36" > versions.yml

# Update version in melange package YAML
make update-opencode

# Rebuild packages and image
make build
```

The `update-opencode` target uses `yq` to update the version in `melange/opencode/package.yaml` to match `versions.yml`.

## Error Handling

- melange: Pipeline steps fail on non-zero exit by default
- apko: Build fails if image references or packages are invalid
- Shell: Use `&&` to chain commands that should fail together
- Always verify download URLs before use

## Security

- Run container as non-root user (UID 1000, user: opencode)
- Use read-only root filesystem except for mounted volumes
- Never commit secrets; use Kubernetes secrets for passwords
- Use `stringData` for secret values that need encoding

## Important Notes

- This project does not include application code (no tests, no linting)
- The container is built from upstream releases (opencode, mise, Wolfi packages)
- Versions are NOT configurable at runtime; only at build time
- container-AGENTS.md documents the container environment for LLMs running inside
- README.md contains Kubernetes deployment examples

## Seed & Sync Pattern

The container uses a Seed & Sync pattern for persistent tool configuration:

1. **Seed build**: During image build, `/opt/mise-seed` directory is created (currently empty, mise available via Wolfi packages)
2. **Init container**: Copies seed tools to `/home/opencode/.local/share/mise` with `rsync --ignore-existing`
3. **Runtime**: mise reads from user data directory, respecting existing tools and plugins

This allows:
- Users to install additional tools via mise (persisted in volume)
- Upgrades to container don't overwrite user-installed tools

### First Run Setup
On first container run (or when starting a new environment), install opencode using mise:
```bash
# In the container or via exec
mise use opencode@$(OPENCODE_VERSION)
```

This will install opencode to your persistent mise data directory and make it available immediately. Future container restarts will preserve this installation via the seed sync.

Example initContainer:
```yaml
initContainers:
- name: seed-mise
  image: ghcr.io/user/opencode:latest
  command: ["/bin/sh", "-c"]
  args: ["rsync -a --ignore-existing /opt/mise-seed/ /home/opencode/.local/share/mise/"]
  volumeMounts:
  - name: mise-data
    mountPath: /home/opencode/.local/share/mise
```

## File Structure

```
.
├── .github/
│   └── workflows/
│       └── ci.yml
├── apko/
│   └── opencode.yaml
├── melange/
│   ├── .melange.yaml
│   └── mise/
│       └── package.yaml
├── packages/
│   └── x86_64/
│       └── mise-*.apk
├── AGENTS.md
├── container-AGENTS.md
├── Makefile
├── README.md
└── versions.yml
```

## Working with Versions

When updating component versions:

### opencode

1. **Edit versions.yml** with new version number:
   ```yaml
   opencode: 1.1.27
   ```

2. **Verify release URL** exists before committing:
   ```bash
   curl -sI "https://github.com/anomalyco/opencode/releases/download/v1.1.27/opencode-linux-x64-musl.tar.gz" | head -5
   ```

3. **Commit with descriptive message**:
   ```
   Bump opencode to 1.1.27
   ```

4. **CI automatically builds** and pushes on main branch

### mise

1. **Edit melange/mise/package.yaml** with new version:
   ```yaml
   package:
     version: 2024.11.38
   ```

2. **Update fetch URLs** and SHA256 checksums in the file

3. **Rebuild package**:
   ```bash
   melange build --arch x86_64,aarch64 melange/mise/package.yaml --repository-dir packages/
   ```

4. **Commit and push** to trigger image rebuild

### Wolfi packages (bun, uv, git, fd, ripgrep)

To pin specific Wolfi package versions, edit `apko/opencode.yaml`:
```yaml
contents:
  packages:
    - bun@1.1.36-r0
    - uv@0.9.22-r0
```

By default, packages use the latest version from the Wolfi repository.

## Common Tasks

### Building the mise package

```bash
melange build --arch x86_64,aarch64 melange/mise/package.yaml --repository-dir packages/
```

### Building the image

```bash
apko build apko/opencode.yaml ghcr.io/user/opencode:latest opencode.tar
```

### Adding a new Wolfi package

1. Add package to `apko/opencode.yaml` contents.packages (alphabetically sorted)
2. Test with `apko build`
3. Commit and push

### Updating GitHub Actions workflow

1. Pin all action versions to specific tags (not main/latest)
2. Test changes via PR (workflows run on PRs)
3. Merge to main to deploy changes

## Troubleshooting

### apko build failures
- Verify apko is installed: `which apko`
- Check apko.yaml syntax with `apko validate apko/opencode.yaml`
- Ensure repository URLs are accessible
- Verify package names exist in Wolfi repository

### melange build issues
- Verify melange is installed: `which melange`
- Check package.yaml syntax with `melange lint melange/mise/package.yaml`
- Verify fetch URLs and SHA256 checksums are correct
- Check .melange.yaml configuration exists

### Package repository access
- Verify network access to https://packages.wolfi.dev/os
- Check that architecture (x86_64, aarch64) is valid
- Ensure packages/ directory exists for melange output

### Version parsing errors
- Verify yq is installed: `which yq`
- Check versions.yml syntax: `yq e '.' versions.yml`

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
