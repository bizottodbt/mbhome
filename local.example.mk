# Copy to local.mk and fill in values for your own network.
# local.mk is git-ignored and automatically included by Makefile.

HOMELAB_GATEWAY := 192.0.2.1
HOMELAB_DNS := 192.0.2.1

PROXMOX_GATEWAY := $(HOMELAB_GATEWAY)
PROXMOX_DNS := $(HOMELAB_DNS)
