# OpenCode Container Environment

This document describes the OpenCode container environment for AI assistants.

## Overview

- **Base**: Wolfi OS
- **User**: `opencode` (UID 1000), non-root
- **Filesystem**: Read-only root, `/projects` is writable

## Environment Variables

### Runtime Variables

- `OPENCODE_SERVER_PASSWORD` - **Required**. Password for web UI authentication.
- `HOME=/home/opencode` - User home directory
- `USER=opencode` - Username
- `OPENCODE_CONFIG_DIR` - Optional. Override default config location (`$HOME/.opencode/`)

### Mise Environment Variables

- `MISE_DATA_DIR` - Where mise stores tools and data (default: `$HOME/.local/share/mise`)
- `MISE_CONFIG_DIR` - Where mise configuration lives (default: `$HOME/.config/mise`)
- `MISE_CACHE_DIR` - Download cache location (default: `$HOME/.cache/mise`)

Note: In production, `MISE_DATA_DIR` is set to `/home/opencode/.local/share/mise` and synced from `/opt/mise-seed` via init container. The seed directory is currently empty; install opencode manually on first run using `mise use opencode@VERSION`.

## Mount Points

### `/projects` (Read-Write)

External storage mount for project files. Git repositories should be cloned here.

```bash
# Example: Clone a repository
cd /projects
git clone https://github.com/example/project.git
```

## Available Tools

| Tool | Purpose |
|------|---------|
| `opencode` | AI coding agent |
| `mise` | Polyglot tool version manager |
| `bun` | JavaScript runtime and package manager |
| `uv` | Fast Python package manager |
| `git` | Version control |
| `fd` | Fast file finder |
| `ripgrep` | Fast text search |

### Tool Usage

```bash
# Mise tool manager
mise install node@20
mise use python@3.11
mise ls-remote node

# List installed tools
mise list

# Uninstall a tool
mise uninstall node@20

# OpenCode serve (starts web UI on port 4096)
opencode serve --hostname 0.0.0.0 --port 4096

# Bun package manager
bun install
bun run script

# UV package manager
uv pip install package
uv run python script

# File search
fd "*.py" /projects

# Text search
rg "TODO" /projects
```

## Configuration

Configuration files should be placed in:

1. Default: `$HOME/.opencode/`
2. Custom: `$OPENCODE_CONFIG_DIR/` (if set)

Example structure:
```
/home/opencode/.opencode/
├── opencode.jsonc      # Main configuration
├── instructions.md     # Custom instructions
└── .opencode/          # Additional settings
```

### Mise Configuration

Mise configuration files should be placed in:

1. Global: `$HOME/.config/mise/config.toml`
2. Project-specific: `.mise.toml` or `.mise/config.toml` in any directory

Example global config structure:
```toml
[tools]
python = "3.11"
node = "20"

[settings]
experimental = true
```

Note: In production, the Seed & Sync pattern ensures pre-installed tools (like opencode) are available in `MISE_DATA_DIR`. User-installed tools via `mise install` persist to the same directory.

## Security

- Runs as non-root user (UID 1000)
- Read-only root filesystem
- Password required for web UI when `OPENCODE_SERVER_PASSWORD` is set

## Network

- Port: 4096
- Host: 0.0.0.0 (all interfaces)
