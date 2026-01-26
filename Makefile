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

# Wolfi repository configuration
WOLFI_REPO := https://packages.wolfi.dev/os
WOLFI_KEY := https://packages.wolfi.dev/os/wolfi-signing.rsa.pub
LOCAL_REPO := $(PWD)/packages

# Docker image for package building
MELANGE_DOCKER_IMAGE := ghcr.io/wolfi-dev/sdk:latest

# Detect host OS/arch for container-structure-test
UNAME_S := $(shell uname -s)
UNAME_M := $(shell uname -m)
OS := $(if $(filter Darwin,$(UNAME_S)),darwin,$(if $(filter Linux,$(UNAME_S)),linux,$(error Unsupported OS: $(UNAME_S))))
ARCH := $(if $(filter x86_64,$(UNAME_M)),amd64,$(if $(filter arm64,$(UNAME_M)),arm64,$(if $(filter aarch64,$(UNAME_M)),arm64,$(error Unsupported arch: $(UNAME_M)))))
CONTAINER_STRUCTURE_TEST := container-structure-test-$(OS)-$(ARCH)
CONTAINER_STRUCTURE_TEST_URL := https://github.com/GoogleContainerTools/container-structure-test/releases/latest/download/$(CONTAINER_STRUCTURE_TEST)

.PHONY: install-test-tools
install-test-tools:
	@echo "Installing container-structure-test..."
	@if [ ! -f "$(CONTAINER_STRUCTURE_TEST)" ]; then \
		curl -fsSL $(CONTAINER_STRUCTURE_TEST_URL) -o $(CONTAINER_STRUCTURE_TEST); \
		chmod +x $(CONTAINER_STRUCTURE_TEST); \
	else \
		echo "container-structure-test already installed"; \
	fi

.PHONY: build-packages
build-packages:
	@echo "Building mise package..."
	melange build \
		--keyring-append $(WOLFI_KEY) \
		--repository-append $(WOLFI_REPO) \
		--repository-append $(LOCAL_REPO) \
		--arch x86_64,aarch64 \
		--ignore-signatures \
		melange/mise/package.yaml
	@echo "Building opencode package..."
	melange build \
		--keyring-append $(WOLFI_KEY) \
		--repository-append $(WOLFI_REPO) \
		--repository-append $(LOCAL_REPO) \
		--arch x86_64,aarch64 \
		--ignore-signatures \
		melange/opencode/package.yaml

.PHONY: index-packages
index-packages:
	@echo "Generating APKINDEX files..."
	cd $(PACKAGES_DIR)/x86_64 && melange index -o APKINDEX.tar.gz *.apk
	cd $(PACKAGES_DIR)/aarch64 && melange index -o APKINDEX.tar.gz *.apk

.PHONY: clean-packages
clean-packages:
	@echo "Cleaning built packages..."
	rm -rf $(PACKAGES_DIR)/x86_64/* $(PACKAGES_DIR)/aarch64/*

.PHONY: build-mise-docker
build-mise-docker:
	@echo "Building mise package with Docker..."
	docker run --privileged \
		-v "$(PWD):/work" \
		-w /work \
		--entrypoint=melange \
		$(MELANGE_DOCKER_IMAGE) \
		build \
		--keyring-append $(WOLFI_KEY) \
		--repository-append $(WOLFI_REPO) \
		--repository-append $(LOCAL_REPO) \
		--ignore-signatures \
		--arch x86_64,aarch64 \
		melange/mise/package.yaml

.PHONY: build-opencode-docker
build-opencode-docker:
	@echo "Building opencode package with Docker..."
	docker run --privileged \
		-v "$(PWD):/work" \
		-w /work \
		--entrypoint=melange \
		$(MELANGE_DOCKER_IMAGE) \
		build \
		--keyring-append $(WOLFI_KEY) \
		--repository-append $(WOLFI_REPO) \
		--repository-append $(LOCAL_REPO) \
		--ignore-signatures \
		--arch x86_64,aarch64 \
		melange/opencode/package.yaml

.PHONY: build-packages-docker
build-packages-docker: build-mise-docker build-opencode-docker
	@echo "All packages built with Docker"

.PHONY: update-opencode
update-opencode:
	@echo "Updating opencode version in melange/opencode/package.yaml..."
	yq e -i '.package.version = "$(OPENCODE_VERSION)"' melange/opencode/package.yaml

.PHONY: build-local
build-local:
	@echo "Building apko image..."
	apko build $(APKO_CONFIG) $(IMAGE_NAME):$(TAG) $(IMAGE_NAME).tar --arch host --ignore-signatures

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
	@echo "  build-packages       - Build mise and opencode packages with melange (direct)"
	@echo "  build-packages-docker - Build mise and opencode packages with Docker"
	@echo "  build-mise-docker    - Build mise package with Docker"
	@echo "  build-opencode-docker - Build opencode package with Docker"
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
