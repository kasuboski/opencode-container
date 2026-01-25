REGISTRY ?= ghcr.io/$(USER)
IMAGE_NAME ?= opencode
TAG ?= latest

OPENCODE_VERSION := $(shell yq e '.opencode' versions.yml)
MISE_VERSION := $(shell yq e '.mise' versions.yml)

# apko config file
APKO_CONFIG := apko/opencode.yaml

# Package directory
PACKAGES_DIR := packages

# Structure test config
STRUCTURE_TEST_CONFIG := tests/structure-test.yaml

# Download container-structure-test for current platform
CONTAINER_STRUCTURE_TEST_URL := https://github.com/GoogleContainerTools/container-structure-test/releases/latest/download/container-structure-test-darwin-arm64
CONTAINER_STRUCTURE_TEST := container-structure-test-darwin-arm64

.PHONY: install-test-tools
install-test-tools:
	@echo "Installing container-structure-test..."
	@if [ ! -f "$(CONTAINER_STRUCTURE_TEST)" ]; then \
		curl -fsSLO $(CONTAINER_STRUCTURE_TEST_URL) -o $(CONTAINER_STRUCTURE_TEST); \
		chmod +x $(CONTAINER_STRUCTURE_TEST); \
	else \
		echo "container-structure-test already installed"; \
	fi

.PHONY: build-packages
build-packages:
	@echo "Building mise package..."
	cd melange/mise && melange build --arch x86_64,aarch64 package.yaml --repository-dir ../../$(PACKAGES_DIR)/
	@echo "Building opencode package..."
	cd melange/opencode && melange build --arch x86_64,aarch64 package.yaml --repository-dir ../../$(PACKAGES_DIR)/ --ignore-signatures

.PHONY: index-packages
index-packages:
	@echo "Generating APKINDEX files..."
	cd $(PACKAGES_DIR)/x86_64 && melange index -o APKINDEX.tar.gz *.apk
	cd ../aarch64 && melange index -o APKINDEX.tar.gz *.apk

.PHONY: clean-packages
clean-packages:
	@echo "Cleaning built packages..."
	rm -rf $(PACKAGES_DIR)/x86_64/* $(PACKAGES_DIR)/aarch64/*

.PHONY: update-opencode
update-opencode:
	@echo "Updating opencode version in melange/opencode/package.yaml..."
	yq e -i '.package.version = "$(OPENCODE_VERSION)" melange/opencode/package.yaml

.PHONY: build-local
build-local:
	@echo "Building apko image..."
	apko build $(APKO_CONFIG) $(IMAGE_NAME):$(TAG) $(IMAGE_NAME).tar --ignore-signatures

.PHONY: publish
publish:
	apko publish $(APKO_CONFIG) $(REGISTRY)/$(IMAGE_NAME):$(TAG) --ignore-signatures

.PHONY: build
build: build-packages index-packages publish

.PHONY: help
help:
	@echo "Available targets:"
	@echo "  install-test-tools   - Download container-structure-test tool"
	@echo "  update-opencode     - Update opencode version in melange package YAML"
	@echo "  build-packages       - Build mise and opencode packages with melange"
	@echo "  index-packages       - Generate APKINDEX files for local repository"
	@echo "  clean-packages       - Remove all built packages"
	@echo "  build-local         - Build image with apko for local testing"
	@echo "  publish            - Build and publish multi-arch image to registry"
	@echo "  build              - Full build: packages + index + publish image"
	@echo "  test-structure     - Run structure tests on local image (text output)"
	@echo "  test-structure-json - Run structure tests on local image (JSON output)"
	@echo "  test-structure-ci   - Run structure tests on published image"
	@echo "  help               - Show this help message"
	@echo ""
	@echo "Variables:"
	@echo "  REGISTRY            - Container registry (default: ghcr.io/\$$USER)"
	@echo "  IMAGE_NAME         - Image name (default: opencode)"
	@echo "  TAG                - Image tag (default: latest)"
	@echo ""
	@echo "Versions (from versions.yml):"
	@echo "  OPENCODE_VERSION - $(OPENCODE_VERSION)"
	@echo "  MISE_VERSION     - $(MISE_VERSION)"
