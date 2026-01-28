# OpenCode Container Environment

This document describes the OpenCode container environment for AI assistants.

## Overview

- **Base**: Alpine Linux 3.23
- **User**: `opencode` (UID 1000), non-root
- **Filesystem**: Read-only root, `/projects` is writable

## Environment Variables

### Runtime Variables

- `OPENCODE_SERVER_PASSWORD` - **Required**. Password for web UI authentication.
- `HOME=/home/opencode` - User home directory
- `USER=opencode` - Username
- `OPENCODE_CONFIG_DIR` - Optional. Override default config location (`$HOME/.opencode/`)

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
| `bun` | JavaScript runtime and package manager |
| `uv` | Fast Python package manager |
| `mise` | Development tools manager (asdf alternative) |
| `git` | Version control |
| `fd` | Fast file finder |
| `ripgrep` | Fast text search |

### Tool Usage

```bash
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

## Mise Configuration

Mise is installed with persistent data storage in `~/.local`. Tool installations, plugins, and state are persisted when a volume is mounted over `~/.local`.

### Environment Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `MISE_INSTALL_PATH` | `/usr/local/bin/mise` | Binary installation location |
| `MISE_DATA_DIR` | `/home/opencode/.local/share/mise` | Tool installations, plugins, shims |
| `MISE_CONFIG_DIR` | `/home/opencode/.config/mise` | Global configuration |
| `MISE_CACHE_DIR` | `/home/opencode/.cache/mise` | Download cache |
| `MISE_STATE_DIR` | `/home/opencode/.local/state/mise` | State tracking data |

### Data Persistence

- **Persisted via volume mount**: Tools, plugins, shims, state (`~/.local/share/mise/*`, `~/.local/state/mise/*`)
- **Ephemeral**: Global config (`~/.config/mise/config.toml`) - mount ConfigMap if persistence needed

### Common Commands

```bash
# Install a tool
mise install node@20

# Use a tool version for current shell
mise use node@20

# List available versions
mise ls-remote node

# List installed tools
mise ls

# Update mise (if needed)
mise self-update
```

### Project-Level Configuration

Add `.mise.toml` or `.mise/config.toml` to project directories (persisted via `/projects` mount):

```toml
[tools]
node = "20.11.0"
python = "3.12"
```

See https://mise.jdx.dev/ for full documentation.

## Security

- Runs as non-root user (UID 1000)
- Read-only root filesystem
- Password required for web UI when `OPENCODE_SERVER_PASSWORD` is set

## Network

- Port: 4096
- Host: 0.0.0.0 (all interfaces)
