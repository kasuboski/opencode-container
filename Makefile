REGISTRY ?= ghcr.io/$(USER)
IMAGE_NAME ?= opencode
TAG ?= latest

OPENCODE_VERSION := $(shell yq e '.opencode' versions.yml)
MISE_VERSION := $(shell yq e '.mise' versions.yml)

# apko config file
APKO_CONFIG := apko/opencode.yaml

.PHONY: setup-seed
setup-seed:
	docker run --rm \
		-v "$(PWD):/work" \
		-v "$(PWD)/apko/opencode.yaml:/work/apko.yaml:ro" \
		-v "$(PWD)/versions.yml:/work/versions.yml:ro" \
		-v "$(PWD)/scripts/first-run-setup.sh:/work/setup.sh:ro" \
		-w /work \
		ghcr.io/wolfi-base/wolfi-base:latest \
		sh -c "/work/setup.sh"

.PHONY: build-local
build-local:
	apko build $(APKO_CONFIG) $(IMAGE_NAME):$(TAG) $(IMAGE_NAME).tar

.PHONY: publish
publish:
	apko publish $(APKO_CONFIG) $(REGISTRY)/$(IMAGE_NAME):$(TAG)

.PHONY: build
build: publish

.PHONY: help
help:
	@echo "Available targets:"
	@echo "  setup-seed  - Setup /opt/mise-seed with opencode (run after building image)"
	@echo "  build-local  - Build image with apko for local testing"
	@echo "  publish     - Build and publish multi-arch image to registry"
	@echo "  build       - Full build: publish image"
	@echo "  help        - Show this help message"
	@echo ""
	@echo "Variables:"
	@echo "  REGISTRY     - Container registry (default: ghcr.io/\$$USER)"
	@echo "  IMAGE_NAME  - Image name (default: opencode)"
	@echo "  TAG         - Image tag (default: latest)"
	@echo ""
	@echo "Versions (from versions.yml):"
	@echo "  OPENCODE_VERSION - $(OPENCODE_VERSION)"
	@echo "  MISE_VERSION     - $(MISE_VERSION)"
