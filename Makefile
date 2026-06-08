# Connectivity info for Linux remote
NIXADDR ?= amalthea
NIXPORT ?= 22
NIXUSER ?= cat

# The name of the nixosConfiguration in the flake
NIXNAME ?= amalthea

# Get the path to this Makefile and directory
MAKEFILE_DIR := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
FLAKE_DIR := git+file:$(MAKEFILE_DIR)
DARWIN_FLAKE := $(FLAKE_DIR)\#aglaea
NIXOS_FLAKE := $(FLAKE_DIR)\#$(NIXNAME)
REMOTE_FLAKE := /nix-config\#$(NIXNAME)
HOSTNAME := $(shell hostname -s 2>/dev/null || hostname)
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

.PHONY: local switch build check fast-check test remote-guard r/copy r/preflight r/test r/switch r/verify r/apply r/rdp

remote-guard:
ifeq ($(HOSTNAME), ph)
	@echo "remote targets disabled on host ph"
	@exit 1
endif

local:
ifeq ($(UNAME), Darwin)
ifeq ($(HOSTNAME), ph)
	$(NH) darwin switch "$(FLAKE_DIR)#work"
else
	$(NH) darwin switch "${DARWIN_FLAKE}"
endif
else
	$(NH) os switch "${NIXOS_FLAKE}"
endif

switch:
ifeq ($(UNAME), Darwin)
	$(NH) darwin switch "${DARWIN_FLAKE}"
else
	$(NH) os switch "${NIXOS_FLAKE}"
endif

build:
ifeq ($(UNAME), Darwin)
	$(NH) darwin build "${DARWIN_FLAKE}"
else
	$(NH) os build "${NIXOS_FLAKE}"
endif

check:
	nix flake check --all-systems --print-build-logs
	$(MAKE) fast-check

fast-check:
	$(NIX_FAST_BUILD) --flake ".#checks" --no-link --skip-cached --systems "$(CHECK_SYSTEMS)"

test:
ifeq ($(UNAME), Darwin)
	$(NH) darwin build "${DARWIN_FLAKE}"
else
	$(NH) os test "${NIXOS_FLAKE}"
endif

# copy the Nix configurations into the remote.
r/copy: remote-guard
	rsync -av -e 'ssh -p$(NIXPORT)' \
		--exclude='.git/' \
		--exclude='.jj/' \
		--rsync-path="sudo rsync" \
		$(MAKEFILE_DIR)/ $(NIXUSER)@$(NIXADDR):/nix-config

# preflight remote SSH and Tailscale before copying or switching.
r/preflight: remote-guard
	./scripts/remote-preflight "$(NIXUSER)" "$(NIXADDR)" "$(NIXPORT)"

# run a remote nixos-rebuild test against the copied configuration.
r/test: remote-guard
	ssh -p$(NIXPORT) $(NIXUSER)@$(NIXADDR) " \
		sudo nixos-rebuild test --flake \"$(REMOTE_FLAKE)\" \
	"

# run the nixos-rebuild switch command. This does NOT copy files so you
# have to run r/copy first.
r/switch: remote-guard
	ssh -p$(NIXPORT) $(NIXUSER)@$(NIXADDR) " \
		sudo nixos-rebuild switch --flake \"$(REMOTE_FLAKE)\" \
	"

# verify important remote service state after a switch.
r/verify: remote-guard
	./scripts/remote-verify "$(NIXUSER)" "$(NIXADDR)" "$(NIXPORT)"

# full remote deploy: preflight, local flake check, copy, test, switch, verify.
r/apply: remote-guard
	$(MAKE) r/preflight
	$(MAKE) check
	$(MAKE) r/copy
	$(MAKE) r/test
	$(MAKE) r/switch
	$(MAKE) r/verify

r/rdp: remote-guard
	xfreerdp /u:$(NIXUSER) /p:$$(op items get wdl6vo3pd4vmnf2jz7ydhedspu --fields password) /v:$(NIXADDR) /size:1920x1080
