PROJECT ?= UTM.xcodeproj
SCHEME ?= macOS
SDK ?= macosx
ARCHS ?= arm64
CONFIGURATION ?= Release
ARCHIVE_PATH ?= UTM
DERIVED_DATA ?= build/DerivedData
DOCKER ?= docker
DOCKERFILE ?= docker/Dockerfile
DOCKER_IMAGE ?= utm/xcode-builder:latest
DOCKER_PRIVILEGED ?= --privileged
TEAM_IDENTIFIER ?=

ifneq ($(strip $(XCODE_PATH)),)
DOCKER_VOLUME_XCODE := -v "$(XCODE_PATH)":"$(XCODE_PATH)":ro
DOCKER_ENV_XCODE := -e XCODE_PATH="$(XCODE_PATH)"
else
DOCKER_VOLUME_XCODE :=
DOCKER_ENV_XCODE :=
endif

ARCH_FLAGS := $(foreach arch,$(ARCHS),-arch $(arch))
TEAM_FLAG := $(if $(strip $(TEAM_IDENTIFIER)),-t $(TEAM_IDENTIFIER),)

.PHONY: build archive clean docker-image docker-build docker-shell docker-clean changelog

build:
	@echo "Building $(SCHEME) ($(CONFIGURATION)) for $(SDK) [$(ARCHS)]"
	@$(if $(ARCH_FLAGS),,echo "Warning: ARCHS is empty, using default toolchain architectures.";)
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIGURATION) -sdk $(SDK) $(ARCH_FLAGS) -derivedDataPath $(DERIVED_DATA) CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO

archive:
	@echo "Archiving $(SCHEME) ($(CONFIGURATION)) for $(SDK) [$(ARCHS)]"
	./scripts/build_utm.sh $(TEAM_FLAG) -k $(SDK) -s $(SCHEME) -a "$(ARCHS)" -o $(ARCHIVE_PATH)

clean:
	rm -rf "$(DERIVED_DATA)" "$(ARCHIVE_PATH).xcarchive"

docker-image:
	$(DOCKER) build -t $(DOCKER_IMAGE) -f $(DOCKERFILE) docker

docker-build: docker-image
	$(DOCKER) run --rm $(DOCKER_PRIVILEGED) \
		$(DOCKER_VOLUME_XCODE) \
		-e SCHEME="$(SCHEME)" \
		-e SDK="$(SDK)" \
		-e ARCHS="$(ARCHS)" \
		-e CONFIGURATION="$(CONFIGURATION)" \
		-e ARCHIVE_PATH="$(ARCHIVE_PATH)" \
		-e TEAM_IDENTIFIER="$(TEAM_IDENTIFIER)" \
		$(DOCKER_ENV_XCODE) \
		-v "$(CURDIR)":/workspace \
		-w /workspace \
		$(DOCKER_IMAGE)

docker-shell: docker-image
	$(DOCKER) run --rm -it $(DOCKER_PRIVILEGED) \
		$(DOCKER_VOLUME_XCODE) \
		$(DOCKER_ENV_XCODE) \
		-v "$(CURDIR)":/workspace \
		-w /workspace \
		$(DOCKER_IMAGE) /bin/bash

docker-clean:
	$(DOCKER) image rm $(DOCKER_IMAGE) || true

changelog:
	@echo "Generating changelog against $${UPSTREAM_REMOTE:-upstream}/$${UPSTREAM_BRANCH:-main}"
	python3 scripts/make_changelog.py
