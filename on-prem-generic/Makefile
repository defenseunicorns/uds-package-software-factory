# The version of Zarf to use. To keep this repo as portable as possible the Zarf binary will be downloaded and added to
# the build folder.
ZARF_VERSION := v0.28.0

SWF_VERSION := 0.0.1

DUBBD_KIND_VERSION := 2.2.0

DUBBD_K3D_VERSION := 0.3.0

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

.DEFAULT_GOAL := help

# Idiomatic way to force a target to always run, by having it depend on this dummy target
FORCE:

.PHONY: help
help: ## Show a list of all targets
	@grep -E '^\S*:.*##.*$$' $(MAKEFILE_LIST) \
	| sed -n 's/^\(.*\): \(.*\)##\(.*\)/\1:\3/p' \
	| column -t -s ":"

########################################################################
# Build Section
########################################################################

.PHONY: clean
clean: ## Clean up build files
	@rm -rf ./build zarf-sbom

build/:
	mkdir -p build

build/zarf: | build/ ## Download the Linux flavor of Zarf to the build dir
	echo "Downloading zarf"
	curl -sL https://github.com/defenseunicorns/zarf/releases/download/$(ZARF_VERSION)/zarf_$(ZARF_VERSION)_Linux_amd64 -o build/zarf
	chmod +x build/zarf

build/zarf-init.sha256: | build/ ## Download the init package
	echo "Downloading zarf-init-amd64-$(ZARF_VERSION).tar.zst"
	curl -sL https://github.com/defenseunicorns/zarf/releases/download/$(ZARF_VERSION)/zarf-init-amd64-$(ZARF_VERSION).tar.zst -o build/zarf-init-amd64-$(ZARF_VERSION).tar.zst
	echo "Creating shasum of the init package"
	shasum -a 256 build/zarf-init-amd64-$(ZARF_VERSION).tar.zst | awk '{print $$1}' > build/zarf-init.sha256

build/values-package: | build/
	build/zarf package create values-package/ --skip-sbom --confirm --output-directory build

build/software-factory: | build/ build/values-package
	build/zarf package create . --skip-sbom --confirm --output-directory build

build/dubbd-pull-k3d.sha256: | build/
	./build/zarf package pull oci://ghcr.io/defenseunicorns/packages/dubbd-k3d:$(DUBBD_K3D_VERSION)-amd64 --oci-concurrency 9 --output-directory build
	echo "Creating shasum of the dubbd-k3d package"
	shasum -a 256 build/zarf-package-dubbd-k3d-amd64-$(DUBBD_K3D_VERSION).tar.zst | awk '{print $$1}' > build/dubbd-pull-k3d.sha256

build/dubbd-pull-kind.sha256: | build/
	./build/zarf package pull oci://ghcr.io/corang/big-bang-distro-kind:$(DUBBD_KIND_VERSION)-amd64 --oci-concurrency 9 --output-directory build
	echo "Creating shasum of the dubbd-kind package"
	shasum -a 256 build/zarf-package-big-bang-distro-kind-amd64-$(DUBBD_KIND_VERSION).tar.zst | awk '{print $$1}' > build/dubbd-pull-kind.sha256

########################################################################
# Deploy Section
########################################################################

deploy/init: ## Deploy the zarf init package
	./build/zarf init --confirm --components=git-server

deploy/dubbd-k3d: ## Deploy the k3d flavor of DUBBD
	cd ./build && ./zarf package deploy zarf-package-dubbd-k3d-amd64-$(DUBBD_K3D_VERSION).tar.zst --confirm

deploy/dubbd-kind: ## Deploy the kind flavor of DUBBD
	cd ./build && ./zarf package deploy zarf-package-big-bang-distro-kind-amd64-$(DUBBD_KIND_VERSION).tar.zst --confirm

deploy/software-factory: ## Deploy the software factory package
	build/zarf package deploy build/zarf-package-wip-on-prem-generic-swf-amd64-$(SWF_VERSION).tar.zst --confirm

########################################################################
# Cluster Section
########################################################################

cluster/full: | cluster/destroy cluster/create build/zarf-init.sha256 deploy/init build/dubbd-pull-k3d.sha256 deploy/dubbd-k3d

cluster/create:
	k3d cluster create swf --api-port 6443 --no-lb --k3s-arg '--disable=servicelb' --k3s-arg '--disable=traefik@server:0' -v /etc/machine-id:/etc/machine-id@server:*
	k3d kubeconfig merge swf -o /home/${USER}/cluster-kubeconfig.yaml
	../utils/metallb/install.sh
	echo "Cluster is ready!"

cluster/destroy:
	k3d cluster delete swf

cluster/kind/full: | cluster/kind/destroy cluster/kind/create deploy/init deploy/dubbd-kind

cluster/kind/create:
	kind create cluster --name swf --config utils/kind-config/noCNI.yaml
	echo
	echo "Waiting for cluster to be ready..."
	kubectl wait --for=condition=Ready pods --all --all-namespaces 2>&1 >/dev/null
	echo
	echo "Installing Calico..."
	kubectl apply --wait=true -f https://raw.githubusercontent.com/projectcalico/calico/v3.25.1/manifests/calico.yaml 2>&1 >/dev/null
	echo "Waiting for Calico to be ready..."
	kubectl rollout status deployment/calico-kube-controllers -n kube-system --watch --timeout=90s 2>&1 >/dev/null
	kubectl rollout status daemonset/calico-node -n kube-system --watch --timeout=90s 2>&1 >/dev/null
	kubectl wait --for=condition=Ready pods --all --all-namespaces 2>&1 >/dev/null
	echo
	utils/metallb/install.sh
	kubectl wait --for=condition=Ready pods --all --all-namespaces 2>&1 >/dev/null
	echo
	echo "Cluster is ready!"

cluster/kind/destroy:
	kind delete cluster --name swf
