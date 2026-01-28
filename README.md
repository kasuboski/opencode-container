# OpenCode Container

A containerized OpenCode deployment for Kubernetes with pre-installed tools (bun, uv, git, fd, ripgrep).

## About

This repository contains:
- **Dockerfile**: Multi-stage Alpine Linux build for opencode, bun, uv, and utilities
- **Makefile**: Build automation that reads versions from `versions.yml`
- **GitHub Actions**: CI/CD pipeline for multi-architecture builds
- **container-AGENTS.md**: Detailed container environment documentation for AI assistants

## Quick Start

### Prerequisites

- Docker with buildx support
- yq (for reading versions.yml)
- Access to GitHub Container Registry (for published images)

### Build the Image

```bash
# Build multi-arch image and push to registry
make build REGISTRY=ghcr.io/youruser TAG=latest

# Build single arch for local testing
make build-amd64 TAG=test
make build-arm64 TAG=test

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
bun: 1.1.35
uv: 0.9.21
mise: v2026.1.8
```

To update versions:
1. Edit `versions.yml`
2. Commit and push to main
3. GitHub Actions automatically builds and pushes the new image

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

For global mise configuration, mount a ConfigMap to `/home/opencode/.config/mise/config.toml` if persistence is needed (otherwise the config is ephemeral).

### Mount Points

| Path | Access | Description |
|------|--------|-------------|
| `/projects` | Read-Write | Project files and git repositories |
| `~/.local` | Optional | OpenCode and mise data (tools, plugins, state) |

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

## Image Details

- **Base**: Alpine Linux 3.23
- **Architecture**: amd64, arm64
- **User**: Non-root (opencode, UID 1000)
- **Filesystem**: Read-only root, writable `/projects`
- **Port**: 4096 (configurable via Service/Ingress)

## CI/CD

GitHub Actions workflow (`.github/workflows/ci.yml`):
- Builds on push to main (when `versions.yml`, `Dockerfile`, or workflow changes)
- Builds on all PRs to main (no push)
- Uses GitHub Actions cache for faster builds
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
        volumeMounts:
        - name: projects-storage
          mountPath: /projects
        - name: opencode-persistent
          mountPath: /home/opencode/.local
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
      - name: opencode-persistent
        emptyDir: {}
        # Alternatively, use a PVC for persistence:
        # persistentVolumeClaim:
        #   claimName: opencode-persistent-pvc
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
