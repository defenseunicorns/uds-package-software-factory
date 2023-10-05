# The version of Zarf to use. To keep this repo as portable as possible the Zarf binary will be downloaded and added to
# the build folder.
# renovate: datasource=github-tags depName=defenseunicorns/zarf
UDS_CLI_VERSION := v0.0.5-alpha

ZARF_VERSION := v0.29.2

# The version of the build harness container to use
BUILD_HARNESS_REPO := ghcr.io/defenseunicorns/build-harness/build-harness
# renovate: datasource=docker depName=ghcr.io/defenseunicorns/build-harness/build-harness
BUILD_HARNESS_VERSION := 1.10.2
# renovate: datasource=docker depName=ghcr.io/defenseunicorns/packages/dubbd-k3d extractVersion=^(?<version>\d+\.\d+\.\d+)
DUBBD_K3D_VERSION := 0.10.1

# Figure out which Zarf binary we should use based on the operating system we are on
ZARF_BIN := zarf
UNAME_S := $(shell uname -s)
UNAME_M := $(shell uname -m)
ifeq ($(UNAME_M),x86_64)
    ARCH := amd64
else ifeq ($(UNAME_M),amd64)
    ARCH := amd64
else ifeq ($(UNAME_M),arm64)
    ARCH := arm64
else
    $(error Unsupported architecture: $(UNAME_M))
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

.PHONY: start-proxy
start-proxy:
	cd build && ../utils/start-proxy.sh

.PHONY: stop-proxy
stop-proxy:
	cd build && ../utils/stop-proxy.sh

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
	-e LATEST_VERSION \
	-e UPGRADE \
	-e COPY_BUNDLE \
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

cluster/reset: cluster/destroy cluster/create cluster/calico cluster/metallb ## This will destroy any existing cluster and then create a new one

cluster/create: ## Create a k3d cluster with no CNI
	K3D_FIX_MOUNTS=1 k3d cluster create k3d-test-cluster --config utils/k3d/k3d-config.yaml
	k3d kubeconfig merge k3d-test-cluster -o /home/${USER}/cluster-kubeconfig.yaml

cluster/calico: ## Install calico
	echo "Installing Calico..."
	kubectl apply --wait=true -f utils/calico/calico.yaml 2>&1 >/dev/null
	echo "Waiting for Calico to be ready..."
	kubectl rollout status deployment/calico-kube-controllers -n kube-system --watch --timeout=90s 2>&1 >/dev/null
	kubectl rollout status daemonset/calico-node -n kube-system --watch --timeout=90s 2>&1 >/dev/null
	kubectl wait --for=condition=Ready pods --all --all-namespaces 2>&1 >/dev/null

cluster/metallb: ## Install metallb
	utils/metallb/install.sh

cluster/destroy: ## Destroy the k3d cluster
	k3d cluster delete k3d-test-cluster

########################################################################
# Build Section
########################################################################

.PHONY: build/all
build/all: build build/zarf build/uds build/software-factory-namespaces build/idam-dns build/idam-realm build/idam-gitlab build/idam-sonarqube build/uds-bundle-software-factory ## Build everything

build: ## Create build directory
	mkdir -p build

.PHONY: clean
clean: ## Clean up build files
	rm -rf ./build

.PHONY: build/zarf
build/zarf: | build ## Download the Zarf to the build dir
	if [ -f build/zarf ] && [ "$$(build/zarf version)" = "$(ZARF_VERSION)" ] ; then exit 0; fi && \
	echo "Downloading zarf" && \
	curl -sL https://github.com/defenseunicorns/zarf/releases/download/$(ZARF_VERSION)/zarf_$(ZARF_VERSION)_$(UNAME_S)_$(ARCH) -o build/zarf && \
	chmod +x build/zarf

.PHONY: build/uds
build/uds: | build ## Download uds-cli to the build dir
	if [ -f build/uds ] && [ "$$(build/uds version)" = "$(UDS_CLI_VERSION)" ] ; then exit 0; fi && \
	echo "Downloading uds-cli" && \
	curl -sL https://github.com/defenseunicorns/uds-cli/releases/download/$(UDS_CLI_VERSION)/uds-cli_$(UDS_CLI_VERSION)_$(UNAME_S)_$(ARCH) -o build/uds && \
	chmod +x build/uds

build/software-factory-namespaces: | build ## Build namespaces package
	cd build && ./zarf package create ../packages/namespaces/ --confirm --output-directory .

build/idam-gitlab: | build ## Build idam-gitlab package
	cd build && ./zarf package create ../packages/idam-gitlab/ --confirm --output-directory .

build/idam-sonarqube: | build ## Build idam-sonarqube package
	cd build && ./zarf package create ../packages/idam-sonarqube/ --confirm --output-directory .

build/idam-dns: | build ## Build idam-dns package
	cd build && ./zarf package create ../packages/idam-dns/ --confirm --output-directory .

build/idam-realm: | build ## Build idam-realm package
	cd build && ./zarf package create ../packages/idam-realm/ --confirm --output-directory .

build/uds-bundle-software-factory: | build ## Build the software factory
	cd build && ./uds bundle create ../ --confirm
	mv uds-bundle-software-factory-demo-*.tar.zst build/

########################################################################
# Deploy Section
########################################################################

deploy: ## Deploy the software factory package
	cd ./build && ./uds bundle deploy uds-bundle-software-factory-demo-*.tar.zst --confirm

########################################################################
# Macro Section
########################################################################

.PHONY: all
all: build/all cluster/reset deploy ## Build and deploy the software factory

.PHONY: rebuild
rebuild: clean build/all
