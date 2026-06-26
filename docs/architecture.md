# Homelab Infrastructure Architecture

## Overview

This repo manages a homelab platform built around:

- Unraid as the storage and VM host
- A single OpenStack VM as the bare-metal provisioning controller
- Ironic for provisioning Proxmox VE onto physical nodes
- Proxmox VE as the virtualization layer for later k3s workloads
- Ansible, DIB, Terraform/OpenTofu, and Flux for automation as the stack grows

The active bare-metal path is OpenStack Ironic, not Tinkerbell. Older Tinkerbell
manifests have been removed from the active tree.

## Physical Layout

### Unraid Server

| Property | Value |
|---|---|
| Role | Primary storage and VM host |
| IP | `192.0.2.48` |
| Network | Flat `192.0.2.0/24` |

Expected NFS shares:

| Share | Path | Purpose |
|---|---|---|
| `proxmox-vm` | `/mnt/user/proxmox-vm` | Proxmox VM disks |
| `proxmox-backup` | `/mnt/user/proxmox-backup` | Proxmox backups |
| `proxmox-snippets` | `/mnt/user/proxmox-snippets` | cloud-init snippets for Terraform/OpenTofu |

### OpenStack VM

| Property | Value |
|---|---|
| Role | Bare-metal provisioning controller |
| Host | Unraid |
| IP | `192.0.2.10` |
| OS | Debian 13 |
| Provisioning | `make openstack-vm` |
| OpenStack deployment | Kolla-Ansible |
| Enabled services | Keystone, Glance, Neutron, Ironic, Horizon |

The OpenStack VM hosts:

- Ironic API/conductor
- Ironic dnsmasq/httpboot for PXE/iPXE
- Glance images for deploy ramdisks and OS images
- Neutron flat provisioning network metadata
- Horizon for debugging

### Proxmox Nodes

| Component | Detail |
|---|---|
| Platform | Gigabyte MJ11-EC1 / G431-MM0-OT class nodes |
| CPU | AMD EPYC 3151 |
| Memory | 128 GiB per current node |
| BMC | Aspeed AST2500 with IPMI and Redfish |
| OS target | Local SSD/NVMe, currently modelled as `/dev/sda` in Ironic |
| Required kernel parameter | `pcie_aspm=off` |

The currently validated Proxmox image boots, accepts the injected SSH key, serves
the Proxmox web UI on `https://<node-ip>:8006`, and includes `pcie_aspm=off` in
the running kernel command line.

## Network

Detailed current and future network planning lives in
[`docs/network-plan.md`](network-plan.md).

| Item | Value |
|---|---|
| Subnet | `192.0.2.0/24` |
| Gateway/DNS | `192.0.2.1` |
| OpenStack VM | `192.0.2.10` |
| DHCP/PXE range | `192.0.2.100-192.0.2.200` |
| Provisioning network | `provisioning-net` |
| Provider physical network | `physnet1` |
| VLANs | Flat management LAN now; UniFi VLAN-only storage network `90` on SFP+ |
| Storage network | `198.51.100.0/24`, no gateway |

Ironic dnsmasq handles PXE DHCP. The Neutron provisioning subnet exists with DHCP
disabled so Ironic can own PXE behavior directly.

## Bare-Metal Provisioning Flow

1. `make kolla-ipa-images` builds the Ironic Python Agent kernel/initramfs on the
   OpenStack VM from the OpenStack release branch configured in the Makefile,
   then stores them as release-versioned artifacts such as
   `ironic-agent-2026.1.kernel`.
2. `make openstack-setup` uploads or refreshes those IPA artifacts in Glance and
   creates the provisioning network. Glance image names include the same
   release, for example `ironic-deploy-kernel-2026.1`.
3. Nodes are registered from `infrastructure/ironic/nodes/proxmox-nodes.yaml`.
4. `make ironic-set-deploy-images NODE=<node>` writes the current Glance
   deploy kernel/ramdisk IDs into the node driver-info.
5. `make ironic-build-image OS=proxmox` builds the Proxmox raw disk image with
   diskimage-builder on the OpenStack VM and uploads it to Glance.
6. `openstack baremetal node deploy <node>` PXE-boots IPA, writes the raw image
   to the node disk, and reboots into local Proxmox.

## Ironic Drivers

`ipmi` is the stable baseline for deployment. It supports the critical path:
power, boot, deploy, management, network, and storage.

For IPMI nodes, validation can still show these optional interfaces as false:

- `bios`
- `console`
- `firmware`
- `inspect`
- `raid`
- `rescue`

That is expected and does not block provisioning.

`redfish` is also enabled. The Gigabyte/AST2500 BMC exposes:

```text
/redfish/v1/Systems/Self
```

Redfish can improve support for BIOS, inspection, management, power, and RAID
interfaces depending on BMC firmware behavior. It should be tested first on
spare nodes before changing a known-good IPMI node.

## Proxmox Image Build

The active image path is:

```text
infrastructure/dib/proxmox/
  build.sh
  elements/
    proxmox-minimal/
    proxmox-network/
    proxmox-ssh/
```

Important image behavior:

- Debian 13/Trixie base
- Proxmox VE 9 packages from the no-subscription repository
- PVE kernel installed via `proxmox-default-kernel`
- UEFI/GPT boot image via DIB `block-device-efi` and `grub2`
- DHCP bootstrap networking via `systemd-networkd`
- Ironic ConfigDrive cloud-init datasource enabled
- Root SSH key injected from `SSH_KEY_FILE`
- First boot `/etc/hosts` generated from the DHCP address before Proxmox services start
- GRUB kernel parameter `pcie_aspm=off`

## Repository Map

```text
mbhome/
  Makefile
  README.md
  docs/
    architecture.md
  infrastructure/
    ansible/
      inventory/
      playbooks/
      roles/
    dib/
      debian/
      proxmox/
    ironic/
      images/
      nodes/
    kolla-ansible/
      config/
      globals.yml
      build-ipa.sh
    packer/
    terraform/
      proxmox/
  kubernetes/
    app-cluster/
```

## Current Status

- OpenStack VM deployment path exists through Ansible and Kolla-Ansible.
- IPA kernel/initramfs build path exists and is aligned to OpenStack `2026.1`.
- `openstack-setup` refreshes stale IPA Glance images when local checksums change.
- Proxmox DIB image deploys through Ironic and boots successfully.
- Proxmox SSH key access, web UI, and `pcie_aspm=off` have been validated.
- Redfish has been discovered on the first node and should be trialed on spare nodes.

## Later Phases

- Register and deploy the remaining Proxmox nodes.
- Run the Proxmox baseline Ansible playbook for NFS storage and cluster setup.
- Use Terraform/OpenTofu against Proxmox to create k3s VMs.
- Bootstrap the app cluster under `kubernetes/app-cluster/`.
- Add Flux, External Secrets, and OpenBao once the app cluster exists.
