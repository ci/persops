# Connectivity info for Linux remote
NIXADDR ?= amalthea
NIXPORT ?= 22
NIXUSER ?= cat

# The name of the nixosConfiguration in the flake
NIXNAME ?= amalthea

# Get the path to this Makefile and directory
MAKEFILE_DIR := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
FLAKE ?= $(MAKEFILE_DIR)
HOSTNAME := $(shell hostname -s 2>/dev/null || hostname)
# Each Mac switches to the Darwin config named after its hostname. A new Mac
# bootstraps once with darwin-rebuild (README), which sets the hostname.
DARWIN_HOSTS := aglaea ergane
# Work-profile hosts only ever switch themselves; no remote targets.
WORK_HOSTS := ergane
DARWIN_FLAKE := $(FLAKE)\#$(HOSTNAME)
NIXOS_FLAKE := $(FLAKE)\#$(NIXNAME)
ARCH := $(shell uname -m)

# We need to do some OS switching below.
UNAME := $(shell uname)
ifeq ($(UNAME),Darwin)
CURRENT_SYSTEM := $(if $(filter arm64 aarch64,$(ARCH)),aarch64-darwin,x86_64-darwin)
else
CURRENT_SYSTEM := $(if $(filter arm64 aarch64,$(ARCH)),aarch64-linux,x86_64-linux)
endif

CHECK_SYSTEMS ?= $(CURRENT_SYSTEM)
NH ?= nh
NIX_FAST_BUILD ?= nix develop --command nix-fast-build
TARGETS ?=
DEPLOY_CONTROLLER ?= $(HOSTNAME)
VALID_DEPLOY_TARGETS := aglaea amalthea ergane
UNKNOWN_DEPLOY_TARGETS = $(filter-out $(VALID_DEPLOY_TARGETS),$(TARGETS))
DEPLOY_EVAL_ATTRS = $(strip \
	$(if $(filter amalthea,$(TARGETS)),$(if $(filter amalthea,$(DEPLOY_CONTROLLER)),nixosConfigurations.amalthea.config.system.build.toplevel.drvPath,deploy.nodes.amalthea.profiles.system.path.drvPath)) \
	$(if $(filter aglaea,$(TARGETS)),darwinConfigurations.aglaea.config.system.build.toplevel.drvPath) \
	$(if $(filter ergane,$(TARGETS)),darwinConfigurations.ergane.config.system.build.toplevel.drvPath))

.PHONY: local switch deploy build check deploy-check eval-machines fast-check test darwin-host-guard remote-guard r/rdp

darwin-host-guard:
ifeq ($(UNAME),Darwin)
ifeq ($(filter $(HOSTNAME),$(DARWIN_HOSTS)),)
	@echo "error: no Darwin config for host '$(HOSTNAME)' (known: $(DARWIN_HOSTS))" >&2
	@exit 1
endif
endif

remote-guard:
ifneq ($(filter $(HOSTNAME),$(WORK_HOSTS)),)
	@echo "remote targets disabled on work host $(HOSTNAME)"
	@exit 1
endif

local: darwin-host-guard
ifeq ($(UNAME), Darwin)
	$(NH) darwin switch "${DARWIN_FLAKE}"
else
	$(NH) os switch "${NIXOS_FLAKE}"
endif

switch: darwin-host-guard
ifeq ($(UNAME), Darwin)
	$(NH) darwin switch "${DARWIN_FLAKE}"
else
	$(NH) os switch "${NIXOS_FLAKE}"
endif

deploy:
	NIXADDR="$(NIXADDR)" NIXPORT="$(NIXPORT)" NIXUSER="$(NIXUSER)" ./scripts/deploy $(TARGETS)

build: darwin-host-guard
ifeq ($(UNAME), Darwin)
	$(NH) darwin build "${DARWIN_FLAKE}"
else
	$(NH) os build "${NIXOS_FLAKE}"
endif

check:
	nix flake check --print-build-logs "$(FLAKE)"
	$(MAKE) eval-machines

deploy-check:
	@if [ -z "$(strip $(TARGETS))" ]; then echo "error: no deployment targets specified" >&2; exit 1; fi
	@if [ -n "$(UNKNOWN_DEPLOY_TARGETS)" ]; then echo "error: unknown deployment target: $(UNKNOWN_DEPLOY_TARGETS)" >&2; exit 1; fi
	@case "$(DEPLOY_CONTROLLER)" in aglaea|amalthea|ergane) ;; *) echo "error: unknown deployment controller: $(DEPLOY_CONTROLLER)" >&2; exit 1 ;; esac
	@if [ "$(DEPLOY_CONTROLLER)" = amalthea ] && [ -n "$(filter aglaea,$(TARGETS))" ]; then echo "error: aglaea cannot be checked for deployment from amalthea" >&2; exit 1; fi
	@if [ "$(DEPLOY_CONTROLLER)" = ergane ] && [ -n "$(filter-out ergane,$(TARGETS))" ]; then echo "error: ergane is isolated and can deploy only itself" >&2; exit 1; fi
	@if [ "$(DEPLOY_CONTROLLER)" != ergane ] && [ -n "$(filter ergane,$(TARGETS))" ]; then echo "error: ergane can be deployed only from ergane" >&2; exit 1; fi
	nix flake check --print-build-logs "$(FLAKE)"
	@set -e; $(foreach attr,$(DEPLOY_EVAL_ATTRS),nix eval --raw '$(FLAKE)#$(attr)';)

# Force each machine config through the module system without realizing it.
# `nix flake check` only builds checks.*; it does not eval these attrsets.
eval-machines:
	nix eval --raw '$(FLAKE)#nixosConfigurations.amalthea.config.system.build.toplevel.drvPath'
	nix eval --raw '$(FLAKE)#darwinConfigurations.aglaea.config.system.build.toplevel.drvPath'
	nix eval --raw '$(FLAKE)#darwinConfigurations.ergane.config.system.build.toplevel.drvPath'
	nix eval --raw '$(FLAKE)#deploy.nodes.amalthea.profiles.system.path.drvPath'

fast-check:
	$(NIX_FAST_BUILD) --flake "$(FLAKE)#checks" --no-link --skip-cached --systems "$(CHECK_SYSTEMS)"

test: darwin-host-guard
ifeq ($(UNAME), Darwin)
	$(NH) darwin build "${DARWIN_FLAKE}"
else
	$(NH) os test "${NIXOS_FLAKE}"
endif

r/rdp: remote-guard
	xfreerdp /u:$(NIXUSER) /p:$$(op items get wdl6vo3pd4vmnf2jz7ydhedspu --fields password) /v:$(NIXADDR) /size:1920x1080
