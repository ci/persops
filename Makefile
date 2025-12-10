# Connectivity info for Linux remote
NIXADDR ?= amalthea
NIXPORT ?= 22
NIXUSER ?= cat

# Get the path to this Makefile and directory
MAKEFILE_DIR := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))

# The name of the nixosConfiguration in the flake
NIXNAME ?= amalthea

# We need to do some OS switching below.
UNAME := $(shell uname)

switch:
ifeq ($(UNAME), Darwin)
	sudo darwin-rebuild switch --flake "${MAKEFILE_DIR}"
else
	sudo nixos-rebuild switch --flake "${MAKEFILE_DIR}#${NIXNAME}"
endif

test:
ifeq ($(UNAME), Darwin)
	nix build "${MAKEFILE_DIR}"
	sudo darwin-rebuild test --flake "${MAKEFILE_DIR}"
else
	sudo nixos-rebuild test --flake "${MAKEFILE_DIR}#$(NIXNAME)"
endif

# copy the Nix configurations into the remote.
r/copy:
	rsync -av -e 'ssh -p$(NIXPORT)' \
		--exclude='.git/' \
		--exclude='.jj/' \
		--rsync-path="sudo rsync" \
		$(MAKEFILE_DIR)/ $(NIXUSER)@$(NIXADDR):/nix-config

# run the nixos-rebuild switch command. This does NOT copy files so you
# have to run vm/copy before.
r/switch:
	ssh -p$(NIXPORT) $(NIXUSER)@$(NIXADDR) " \
		sudo nixos-rebuild switch --flake \"/nix-config#${NIXNAME}\" \
	"
