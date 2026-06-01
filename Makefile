# Connectivity info for Linux remote
NIXADDR ?= amalthea
NIXPORT ?= 22
NIXUSER ?= cat

# Get the path to this Makefile and directory
MAKEFILE_DIR := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
FLAKE_DIR := git+file:$(MAKEFILE_DIR)
DARWIN_FLAKE := $(FLAKE_DIR)#aglaea
NIXOS_FLAKE := $(FLAKE_DIR)#$(NIXNAME)
HOSTNAME := $(shell hostname -s 2>/dev/null || hostname)

# The name of the nixosConfiguration in the flake
NIXNAME ?= amalthea

# We need to do some OS switching below.
UNAME := $(shell uname)

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

test:
ifeq ($(UNAME), Darwin)
	darwin-rebuild build --flake "${DARWIN_FLAKE}"
	sudo darwin-rebuild test --flake "${DARWIN_FLAKE}"
else
	nixos-rebuild build --flake "${NIXOS_FLAKE}"
	sudo nixos-rebuild test --flake "${NIXOS_FLAKE}"
endif

# copy the Nix configurations into the remote.
r/copy:
ifeq ($(HOSTNAME), ph)
	@echo "r/copy disabled on host ph"
	@exit 1
endif
	rsync -av -e 'ssh -p$(NIXPORT)' \
		--exclude='.git/' \
		--exclude='.jj/' \
		--rsync-path="sudo rsync" \
		$(MAKEFILE_DIR)/ $(NIXUSER)@$(NIXADDR):/nix-config

# run the nixos-rebuild switch command. This does NOT copy files so you
# have to run vm/copy before.
r/switch:
ifeq ($(HOSTNAME), ph)
	@echo "r/switch disabled on host ph"
	@exit 1
endif
	ssh -p$(NIXPORT) $(NIXUSER)@$(NIXADDR) " \
		sudo nixos-rebuild switch --flake \"/nix-config#${NIXNAME}\" \
	"

r/rdp:
	xfreerdp /u:$(NIXUSER) /p:$(shell op items get wdl6vo3pd4vmnf2jz7ydhedspu --fields password) /v:$(NIXADDR) /size:1920x1080
