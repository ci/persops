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

# We need to do some OS switching below.
UNAME := $(shell uname)

.PHONY: local switch check test remote-guard r/copy r/preflight r/test r/switch r/verify r/apply r/rdp

remote-guard:
ifeq ($(HOSTNAME), ph)
	@echo "remote targets disabled on host ph"
	@exit 1
endif

local:
ifeq ($(UNAME), Darwin)
ifeq ($(HOSTNAME), ph)
	sudo darwin-rebuild switch --flake ~/p/persops#work
else
	sudo darwin-rebuild switch --flake "${DARWIN_FLAKE}"
endif
else
	sudo nixos-rebuild switch --flake "${NIXOS_FLAKE}"
endif

switch:
ifeq ($(UNAME), Darwin)
	sudo darwin-rebuild switch --flake "${DARWIN_FLAKE}"
else
	sudo nixos-rebuild switch --flake "${NIXOS_FLAKE}"
endif

check:
	nix flake check

test:
ifeq ($(UNAME), Darwin)
	darwin-rebuild build --flake "${DARWIN_FLAKE}"
	sudo darwin-rebuild test --flake "${DARWIN_FLAKE}"
else
	nixos-rebuild build --flake "${NIXOS_FLAKE}"
	sudo nixos-rebuild test --flake "${NIXOS_FLAKE}"
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
