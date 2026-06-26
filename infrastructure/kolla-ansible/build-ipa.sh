#!/bin/bash
# Build Ironic Python Agent kernel + initramfs on the OpenStack VM.
# Builds from the stable/2026.1 git branch — the same source Kolla-Ansible 2026.1
# uses for the ironic_conductor container — so the ramdisk and conductor are aligned.
set -euo pipefail

OUTPUT_DIR="${1:-/tmp/ipa-build}"
OPENSTACK_RELEASE="${2:-2026.1}"
VENV="/tmp/ipa-builder-venv"
IPA_BRANCH="stable/${OPENSTACK_RELEASE}"
VERSIONED_KERNEL="ironic-agent-${OPENSTACK_RELEASE}.kernel"
VERSIONED_INITRAMFS="ironic-agent-${OPENSTACK_RELEASE}.initramfs"
# Upper-constraints from the same OpenStack release ensure compatible tool versions.
CONSTRAINTS="https://releases.openstack.org/constraints/upper/${OPENSTACK_RELEASE}"

echo "==> Detecting IPA version from ironic_conductor container (informational)..."
# /var/lib/openstack/bin/pip is the Kolla venv pip; || true prevents set -e from aborting.
IPA_VERSION=$(sudo docker exec ironic_conductor \
    /var/lib/openstack/bin/pip show ironic-python-agent 2>/dev/null \
    | grep ^Version | awk '{print $2}' || true)
if [[ -n "${IPA_VERSION}" ]]; then
    echo "    ironic_conductor has ironic-python-agent ${IPA_VERSION}"
fi
echo "    Building IPA ramdisk from git branch: ${IPA_BRANCH}"

echo "==> Installing build dependencies..."
sudo apt-get install -y -q \
    python3-venv python3-pip \
    debootstrap qemu-utils kpartx \
    gdisk parted git

echo "==> Setting up ironic-python-agent-builder venv (OpenStack ${OPENSTACK_RELEASE} constraints)..."
python3 -m venv "${VENV}"
"${VENV}/bin/pip" install -q --upgrade pip
# Install build tools constrained to the same OpenStack release.
# ironic-python-agent itself is installed inside the ramdisk from git (see DIB_REPOREF below).
"${VENV}/bin/pip" install -q \
    -c "${CONSTRAINTS}" \
    "diskimage-builder" \
    "ironic-python-agent-builder"

echo "==> Building IPA images from ${IPA_BRANCH}..."
mkdir -p "${OUTPUT_DIR}"

sudo env PATH="${VENV}/bin:${PATH}" \
    DIB_REPOLOCATION_ironic_python_agent="https://opendev.org/openstack/ironic-python-agent" \
    DIB_REPOREF_ironic_python_agent="${IPA_BRANCH}" \
    "${VENV}/bin/ironic-python-agent-builder" \
    --release trixie \
    --output "${OUTPUT_DIR}/ironic-agent" \
    debian

cp "${OUTPUT_DIR}/ironic-agent.kernel"    "${OUTPUT_DIR}/${VERSIONED_KERNEL}"
cp "${OUTPUT_DIR}/ironic-agent.initramfs" "${OUTPUT_DIR}/${VERSIONED_INITRAMFS}"

echo "==> Build complete:"
ls -lh "${OUTPUT_DIR}/ironic-agent"*

echo "==> Copying to Ironic httpboot volume..."
sudo cp "${OUTPUT_DIR}/${VERSIONED_KERNEL}"    "/var/lib/docker/volumes/ironic/_data/httpboot/${VERSIONED_KERNEL}"
sudo cp "${OUTPUT_DIR}/${VERSIONED_INITRAMFS}" "/var/lib/docker/volumes/ironic/_data/httpboot/${VERSIONED_INITRAMFS}"
# Keep the stable names used by ipa.ipxe as compatibility copies.
sudo cp "${OUTPUT_DIR}/${VERSIONED_KERNEL}"    /var/lib/docker/volumes/ironic/_data/httpboot/ironic-agent.kernel
sudo cp "${OUTPUT_DIR}/${VERSIONED_INITRAMFS}" /var/lib/docker/volumes/ironic/_data/httpboot/ironic-agent.initramfs

echo "==> Done. Re-upload to Glance with: make openstack-setup"
