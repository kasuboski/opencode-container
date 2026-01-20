ARG ALPINE_VERSION=3.23
FROM alpine:${ALPINE_VERSION} AS base

ARG OPENCODE_VERSION=1.1.26
ARG BUN_VERSION=latest
ARG UV_VERSION=latest

ENV OPENCODE_VERSION=${OPENCODE_VERSION}
ENV BUN_VERSION=${BUN_VERSION}
ENV UV_VERSION=${UV_VERSION}

RUN apk add --no-cache \
    bash \
    ca-certificates \
    curl \
    fd \
    gcompat \
    git \
    libgcc \
    libstdc++ \
    ripgrep \
    tar \
    unzip \
    xz

RUN curl -fsSL https://bun.sh/install | bash

RUN set -e && \
    UV_INSTALL_SCRIPT_URL="https://astral.sh/uv/install.sh" && \
    if [ "${UV_VERSION}" != "latest" ]; then \
    UV_INSTALL_SCRIPT_URL="https://astral.sh/uv/${UV_VERSION}/install.sh"; \
    fi && \
    curl -LsSf "${UV_INSTALL_SCRIPT_URL}" | sh

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

FROM build-${TARGETARCH} AS final

RUN addgroup -g 1000 opencode && \
    adduser -u 1000 -G opencode -s /bin/sh -D opencode

ENV HOME=/home/opencode
ENV USER=opencode
ENV PATH=/home/opencode/.bun/bin:/usr/local/bin:/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin

RUN chown -R opencode:opencode /home/opencode && \
    mkdir -p /projects && \
    chown -R opencode:opencode /projects

COPY --chown=opencode:opencode container-AGENTS.md /home/opencode/.config/opencode/AGENTS.md

USER opencode

WORKDIR /projects

EXPOSE 4096

ENTRYPOINT ["opencode", "serve", "--hostname", "0.0.0.0", "--port", "4096"]
