#!/bin/bash
# Build a Proxmox VE raw disk image using diskimage-builder.
# Run on the OpenStack VM via: make ironic-build-image
#
# Required environment variables:
#   DIB_ROOT_SSH_KEY  — SSH public key to inject into root (passed by Makefile)
#
# Output: /tmp/proxmox.raw
set -euo pipefail

ELEMENTS_PATH_DIR=/tmp/dib-elements-proxmox
VENV=/tmp/dib-venv-proxmox
OUTPUT=/tmp/proxmox
IMAGE_INFO=/tmp/proxmox.image-info

echo "==> Installing diskimage-builder..."
sudo apt-get install -y -q python3-venv python3-pip debootstrap qemu-utils kpartx parted
python3 -m venv "$VENV"
"$VENV"/bin/pip install -q 'diskimage-builder>=3.28'

echo "==> Making element scripts executable..."
find "$ELEMENTS_PATH_DIR" -type f \( -name "*.d" -prune -o -print \) | xargs -r chmod +x 2>/dev/null || true
find "$ELEMENTS_PATH_DIR" -path "*/install.d/*" -type f -exec chmod +x {} +
find "$ELEMENTS_PATH_DIR" -path "*/cleanup.d/*" -type f -exec chmod +x {} +
find "$ELEMENTS_PATH_DIR" -path "*/first-boot.d/*" -type f -exec chmod +x {} + 2>/dev/null || true

echo "==> Building Proxmox VE image..."
export ELEMENTS_PATH="$ELEMENTS_PATH_DIR"
export DIB_RELEASE=trixie             # Proxmox VE 9 is based on Debian 13
export DIB_IMAGE_SIZE=20             # 20 GB — enough for Proxmox base install
export DIB_ROOT_SSH_KEY="${DIB_ROOT_SSH_KEY:?DIB_ROOT_SSH_KEY must be set}"
export DIB_BOOT_MODE=uefi            # build GPT + EFI System Partition (required for UEFI bare-metal)

"$VENV"/bin/disk-image-create \
    -o "$OUTPUT" \
    -t raw \
    debian-minimal vm block-device-efi grub2 growroot cloud-init proxmox-minimal proxmox-network proxmox-ssh

echo "==> Partition table:"
sudo parted "${OUTPUT}.raw" unit MiB print

echo ""
echo "==> Image built successfully: ${OUTPUT}.raw"
echo "    Size: $(du -sh "${OUTPUT}.raw" | cut -f1)"

cat > "$IMAGE_INFO" <<EOF
IMAGE_NAME=proxmox
IMAGE_OS=proxmox
IMAGE_OS_VERSION=proxmox-ve-9-debian-13-trixie
IMAGE_DISTRO=debian
IMAGE_DISTRO_VERSION=13-trixie
IMAGE_BUILD_DATE=$(date -u +%Y%m%dT%H%M%SZ)
EOF

echo "==> Image metadata written to ${IMAGE_INFO}"
