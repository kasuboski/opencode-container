# OpenCode Container

A containerized OpenCode deployment for Kubernetes with pre-installed tools (bun, uv, git, fd, ripgrep) and mise tool manager.

## About

This repository contains:
- **apko configs**: Wolfi OS base image with opencode, bun, uv, and utilities
- **melange configs**: Custom mise package build from source
- **Makefile**: Build automation that reads versions from `versions.yml`
- **GitHub Actions**: CI/CD pipeline for multi-architecture builds
- **container-AGENTS.md**: Detailed container environment documentation for AI assistants

## Quick Start

### Prerequisites

- Docker with buildx support
- apko (for building OCI images)
- melange (for building packages)
- yq (for reading versions.yml)
- Access to GitHub Container Registry (for published images)

### Build the Image

```bash
# Build and publish multi-arch image to registry
make publish REGISTRY=ghcr.io/youruser TAG=latest

# Build local single arch for testing
make build-local ARCH=amd64 TAG=test
make build-local ARCH=arm64 TAG=test

# View available targets and current versions
make help
```

### Run Locally

```bash
# Run the container locally
docker run -d \
  --name opencode \
  -p 4096:4096 \
  -e OPENCODE_SERVER_PASSWORD=your-password \
  -v projects-data:/projects \
  ghcr.io/user/opencode:latest

# Access at http://localhost:4096
```

## Version Management

Versions are defined in `versions.yml`:

```yaml
opencode: 1.1.26
mise: 2024.11.37
# Wolfi packages (bun, uv, git, fd, ripgrep) use latest from repo by default
# To pin specific versions, edit apko/opencode.yaml directly
```

To update versions:
1. Edit `versions.yml` for opencode or mise
2. For Wolfi packages (bun, uv, git, fd, ripgrep), edit `apko/opencode.yaml`
3. Commit and push to main
4. GitHub Actions automatically builds and pushes the new image

## Configuration

### Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `OPENCODE_SERVER_PASSWORD` | Yes | Password for web UI authentication |
| `OPENCODE_CONFIG_DIR` | No | Custom config directory (default: `$HOME/.opencode/`) |

### Configuration Files

Place OpenCode configuration in `$HOME/.opencode/`:
```
/home/opencode/.opencode/
├── opencode.jsonc      # Main configuration
├── instructions.md     # Custom instructions
└── .opencode/          # Additional settings
```

### Mount Points

| Path | Access | Description |
|------|--------|-------------|
| `/projects` | Read-Write | Project files and git repositories |

## Seed & Sync Pattern

This container uses the "Seed & Sync" pattern to manage tool persistence in Kubernetes.

### The Problem: Mount Masking
When you mount a Kubernetes Persistent Volume (PV) to a path (e.g., `/home/opencode/.local/share/mise`), it acts like a "new sheet of paper" placed over the existing folder. This makes tools installed during the image build invisible.

### The Solution: Seed & Sync
Instead of installing tools directly to the final destination, they're installed to a "Seed" directory (`/opt/mise-seed`) during the image build. At runtime, an init container syncs these tools to the PV using `rsync --ignore-existing`, which preserves user-installed tool versions.

### Implementation
- **Build time**: Tools installed to `/opt/mise-seed` (currently empty, mise available via Wolfi packages)
- **Runtime**: Uses `MISE_DATA_DIR=/home/opencode/.local/share/mise`
- **Init Container**: Syncs `/opt/mise-seed/` → `/home/opencode/.local/share/mise/` with `--ignore-existing`

### First Run Setup
On first container run (or when starting a new environment), install opencode using mise:
```bash
# In the container or via exec
mise use opencode@1.1.26
```

This will install opencode to your persistent mise data directory and make it available immediately. Future container restarts will preserve this installation via the seed sync.

### Benefits
- Pre-installed tools (opencode) start instantly
- User-installed tools persist across pod restarts
- User tool upgrades aren't overwritten on restart
- Files owned by the container user (UID 1000)

## Available Tools

| Tool | Purpose |
|------|---------|
| `opencode` | AI coding agent |
| `mise` | Tool version manager (installed via melange) |
| `bun` | JavaScript runtime and package manager |
| `uv` | Fast Python package manager |
| `git` | Version control |
| `fd` | Fast file finder |
| `ripgrep` | Fast text search |

## Image Details

- **Base**: Wolfi OS (apko-built)
- **Architecture**: amd64, arm64
- **User**: Non-root (opencode, UID 1000)
- **Filesystem**: Read-only root, writable `/projects`, `/home/opencode/.local/share/mise`
- **Port**: 4096 (configurable via Service/Ingress)

## CI/CD

GitHub Actions workflow (`.github/workflows/ci.yml`):
- Builds on push to main (when `versions.yml`, `apko/`, `melange/`, or workflow changes)
- Builds on all PRs to main (no push)
- Uses GitHub Actions cache for faster apko/melange builds
- Pushes to ghcr.io on main branch only

## Security

- Runs as non-root user (UID 1000)
- Read-only root filesystem by default
- Password-protected web UI
- Recommended Kubernetes security context:
  ```yaml
  securityContext:
    runAsUser: 1000
    runAsNonRoot: true
    readOnlyRootFilesystem: true
  ```

---

## Kubernetes Deployment

### Secret

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: opencode-secret
type: Opaque
stringData:
  password: "your-secure-password"
```

### Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: opencode
spec:
  replicas: 1
  selector:
    matchLabels:
      app: opencode
  template:
    metadata:
      labels:
        app: opencode
    spec:
      securityContext:
        runAsUser: 1000
        runAsNonRoot: true
        readOnlyRootFilesystem: true
      initContainers:
      - name: sync-mise-seed
        image: ghcr.io/user/opencode:latest
        command: ["/bin/sh", "-c", "rsync -av --ignore-existing /opt/mise-seed/ /home/opencode/.local/share/mise/"]
        volumeMounts:
        - name: mise-data
          mountPath: /home/opencode/.local/share/mise
      containers:
      - name: opencode
        image: ghcr.io/user/opencode:latest
        ports:
        - containerPort: 4096
        env:
        - name: OPENCODE_SERVER_PASSWORD
          valueFrom:
            secretKeyRef:
              name: opencode-secret
              key: password
        - name: MISE_DATA_DIR
          value: /home/opencode/.local/share/mise
        volumeMounts:
        - name: projects-storage
          mountPath: /projects
        - name: mise-data
          mountPath: /home/opencode/.local/share/mise
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "2Gi"
            cpu: "1000m"
      volumes:
      - name: projects-storage
        persistentVolumeClaim:
          claimName: opencode-projects-pvc
      - name: mise-data
        persistentVolumeClaim:
          claimName: opencode-mise-pvc
```

### Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: opencode
spec:
  selector:
    app: opencode
  ports:
  - port: 80
    targetPort: 4096
  type: ClusterIP
```

### Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: opencode
spec:
  rules:
  - host: opencode.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: opencode
            port:
              number: 80
```
