# The version of Zarf to use. To keep this repo as portable as possible the Zarf binary will be downloaded and added to
# the build folder.
ZARF_VERSION := v0.28.2

# The version of the build harness container to use
BUILD_HARNESS_REPO := ghcr.io/defenseunicorns/build-harness/build-harness
BUILD_HARNESS_VERSION := 1.7.1

DUBBD_K3D_VERSION := 0.5.0

# Figure out which Zarf binary we should use based on the operating system we are on
ZARF_BIN := zarf
UNAME_S := $(shell uname -s)
UNAME_P := $(shell uname -p)
ifneq ($(UNAME_S),Linux)
	ifeq ($(UNAME_S),Darwin)
		ZARF_BIN := $(addsuffix -mac,$(ZARF_BIN))
	endif
	ifeq ($(UNAME_P),i386)
		ZARF_BIN := $(addsuffix -intel,$(ZARF_BIN))
	endif
	ifeq ($(UNAME_P),arm64)
		ZARF_BIN := $(addsuffix -apple,$(ZARF_BIN))
	endif
endif

# Silent mode by default. Run `make VERBOSE=1` to turn off silent mode.
ifndef VERBOSE
.SILENT:
endif

# Optionally add the "-it" flag for docker run commands if the env var "CI" is not set (meaning we are on a local machine and not in github actions)
TTY_ARG :=
ifndef CI
	TTY_ARG := -it
endif

.DEFAULT_GOAL := help

# Idiomatic way to force a target to always run, by having it depend on this dummy target
FORCE:

.PHONY: help
help: ## Show a list of all targets
	grep -E '^\S*:.*##.*$$' $(MAKEFILE_LIST) \
	| sed -n 's/^\(.*\): \(.*\)##\(.*\)/\1:\3/p' \
	| column -t -s ":"

########################################################################
# Utility Section
########################################################################

.PHONY: docker-save-build-harness
docker-save-build-harness: ## Pulls the build harness docker image and saves it to a tarball
	mkdir -p .cache/docker
	docker pull $(BUILD_HARNESS_REPO):$(BUILD_HARNESS_VERSION)
	docker save -o .cache/docker/build-harness.tar $(BUILD_HARNESS_REPO):$(BUILD_HARNESS_VERSION)

.PHONY: docker-load-build-harness
docker-load-build-harness: ## Loads the saved build harness docker image
	docker load -i .cache/docker/build-harness.tar

.PHONY: run-pre-commit-hooks
run-pre-commit-hooks: ## Run all pre-commit hooks. Returns nonzero exit code if any hooks fail. Uses Docker for maximum compatibility
	mkdir -p .cache/pre-commit
	docker run --rm -v "${PWD}:/app" --workdir "/app" -e "PRE_COMMIT_HOME=/app/.cache/pre-commit" $(BUILD_HARNESS_REPO):$(BUILD_HARNESS_VERSION) bash -c 'git config --global --add safe.directory /app && asdf install && pre-commit run -a'

.PHONY: fix-cache-permissions
fix-cache-permissions: ## Fixes the permissions on the pre-commit cache
	docker run --rm -v "${PWD}:/app" --workdir "/app" -e "PRE_COMMIT_HOME=/app/.cache/pre-commit" $(BUILD_HARNESS_REPO):$(BUILD_HARNESS_VERSION) chmod -R a+rx .cache

########################################################################
# Test Section
########################################################################

.PHONY: test
test: ## Run all automated tests. Requires access to an AWS account. Costs money. Requires env vars "REPO_URL", "GIT_BRANCH", "REGISTRY1_USERNAME", "REGISTRY1_PASSWORD", "GHCR_USERNAME", "GHCR_PASSWORD" and standard AWS env vars.
	mkdir -p .cache/go
	mkdir -p .cache/go-build
	echo "Running automated tests. This will take several minutes. At times it does not log anything to the console. If you interrupt the test run you will need to log into AWS console and manually delete any orphaned infrastructure."
	docker run $(TTY_ARG) --rm \
	-v "${PWD}:/app" \
	-v "${PWD}/.cache/go:/root/go" \
	-v "${PWD}/.cache/go-build:/root/.cache/go-build" \
	--workdir "/app/test/e2e" \
	-e GOPATH=/root/go \
	-e GOCACHE=/root/.cache/go-build \
	-e REPO_URL \
	-e GIT_BRANCH \
	-e REGISTRY1_USERNAME \
	-e REGISTRY1_PASSWORD \
	-e GHCR_USERNAME \
	-e GHCR_PASSWORD \
	-e AWS_REGION \
	-e AWS_DEFAULT_REGION \
	-e AWS_ACCESS_KEY_ID \
	-e AWS_SECRET_ACCESS_KEY \
	-e AWS_SESSION_TOKEN \
	-e AWS_SECURITY_TOKEN \
	-e AWS_SESSION_EXPIRATION \
	-e SKIP_SETUP -e SKIP_TEST \
	-e SKIP_TEARDOWN \
	-e AWS_AVAILABILITY_ZONE \
	$(BUILD_HARNESS_REPO):$(BUILD_HARNESS_VERSION) \
	bash -c 'asdf install && go test -v -timeout 2h -p 1 ./...'

.PHONY: test-ssh
test-ssh: ## Run this if you set SKIP_TEARDOWN=1 and want to SSH into the still-running test server. Don't forget to unset SKIP_TEARDOWN when you're done
	cd test/tf/public-ec2-instance && terraform init
	cd test/tf/public-ec2-instance/.test-data && cat Ec2KeyPair.json | jq -r .PrivateKey > privatekey.pem && chmod 600 privatekey.pem
	cd test/tf/public-ec2-instance && ssh -i .test-data/privatekey.pem ubuntu@$$(terraform output public_instance_ip | tr -d '"')

########################################################################
# Cluster Section
########################################################################

cluster/full: cluster/destroy cluster/create build/all deploy/all ## This will destroy any existing cluster, create a new one, then build and deploy all

cluster/create: ## Create a k3d cluster with metallb installed
	k3d cluster create k3d-test-cluster --config utils/k3d/k3d-config.yaml -v /etc/machine-id:/etc/machine-id@server:*
	k3d kubeconfig merge k3d-test-cluster -o /home/${USER}/cluster-kubeconfig.yaml
	utils/metallb/install.sh
	echo "Cluster is ready!"

cluster/destroy: ## Destroy the k3d cluster
	k3d cluster delete k3d-test-cluster

########################################################################
# Build Section
########################################################################

build/all: build build/zarf build/zarf-init.sha256 build/dubbd-pull-k3d.sha256 build/test-pkg-deps build/uds-package-software-factory ##

build: ## Create build directory
	mkdir -p build

.PHONY: clean
clean: ## Clean up build files
	rm -rf ./build

build/zarf: | build ## Download the Linux flavor of Zarf to the build dir
	echo "Downloading zarf"
	curl -sL https://github.com/defenseunicorns/zarf/releases/download/$(ZARF_VERSION)/zarf_$(ZARF_VERSION)_Linux_amd64 -o build/zarf
	chmod +x build/zarf

build/zarf-mac-intel: | build ## Download the Mac (Intel) flavor of Zarf to the build dir
	echo "Downloading zarf-mac-intel"
	curl -sL https://github.com/defenseunicorns/zarf/releases/download/$(ZARF_VERSION)/zarf_$(ZARF_VERSION)_Darwin_amd64 -o build/zarf-mac-intel
	chmod +x build/zarf-mac-intel

build/zarf-init.sha256: | build ## Download the init package
	echo "Downloading zarf-init-amd64-$(ZARF_VERSION).tar.zst"
	curl -sL https://github.com/defenseunicorns/zarf/releases/download/$(ZARF_VERSION)/zarf-init-amd64-$(ZARF_VERSION).tar.zst -o build/zarf-init-amd64-$(ZARF_VERSION).tar.zst
	echo "Creating shasum of the init package"
	shasum -a 256 build/zarf-init-amd64-$(ZARF_VERSION).tar.zst | awk '{print $$1}' > build/zarf-init.sha256

build/dubbd-pull-k3d.sha256: | build ## Download dubbd k3d oci package
	./build/zarf package pull oci://ghcr.io/defenseunicorns/packages/dubbd-k3d:$(DUBBD_K3D_VERSION)-amd64 --oci-concurrency 9 --output-directory build
	echo "Creating shasum of the dubbd-k3d package"
	shasum -a 256 build/zarf-package-dubbd-k3d-amd64-$(DUBBD_K3D_VERSION).tar.zst | awk '{print $$1}' > build/dubbd-pull-k3d.sha256

build/test-pkg-deps: | build ## Build package dependencies for testing
	build/zarf package create utils/pkg-deps/namespaces/ --skip-sbom --confirm --output-directory build
	build/zarf package create utils/pkg-deps/gitlab/postgres/ --skip-sbom --confirm --output-directory build
	build/zarf package create utils/pkg-deps/gitlab/redis/ --skip-sbom --confirm --output-directory build
	build/zarf package create utils/pkg-deps/gitlab/minio/ --skip-sbom --confirm --output-directory build

build/uds-package-software-factory: | build ## Build the software factory
	build/zarf package create . --skip-sbom --confirm --output-directory build

########################################################################
# Deploy Section
########################################################################

deploy/all: deploy/init deploy/dubbd-k3d deploy/test-pkg-deps deploy/uds-package-software-factory ##

deploy/init: ## Deploy the zarf init package
	./build/zarf init --confirm --components=git-server

deploy/dubbd-k3d: ## Deploy the k3d flavor of DUBBD
	cd ./build && ./zarf package deploy zarf-package-dubbd-k3d-amd64-$(DUBBD_K3D_VERSION).tar.zst --confirm

deploy/test-pkg-deps: ## Deploy the package dependencies needed for testing the software factory
	cd ./build && ./zarf package deploy zarf-package-swf-namespaces-* --confirm
	cd ./build && ./zarf package deploy zarf-package-gitlab-postgres-* --confirm
	cd ./build && ./zarf package deploy zarf-package-gitlab-redis-* --confirm
	cd ./build && ./zarf package deploy zarf-package-gitlab-minio-* --confirm

deploy/uds-package-software-factory: ## Deploy the software factory package
	cd ./build && ./zarf package deploy zarf-package-software-factory-*.tar.zst --confirm
