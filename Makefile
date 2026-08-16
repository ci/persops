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
# The secondary machine uses the "work" Darwin config; everything else is aglaea.
ifeq ($(HOSTNAME), work)
DARWIN_FLAKE := $(FLAKE)\#work
else
DARWIN_FLAKE := $(FLAKE)\#aglaea
endif
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

.PHONY: local switch deploy build check eval-machines fast-check test remote-guard r/rdp

remote-guard:
ifeq ($(HOSTNAME), work)
	@echo "remote targets disabled on host work"
	@exit 1
endif

local:
ifeq ($(UNAME), Darwin)
	$(NH) darwin switch "${DARWIN_FLAKE}"
else
	$(NH) os switch "${NIXOS_FLAKE}"
endif

switch:
ifeq ($(UNAME), Darwin)
	$(NH) darwin switch "${DARWIN_FLAKE}"
else
	$(NH) os switch "${NIXOS_FLAKE}"
endif

deploy:
	NIXADDR="$(NIXADDR)" NIXPORT="$(NIXPORT)" NIXUSER="$(NIXUSER)" ./scripts/deploy $(TARGETS)

build:
ifeq ($(UNAME), Darwin)
	$(NH) darwin build "${DARWIN_FLAKE}"
else
	$(NH) os build "${NIXOS_FLAKE}"
endif

check:
	nix flake check --print-build-logs "$(FLAKE)"
	$(MAKE) eval-machines

# Force each machine config through the module system without realizing it.
# `nix flake check` only builds checks.*; it does not eval these attrsets.
eval-machines:
	nix eval --raw '$(FLAKE)#nixosConfigurations.amalthea.config.system.build.toplevel.drvPath'
	nix eval --raw '$(FLAKE)#darwinConfigurations.aglaea.config.system.build.toplevel.drvPath'
	nix eval --raw '$(FLAKE)#darwinConfigurations.work.config.system.build.toplevel.drvPath'
	nix eval --raw '$(FLAKE)#deploy.nodes.amalthea.profiles.system.path.drvPath'

fast-check:
	$(NIX_FAST_BUILD) --flake "$(FLAKE)#checks" --no-link --skip-cached --systems "$(CHECK_SYSTEMS)"

test:
ifeq ($(UNAME), Darwin)
	$(NH) darwin build "${DARWIN_FLAKE}"
else
	$(NH) os test "${NIXOS_FLAKE}"
endif

r/rdp: remote-guard
	xfreerdp /u:$(NIXUSER) /p:$$(op items get wdl6vo3pd4vmnf2jz7ydhedspu --fields password) /v:$(NIXADDR) /size:1920x1080
