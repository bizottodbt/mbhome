#!/bin/bash
# Build a minimal Debian 13 (trixie) raw disk image using diskimage-builder.
# Used to validate the DIB pipeline and Ironic deploy workflow before adding
# Proxmox-specific packages.
# Run on the OpenStack VM via: make ironic-build-image OS=debian
#
# Required environment variables:
#   DIB_ROOT_SSH_KEY  — SSH public key to inject into root (passed by Makefile)
#
# Output: /tmp/debian.raw
set -euo pipefail

ELEMENTS_PATH_DIR=/tmp/dib-elements-debian
VENV=/tmp/dib-venv-debian
OUTPUT=/tmp/debian

echo "==> Installing diskimage-builder..."
sudo apt-get install -y -q python3-venv python3-pip debootstrap qemu-utils kpartx
python3 -m venv "$VENV"
"$VENV"/bin/pip install -q 'diskimage-builder>=3.28'

echo "==> Making element scripts executable..."
find "$ELEMENTS_PATH_DIR" -path "*/install.d/*" -type f -exec chmod +x {} +
find "$ELEMENTS_PATH_DIR" -path "*/cleanup.d/*" -type f -exec chmod +x {} + 2>/dev/null || true
find "$ELEMENTS_PATH_DIR" -path "*/first-boot.d/*" -type f -exec chmod +x {} + 2>/dev/null || true

echo "==> Building Debian image..."
export ELEMENTS_PATH="$ELEMENTS_PATH_DIR"
export DIB_RELEASE=trixie
export DIB_IMAGE_SIZE=5
export DIB_ROOT_SSH_KEY="${DIB_ROOT_SSH_KEY:?DIB_ROOT_SSH_KEY must be set}"
export DIB_BOOT_MODE=uefi

"$VENV"/bin/disk-image-create \
    -o "$OUTPUT" \
    -t raw \
    debian-minimal vm block-device-efi grub2 proxmox-network proxmox-ssh

echo "==> Partition table:"
sudo parted "${OUTPUT}.raw" unit MiB print

echo ""
echo "==> Image built successfully: ${OUTPUT}.raw"
echo "    Size: $(du -sh "${OUTPUT}.raw" | cut -f1)"
