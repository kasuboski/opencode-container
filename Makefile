REGISTRY ?= ghcr.io/$(USER)
IMAGE_NAME ?= opencode
TAG ?= latest

OPENCODE_VERSION := $(shell yq e '.opencode' versions.yml)
BUN_VERSION := $(shell yq e '.bun' versions.yml)
UV_VERSION := $(shell yq e '.uv' versions.yml)

.PHONY: build
build:
	docker buildx build \
		--platform linux/amd64,linux/arm64 \
		--build-arg OPENCODE_VERSION=$(OPENCODE_VERSION) \
		--build-arg BUN_VERSION=$(BUN_VERSION) \
		--build-arg UV_VERSION=$(UV_VERSION) \
		--tag $(REGISTRY)/$(IMAGE_NAME):$(TAG) \
		--push .

.PHONY: build-amd64
build-amd64:
	docker build \
		--platform linux/amd64 \
		--build-arg OPENCODE_VERSION=$(OPENCODE_VERSION) \
		--build-arg BUN_VERSION=$(BUN_VERSION) \
		--build-arg UV_VERSION=$(UV_VERSION) \
		--tag $(IMAGE_NAME):$(TAG)-amd64 \
		.

.PHONY: build-arm64
build-arm64:
	docker build \
		--platform linux/arm64 \
		--build-arg OPENCODE_VERSION=$(OPENCODE_VERSION) \
		--build-arg BUN_VERSION=$(BUN_VERSION) \
		--build-arg UV_VERSION=$(UV_VERSION) \
		--tag $(IMAGE_NAME):$(TAG)-arm64 \
		.

.PHONY: push
push:
	docker push $(REGISTRY)/$(IMAGE_NAME):$(TAG)

.PHONY: help
help:
	@echo "Available targets:"
	@echo "  build     - Build multi-arch image and push to registry"
	@echo "  build-amd64 - Build amd64 image locally"
	@echo "  build-arm64 - Build arm64 image locally"
	@echo "  push      - Push image to registry"
	@echo "  help      - Show this help message"
	@echo ""
	@echo "Variables:"
	@echo "  REGISTRY  - Container registry (default: ghcr.io/\$$USER)"
	@echo "  IMAGE_NAME - Image name (default: opencode)"
	@echo "  TAG       - Image tag (default: latest)"
	@echo ""
	@echo "Versions (from versions.yml):"
	@echo "  OPENCODE_VERSION - $(OPENCODE_VERSION)"
	@echo "  BUN_VERSION - $(BUN_VERSION)"
	@echo "  UV_VERSION - $(UV_VERSION)"
