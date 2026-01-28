ARG ALPINE_VERSION=3.23
FROM alpine:${ALPINE_VERSION} AS base

ARG OPENCODE_VERSION=1.1.26
ARG BUN_VERSION=latest
ARG UV_VERSION=latest
ARG MISE_VERSION=v2026.1.8

ENV OPENCODE_VERSION=${OPENCODE_VERSION}
ENV BUN_VERSION=${BUN_VERSION}
ENV UV_VERSION=${UV_VERSION}
ENV MISE_VERSION=${MISE_VERSION}
ENV MISE_INSTALL_PATH=/usr/local/bin/mise
ENV MISE_DATA_DIR=/home/opencode/.local/share/mise
ENV MISE_CONFIG_DIR=/home/opencode/.config/mise
ENV MISE_CACHE_DIR=/home/opencode/.cache/mise
ENV MISE_STATE_DIR=/home/opencode/.local/state/mise

RUN apk add --no-cache \
    bash=5.3.3-r1 \
    ca-certificates=20251003-r0 \
    curl=8.17.0-r1 \
    fd=10.2.0-r3 \
    gcompat=1.1.0-r4 \
    git=2.52.0-r0 \
    libgcc=15.2.0-r2 \
    libstdc++=15.2.0-r2 \
    ripgrep=15.1.0-r0 \
    tar=1.35-r4 \
    unzip=6.0-r16 \
    xz=5.8.2-r0

SHELL ["/bin/ash", "-o", "pipefail", "-e", "-c"]

RUN curl -fsSL https://bun.sh/install | bash

RUN set -e && \
    UV_INSTALL_SCRIPT_URL="https://astral.sh/uv/install.sh" && \
    if [ "${UV_VERSION}" != "latest" ]; then \
    UV_INSTALL_SCRIPT_URL="https://astral.sh/uv/${UV_VERSION}/install.sh"; \
    fi && \
    curl -LsSf "${UV_INSTALL_SCRIPT_URL}" | sh

RUN curl https://mise.run | MISE_VERSION=${MISE_VERSION} sh

FROM base AS build-amd64
ARG OPENCODE_VERSION
RUN ARCH="x64" && \
    OPENCODE_URL="https://github.com/anomalyco/opencode/releases/download/v${OPENCODE_VERSION}/opencode-linux-${ARCH}-musl.tar.gz" && \
    curl -fsSL "${OPENCODE_URL}" -o opencode.tar.gz && \
    tar -xzf opencode.tar.gz && \
    mv opencode /usr/local/bin/ && \
    rm -f opencode.tar.gz && \
    chmod +x /usr/local/bin/opencode

FROM base AS build-arm64
ARG OPENCODE_VERSION
RUN ARCH="arm64" && \
    OPENCODE_URL="https://github.com/anomalyco/opencode/releases/download/v${OPENCODE_VERSION}/opencode-linux-${ARCH}-musl.tar.gz" && \
    curl -fsSL "${OPENCODE_URL}" -o opencode.tar.gz && \
    tar -xzf opencode.tar.gz && \
    mv opencode /usr/local/bin/ && \
    rm -f opencode.tar.gz && \
    chmod +x /usr/local/bin/opencode

# hadolint ignore=DL3006
FROM build-${TARGETARCH} AS final

RUN addgroup -g 1000 opencode && \
    adduser -u 1000 -G opencode -s /bin/sh -D opencode

ENV HOME=/home/opencode
ENV USER=opencode
ENV PATH=/home/opencode/.local/share/mise/shims:/home/opencode/.bun/bin:/usr/local/bin:/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin

RUN chown -R opencode:opencode /home/opencode && \
    mkdir -p /projects && \
    chown -R opencode:opencode /projects && \
    mkdir -p /home/opencode/.local/share/mise \
             /home/opencode/.local/state/mise \
             /home/opencode/.config/mise \
             /home/opencode/.cache/mise \
             /home/opencode/.cache/opencode && \
    chown -R opencode:opencode /home/opencode/.local \
                            /home/opencode/.config/mise \
                            /home/opencode/.cache/mise \
                            /home/opencode/.cache/opencode


COPY --chown=opencode:opencode container-AGENTS.md /home/opencode/.config/opencode/AGENTS.md

USER opencode

WORKDIR /projects

EXPOSE 4096

ENTRYPOINT ["opencode", "serve", "--hostname", "0.0.0.0", "--port", "4096"]
