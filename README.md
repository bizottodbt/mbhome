# mbhome
Repo for cluster and infrastructure deployment.

---

## Repository Data Policy

Commit declarative topology when it contains only private IPs, CIDRs, DNS
records, MAC addresses, hostnames, StorageClasses, or other non-secret desired
state. Keep credentials, API tokens, generated secrets, Terraform/Packer local
vars, BMC access, user passwords, and state files in git-ignored local files.

---

## Deploy OpenStack VM

Provisions a Debian 13 VM on Unraid (4 vCPU / 16 GB / 100 GB OS disk + 200 GB persistent data disk, IP `192.0.2.10`) that hosts OpenStack services via Kolla-Ansible. This VM is the bare-metal provisioning controller — Ironic PXE-boots the Proxmox nodes through it.

The playbook is **idempotent**:
- Running → exits immediately
- Shut off → starts the VM without reprovisioning
- Not found → full provision

### Requirements

| Requirement | Notes |
|---|---|
| Ansible ≥ 2.15 on the controller | `brew install ansible` |
| Unraid with VM Manager enabled | Settings → VM Manager → Enable VMs |
| `/mnt/user/isos/` exists on Unraid | Default Unraid ISOs share; base image downloaded here |
| `/mnt/user/domains/` exists on Unraid | Default Unraid domains share; VM disk created here |
| `qemu-img` on Unraid | Pre-installed on Unraid 6/7 |
| SSH key access to Unraid | `ssh root@<unraid-host>` must succeed without a password prompt |
| `~/.ssh/id_ed25519.pub` on the controller | Injected into the VM as the authorised key |

### Run

The playbook targets the `unraid` group defined in [`infrastructure/ansible/inventory/hosts.yaml`](infrastructure/ansible/inventory/hosts.yaml).
Real host IPs and SSH aliases live in the git-ignored local overlay. Start from
[`infrastructure/ansible/inventory/hosts.local.example.yaml`](infrastructure/ansible/inventory/hosts.local.example.yaml)
and copy it to `infrastructure/ansible/inventory/hosts.local.yaml`.

```bash
make openstack-vm
```

The playbook will:
1. Download the Debian 13 genericcloud image to `/mnt/user/isos/` on Unraid (≈ 326 MB, skipped on repeat runs)
2. Create a standalone 100 GB qcow2 disk at `/mnt/user/domains/openstack/vdisk1.qcow2`
3. Create a persistent 200 GB qcow2 data disk at `/mnt/user/domains/openstack/vdisk-openstack-data.qcow2` if missing
4. Build a cloud-init seed ISO (static IP `192.0.2.10`, SSH key, base packages)
5. Define and start the VM via libvirt
6. Wait for SSH on port 22 to confirm cloud-init is complete (≈ 3–5 min)

The persistent data disk is formatted once and mounted at `/var/lib/openstack-data`. Cloud-init bind-mounts:

- `/var/lib/openstack-data/docker-volumes` → `/var/lib/docker/volumes`
- `/var/lib/openstack-data/glance` → `/var/lib/glance/images`

This preserves Kolla Docker volumes, MariaDB metadata, Glance image files, Ironic httpboot content, and the Ironic conductor image cache across an OpenStack VM OS-disk rebuild, as long as the data disk is kept.

---

## Deploy OpenStack (Kolla-Ansible)

After the VM is up, deploy OpenStack from the Mac. The public example is
[`infrastructure/kolla-ansible/globals.example.yml`](infrastructure/kolla-ansible/globals.example.yml);
copy it to git-ignored `infrastructure/kolla-ansible/globals.yml` and set local
addresses/interface names there. Enabled services: Keystone, Glance, Neutron,
Ironic, Horizon.

### Additional requirements

| Requirement | Notes |
|---|---|
| Kolla-Ansible on the controller | handled automatically by `make kolla-genpwd` |
| `passwords.yml` populated | `make kolla-genpwd` (creates venv then generates passwords) |
| `network_interface` correct in local `globals.yml` | Verify with `ssh openstack ip link show` after first boot |
| Ironic Python Agent images | `make kolla-ipa-images` — built after `kolla-deploy` (git-ignored) |

### Run

```bash
# One-time: create venv + generate passwords (git-ignored)
make kolla-genpwd

# Verify network interface name on the VM, update local globals.yml if needed
ssh openstack ip link show

make kolla-bootstrap   # installs Docker + Kolla deps on the VM
make kolla-prechecks   # validates globals.yml and connectivity
make kolla-deploy      # deploys OpenStack containers
make kolla-post-deploy # generates admin-openrc.sh (git-ignored)

# Build IPA deploy images on the VM from the stable/2026.1 git branch
# (same source as the ironic_conductor container — requires kolla-deploy to have run first).
# Only needed after a fresh kolla-deploy or an OpenStack release upgrade.
# If rebuilt, run `make openstack-setup` afterwards to refresh Glance.
make kolla-ipa-images
```

`make kolla-ipa-images` stores the build output with the OpenStack release in the filename, for example `ironic-agent-2026.1.kernel` and `ironic-agent-2026.1.initramfs`. `make openstack-setup` uploads those artifacts to Glance as `ironic-deploy-kernel-2026.1` and `ironic-deploy-initramfs-2026.1`.

This lab uses Kolla's published `quay.io/openstack.kolla` images. Kolla-Ansible classifies that namespace as test images, so the `make kolla-prechecks` target passes `--use-test-images` intentionally.

### Upgrading OpenStack releases

When upgrading to a new OpenStack release (e.g. `2026.1` → `2026.2`):

1. Update `openstack_release` in the [`Makefile`](Makefile) — this is the single source of truth used by Kolla and the IPA build script.
2. Re-deploy OpenStack: `make kolla-deploy`
3. Rebuild IPA images — the ramdisk and `ironic_conductor` container must be from the same release branch:
   ```bash
   make kolla-ipa-images
   make openstack-setup   # refreshes stale kernel + initramfs in Glance
   ```
4. Update the deploy images on each node:
   ```bash
   make ironic-set-deploy-images NODE=mbhome-proxmox-01
   ```

Patch updates within the same release (e.g. a Kolla security fix that stays on `2026.1`) do **not** require rebuilding IPA images.

### Verify

```bash
# Source admin credentials (generated by kolla-post-deploy, stored locally)
source infrastructure/kolla-ansible/admin-openrc.sh

# The openstack CLI is in the kolla venv — activate it first
source infrastructure/kolla-ansible/.venv/bin/activate

# All services should be UP
openstack service list

# Networks created by Neutron
openstack network list

# Ironic drivers — requires system scope (use the system openrc overlay)
source infrastructure/kolla-ansible/admin-openrc-system.sh
# ipmi and redfish should be listed
openstack baremetal driver list

# Horizon dashboard — admin / generated password from passwords.yml keystone_admin_password
open http://192.0.2.10

# Check all containers are healthy on the VM
ssh openstack 'sudo docker ps --format "table {{.Names}}\t{{.Status}}"'
```

### Maintenance stop/start

For storage maintenance, VM shutdown preparation, or any operation that needs Kolla state to be quiet, stop the OpenStack stack without destroying containers or volumes:

```bash
make openstack-stack-stop
```

This stops Kolla's `kolla-*-container.service` systemd units first, then stops Docker/containerd. The Kolla units use `Restart=always`, so stopping only the Docker containers is not enough; systemd will start them again. This maintenance target does not delete containers, Docker volumes, Glance images, or the persistent data disk.

After maintenance:

```bash
make openstack-stack-start
make openstack-stack-status
```

`openstack-stack-start` starts Docker again and then starts the Kolla systemd units.

`openstack-stack-status` verifies the persistent data mounts and prints container health:

- `/var/lib/openstack-data`
- `/var/lib/docker/volumes`
- `/var/lib/glance/images`

Use `kolla-destroy` only when intentionally removing the OpenStack deployment. Do not use it for routine maintenance.

---

## Provision Bare Metal (Ironic) — Phase 1

Node definitions are based on
[`infrastructure/ironic/nodes/proxmox-nodes.example.yaml`](infrastructure/ironic/nodes/proxmox-nodes.example.yaml).
Copy it to git-ignored `infrastructure/ironic/nodes/proxmox-nodes.yaml`, then
fill in BMC credentials, PXE MAC addresses, and hardware specs for each node.

### Config overrides

Kolla merges any `.conf` file under `infrastructure/kolla-ansible/config/` into the corresponding service config on the VM. The file must be named `<service>.conf` (e.g. `ironic.conf`) at the top level of `config/` — not inside a service subdirectory.

For example [`infrastructure/kolla-ansible/config/ironic.example.conf`](infrastructure/kolla-ansible/config/ironic.example.conf)
shows the local `infrastructure/kolla-ansible/config/ironic.conf` override that
sets `enforce_scope = false` so Horizon can display Ironic nodes with a
project-scoped token.

After changing any config override:

```bash
make kolla-reconfigure TAGS=ironic   # or omit TAGS to reconfigure all services
```

### Image and cache storage

During deploy, Ironic conductor may log that it is downloading the instance image into its local cache before powering on the node. That is expected. The conductor stages images under `/var/lib/ironic`, which Kolla stores in the `ironic` Docker volume.

The Proxmox raw image is slightly larger than Ironic's default 20 GiB master-image cache threshold. The local `infrastructure/kolla-ansible/config/ironic.conf` override, mirrored by [`infrastructure/kolla-ansible/config/ironic.example.conf`](infrastructure/kolla-ansible/config/ironic.example.conf), raises `[pxe] image_cache_size` to 65536 MiB so Ironic can keep the converted Proxmox master image between deploys.

Do not optimize this first by changing the Ironic deploy data path. The safer approach is to keep the cache and backing image store on persistent storage:

- Glance files live under `/var/lib/glance/images`
- Kolla Docker volumes live under `/var/lib/docker/volumes`
- Ironic cache/httpboot lives inside the `ironic` Docker volume
- MariaDB metadata lives inside the `mariadb` Docker volume

The OpenStack VM playbook mounts those paths from the persistent data disk described above. Preserving only Glance files is not enough for a total controller rebuild; Glance also needs its database metadata, or the images must be re-uploaded.

### One-time setup — Glance images and Neutron networks

Before registering nodes, upload the IPA deploy images to Glance and create the provisioning network:

```bash
make openstack-setup
```

This playbook (idempotent):
- Uploads the versioned IPA kernel/initramfs artifacts to Glance
- Removes and recreates stale Glance IPA images when local checksums changed
- Creates `provisioning-net` (flat, physnet1, no Neutron DHCP — Ironic dnsmasq handles it)
- `provisioning-net` doubles as the cleaning network (`ironic_cleaning_network` in local `globals.yml`)

If `make openstack-setup` recreates the deploy kernel or initramfs, the Glance image IDs change. Re-run `make ironic-set-deploy-images NODE=<node>` for any existing node that has explicit `deploy_kernel` / `deploy_ramdisk` driver-info.

### Driver choice: IPMI vs Redfish

`ipmi` is the proven baseline and is enough for deployment. It supports the critical interfaces Ironic needs: power control, boot device management, PXE boot, deploy, networking, and storage. `openstack baremetal node validate` will still show optional interfaces such as `bios`, `console`, `firmware`, `inspect`, `raid`, and `rescue` as `False`; that is expected for the `ipmi` driver.

`redfish` is enabled in Ironic and is worth testing on nodes whose BMC exposes a working Redfish API. The Gigabyte/AST2500 BMCs expose the system at:

```text
/redfish/v1/Systems/Self
```

Redfish node driver-info:

```yaml
driver: redfish
driver_info:
  redfish_address: "https://<bmc-ip>"
  redfish_username: "admin"
  redfish_password: "CHANGE_ME"
  redfish_verify_ca: false
  redfish_system_id: "/redfish/v1/Systems/Self"
```

Quick BMC discovery:

```bash
curl -k -u CHANGE_ME:CHANGE_ME https://<bmc-ip>/redfish/v1/Systems
curl -k -u CHANGE_ME:CHANGE_ME https://<bmc-ip>/redfish/v1/Systems/Self
```

### BMC baseline

Run the BMC baseline before creating or registering the node in OpenStack. The
baseline manages BMC-local users and the fan profile, and Ironic should be
created with the final BMC credentials.

After filling in the `bmc_controllers` inventory in git-ignored
`infrastructure/ansible/inventory/hosts.local.yaml`, apply the BMC baseline:

```bash
make bmc-baseline LIMIT=mbhome-proxmox-01-bmc
make bmc-baseline LIMIT=mbhome-nas-01-bmc
```

The playbook manages BMC-local administrator users. MJ11 BMCs use the BMC web
API for user management and also import
[`infrastructure/ansible/files/bmc/mj11-quiet-fanprofile.json`](infrastructure/ansible/files/bmc/mj11-quiet-fanprofile.json),
set the active fan profile to `quiet`, verify it, and log out. The ASRock Rack
D1541D4U-2T8R / Unraid BMC uses `bmc_user_provider: ipmi` because its HTTPS
stack can fail modern TLS handshakes; it also has `bmc_manage_fan_profile:
false`, so the fan-profile API calls are skipped there. The IPMI path requires
`ipmitool` on the Ansible controller. If the ASRock BMC rejects the default
IPMI settings, adjust `bmc_ipmi_interface` (`lanplus` or `lan`) and
`bmc_ipmi_channel` in `hosts.local.yaml`. Slot `1` is reserved on many IPMI
BMCs, so `bmc_ipmi_min_user_id` defaults to `2`.

It also loads git-ignored
`infrastructure/ansible/vars/bmc-users.local.yaml`: users in `bmc_admin_users`
with a plaintext `password` are created or updated as BMC administrators. The
playbook only changes the BMC users explicitly listed in `bmc_admin_users`.
For BMCs managed through the web API, each user may also include `email`,
`ssh_public_key`, `ssh_public_keys`, or `ssh_key`; when a list is provided, the
first key is written to the BMC `ssh_key` field. Generic IPMI user management
can set the username, password, enabled state, and privilege, but it cannot
install SSH authorized keys.

Start the BMC user vars from
[`infrastructure/ansible/vars/bmc-users.local.example.yaml`](infrastructure/ansible/vars/bmc-users.local.example.yaml)
and keep the real `bmc-users.local.yaml` local only.

The Unraid server BMC is represented in the inventory under
`bmc_asrock_d1541d4u_2t8r` because the ASRock Rack D1541D4U-2T8R uses separate
BMC credentials and does not use the MJ11 fan profile workflow.

### Register nodes

```bash
source infrastructure/kolla-ansible/admin-openrc.sh
source infrastructure/kolla-ansible/.venv/bin/activate
source infrastructure/kolla-ansible/admin-openrc-system.sh

# Register all nodes + PXE ports in one shot
openstack baremetal create infrastructure/ironic/nodes/proxmox-nodes.yaml

# Set IPA deploy images on each node (uploaded to Glance by make openstack-setup)
make ironic-set-deploy-images NODE=mbhome-proxmox-01

# Validate node config. For IPMI, boot/deploy/management/network/power/storage must be True.
# Optional interfaces such as bios/console/inspect/raid/rescue can be False.
openstack baremetal node validate mbhome-proxmox-01

# Move each node through enroll → manageable → available
# (provide triggers automated cleaning: BMC powers on → PXE boots IPA → wipes disk → powers off)
openstack baremetal node manage mbhome-proxmox-01
openstack baremetal node provide mbhome-proxmox-01

# Watch provisioning state
watch -n5 openstack baremetal node show mbhome-proxmox-01 -c provision_state -c last_error

# Update a node's BMC IP later if it changes
openstack baremetal node set mbhome-proxmox-01 --driver-info ipmi_address=<new-ip>
```

> **Note:** IPMI or Redfish controls power/boot-device through the BMC. PXE boot happens over the data NIC on the `192.0.2.x` network — the MAC in `ports.address` is the data NIC, not the BMC.

### Next steps

- Build and upload the Proxmox image, then deploy it onto nodes (see below)
- Deploy Proxmox onto nodes via Ironic

---

## Build and Deploy OS Images (Ironic)

OS images are built with [diskimage-builder (DIB)](https://docs.openstack.org/diskimage-builder/latest/) and uploaded to Glance. Each OS has its own subdirectory under [`infrastructure/dib/`](infrastructure/dib/):

```
infrastructure/dib/
  proxmox/              ← Proxmox VE 9 (Debian 13 base)
    build.sh            ← runs on the OpenStack VM; outputs a raw disk image
    elements/
      proxmox-minimal/  ← adds Proxmox repo, installs proxmox-ve + pve kernel, boot fixes
      proxmox-network/  ← minimal DHCP bootstrap network (Ansible configures final networking)
      proxmox-ssh/      ← injects ~/.ssh/id_ed25519.pub into root authorized_keys
  <future-os>/          ← add future OSes here (same structure)
    build.sh
    elements/
      ...
```

### DIB element structure

Each element is a directory of shell scripts. DIB runs them in phase order inside a chroot of the target OS:

| Directory | When it runs | Purpose |
|---|---|---|
| `install.d/` | During image build | Install packages, write config files |
| `cleanup.d/` | After install, before finalise | Remove temp files, repos, caches |
| `first-boot.d/` | On first boot of the deployed node | Runtime config (hostname, etc.) |
| `element-deps` | — | Declares which other elements this one requires |

Scripts are numbered (`10-`, `20-`, ...) to control execution order.

### Build and upload an image

```bash
# Build the Proxmox image on the OpenStack VM and upload to Glance
# Uses ~/.ssh/id_ed25519.pub by default
make ironic-build-image OS=proxmox

# Override with a different SSH public key file
make ironic-build-image OS=proxmox SSH_KEY_FILE=~/.ssh/deploy_key.pub
```

This copies `infrastructure/dib/proxmox/` to the OpenStack VM, runs DIB there (native Debian/amd64 — no emulation), writes the raw image and metadata under `/var/lib/openstack-data/dib/`, and uploads `/var/lib/openstack-data/dib/proxmox.raw` to Glance as `proxmox`.

To use a different remote build directory:

```bash
make ironic-build-image OS=proxmox DIB_IMAGE_DIR=/path/on/openstack-vm
```

The Glance image keeps the stable name `proxmox` so the deploy helper can look it up reliably, and stores the OS details as standard `os_*` and repo-specific `mbhome_*` image properties:

```bash
openstack image show proxmox \
  -c name \
  -c properties
```

### Add a new OS

1. Create `infrastructure/dib/<os>/elements/` with the required elements
2. Copy `infrastructure/dib/proxmox/build.sh` to `infrastructure/dib/<os>/build.sh` and adjust the `disk-image-create` element list
3. Run:
   ```bash
   make ironic-build-image OS=<os>
   ```

### Deploy an image onto a node

```bash
source infrastructure/kolla-ansible/admin-openrc.sh
source infrastructure/kolla-ansible/.venv/bin/activate

# Get the Glance image UUID
IMAGE_ID=$(openstack image show proxmox -c id -f value)

# Set the image on the node's instance_info (required for standalone Ironic — no --image flag on deploy)
openstack baremetal node set mbhome-proxmox-01 \
  --instance-info image_source=$IMAGE_ID \
  --instance-info image_disk_format=raw \
  --instance-info root_gb=119

# Deploy
openstack baremetal node deploy mbhome-proxmox-01 \
  --config-drive '{"meta_data": {"hostname": "mbhome-proxmox-01"}}'

# Watch progress
watch -n5 openstack baremetal node show mbhome-proxmox-01 -c provision_state -c last_error
```

Ironic will PXE-boot the node into IPA, stream the raw image onto `/dev/sda`, then power-cycle into the installed OS.

To deploy and then automatically run the Proxmox baseline once the installed OS
is active and reachable over SSH:

```bash
make ironic-deploy-proxmox NODE=mbhome-proxmox-01 PROXMOX_IP=192.0.2.51
```

`PROXMOX_IP` is injected through Ironic config-drive on that deployment only. The image stays generic, but the first boot writes a static `systemd-networkd` config for the node's Ironic port MAC. Optional overrides:

```bash
make ironic-deploy-proxmox \
  NODE=mbhome-proxmox-01 \
  PROXMOX_IP=192.0.2.51 \
  PROXMOX_PREFIX=24 \
  PROXMOX_GATEWAY=192.0.2.1 \
  PROXMOX_DNS=192.0.2.1 \
  PROXMOX_MAC=00:00:00:00:00:01
```

If `PROXMOX_MAC` is omitted, the deploy wrapper uses the first Ironic port MAC for the node. If `PROXMOX_IP` is omitted, the node keeps DHCP bootstrap networking and `ANSIBLE_HOST` defaults to `NODE`.

### Verify the deployed Proxmox node

```bash
# SSH should accept the key injected by proxmox-ssh
ssh root@<node-ip>

# Proxmox web UI (self-signed certificate is expected)
open https://<node-ip>:8006

# Confirm the image's kernel parameter is active
cat /proc/cmdline
grep pcie_aspm /etc/default/grub.d/proxmox-extra.cfg /boot/grub/grub.cfg

# Useful service checks if the node gets an IP but SSH/UI do not come up
systemctl status proxmox-bootstrap-hosts ssh pve-cluster pvedaemon pveproxy
journalctl -b -u proxmox-bootstrap-hosts -u ssh -u pve-cluster -u pveproxy --no-pager
```

### Configure Proxmox baseline and 10 GbE storage bridges

Router DHCP reservations provide the Proxmox management IPs. The baseline
playbook does not write static management networking; it manages Proxmox VM
bridges and optional 10 GbE storage bridges from host variables. The public skeleton is
[`infrastructure/ansible/inventory/hosts.yaml`](infrastructure/ansible/inventory/hosts.yaml);
real per-node values live in git-ignored `infrastructure/ansible/inventory/hosts.local.yaml`.

Install the Ansible collections used by the infrastructure playbooks:

```bash
make ansible-collections
```

Run the baseline for one deployed node:

```bash
make proxmox-baseline LIMIT=mbhome-proxmox-01
```

For the 10 GbE storage network, prefer a Proxmox bridge such as `vmbr90` instead
of putting the IP directly on the physical NIC. The physical NIC becomes a
bridge port, and the storage IP moves to the bridge. This lets Proxmox itself
and Talos/Kubernetes VMs share the same storage network.

The `make ironic-deploy-proxmox` wrapper also runs this baseline from the real
inventory, so post-deploy configuration uses the same per-node variables. It
does not run the BMC baseline; run `make bmc-baseline LIMIT=<node-bmc>` before
registering the node in OpenStack.

Direct NFS mounts are controlled by the `proxmox_nfs_mounts` list in
`infrastructure/ansible/inventory/hosts.local.yaml`; use
[`infrastructure/ansible/inventory/hosts.local.example.yaml`](infrastructure/ansible/inventory/hosts.local.example.yaml)
as the committed reference.
If an Unraid share does not exist yet, keep that mount with `enabled: false`.
When the share is created and exported from Unraid, flip it to `enabled: true`
and rerun the baseline.

After Proxmox cluster NFS storages are registered, prefer
`proxmox_nfs_mounts: []` and use Proxmox's own `/mnt/pve/<storage-id>` paths
for testing. This keeps Proxmox as the only NFS client owner for VM storage.

The baseline also aligns Proxmox storage content types. By default, `local` is
allowed to store backups, ISOs, snippets, container templates, VM disks,
container rootdirs, and imported disk images. The `import` content type is
required by the Terraform smoke VM when it downloads a Debian cloud image into
Proxmox.

The DIB-built Proxmox image starts with DHCP on the physical management NIC; it
does not create Proxmox's usual `vmbr0` bridge automatically. Terraform-created
VMs need a Linux bridge, so enable one in
`infrastructure/ansible/inventory/hosts.local.yaml` before creating VMs:

```yaml
proxmox_vm_bridges:
  - name: vmbr0
    # Optional: define proxmox_management_bridge_mac per host to keep an
    # existing router DHCP reservation after DHCP moves from the NIC to vmbr0.
    mac_var: proxmox_management_bridge_mac
    ports:
      - enp3s0   # management NIC on the MJ11 nodes; adjust if a node differs
    dhcp4: true
    link_local: false
    ipv6_accept_ra: false

  - name: vmbr90
    enabled_var: proxmox_storage_bridge_enabled
    ports:
      - enp5s0f0 # 10 GbE storage NIC on the MJ11 nodes; adjust if needed
    address_var: proxmox_storage_bridge_address
    prefix_var: proxmox_storage_bridge_prefix
    dhcp4: false
    link_local: false
    ipv6_accept_ra: false
    required_for_online: "no"
```

Set the storage bridge variables per host that actually has the 10 GbE NIC:

```yaml
mbhome-proxmox-01:
  proxmox_management_bridge_mac: 00:00:00:00:00:01
  proxmox_storage_bridge_enabled: true
  proxmox_storage_bridge_address: 198.51.100.11
  proxmox_storage_bridge_prefix: 24
  proxmox_10gbe_links: []

mbhome-proxmox-02:
  proxmox_management_bridge_mac: 00:00:00:00:00:02
  proxmox_storage_bridge_enabled: true
  proxmox_storage_bridge_address: 198.51.100.12
  proxmox_storage_bridge_prefix: 24
  proxmox_10gbe_links: []
```

Do not configure the same physical interface in both `proxmox_10gbe_links` and
`proxmox_vm_bridges`. The bridge form is the right choice once VMs need access
to that network.

This moves the management DHCP lease onto `vmbr0` and the storage static IP
onto `vmbr90`; both physical NICs become bridge ports. SSH may briefly
disconnect while `systemd-networkd` restarts. After rerunning the baseline,
verify the bridges before retrying Terraform:

```bash
ip -br addr show vmbr0
ip -br addr show vmbr90
bridge link
```

The planned 10 GbE storage network is VLAN-only on the UniFi switch:

```text
VLAN 90, 198.51.100.0/24, no gateway, no DHCP
Unraid 10 GbE: 198.51.100.1
mbhome-proxmox-01 10 GbE: 198.51.100.11
mbhome-proxmox-02 10 GbE: 198.51.100.12
```

Use access/native VLAN 90 on the SFP+ ports so the hosts can use untagged
static IPs directly on their `vmbr90` storage bridges.

After connecting the SFP+ links, verify the storage network before moving NFS:

```bash
ip -br link show enp5s0f0
ip -br addr show vmbr90
ping -c3 198.51.100.1
```

Keep MTU at `1500` until both ends of a storage link are intentionally moved to
jumbo frames.

### Configure Proxmox sudo and Web UI users

The baseline can also create non-root sudo users and register them as Proxmox
Web UI administrators when this local vars file exists:

```text
infrastructure/ansible/vars/proxmox-users.local.yaml
```

Best practice here is:

- Keep the vars file local and git-ignored.
- Store the plaintext password only in the ignored local file; the playbook
  hashes it at runtime before applying it.
- Keep SSH public keys in the same user definition for clarity.
- Use the `pam` Proxmox realm so the Web UI authenticates against the Linux
  account created by Ansible.

Create the file from the example:

```bash
cp infrastructure/ansible/vars/proxmox-users.local.example.yaml \
  infrastructure/ansible/vars/proxmox-users.local.yaml
```

Edit `proxmox-users.local.yaml`, set `password`, and add the SSH public
key. The file is ignored by Git and loaded automatically by `make proxmox-baseline`.

The playbook adds each user to the Linux `sudo` group, creates the Proxmox
`<user>@pam` account, and grants the `Administrator` role on `/` by default.
Sudo still requires the user's password; it is not passwordless.

Log into the Web UI with:

```text
User name: <user>
Realm: Linux PAM standard authentication
```

### Create the Proxmox cluster

Create the Proxmox cluster only after the target nodes have booted into the
deployed OS and `make proxmox-baseline` has completed successfully. The cluster
playbook uses the management address from inventory for corosync by default,
which is the right starting point while only some nodes have 10 GbE.
Join nodes should be fresh Proxmox installs without local guests or storage
state that must be preserved.

Configure these values in git-ignored
`infrastructure/ansible/inventory/hosts.local.yaml`:

```yaml
proxmox_cluster_name: mbhome
proxmox_cluster_primary: mbhome-proxmox-01
proxmox_cluster_link_address_var: ansible_host
proxmox_cluster_migration:
  network: 192.0.2.0/24
  type: secure
```

Then create the cluster from the first two deployed nodes:

```bash
make proxmox-cluster LIMIT='mbhome-proxmox-01:mbhome-proxmox-02'
```

The playbook:

- Ensures each clustered node can resolve the other Proxmox node names
- Creates the cluster on `proxmox_cluster_primary` if it is not clustered yet
- Joins the other nodes one at a time through `pvecm add --use_ssh 1`
- Configures cluster live migration settings from `proxmox_cluster_migration`
- Registers any `proxmox_cluster_nfs_storages` as cluster-wide Proxmox storage
- Configures any `proxmox_cluster_backup_jobs` as Datacenter backup jobs
- Leaves already-clustered nodes alone on later runs

Verify from any Proxmox node:

```bash
pvecm status
pvecm nodes
```

With only two Proxmox nodes, the cluster is useful for centralized management
but it is not a comfortable HA foundation yet. If one node is offline, quorum
can block cluster-wide changes. Before enabling HA, add the third Proxmox node
or configure a qdevice witness.

For live migration tests, define a shared NFS datastore reachable by every
cluster node. While only one Proxmox node has 10 GbE, use Unraid's management
address so both nodes can mount the same storage ID:

Keep migration traffic on the management subnet until every node has 10 GbE:

```yaml
proxmox_cluster_migration:
  network: 192.0.2.0/24
  type: secure
```

After every node has an address on the 10 GbE storage network, change only the
network value, for example `10.20.90.0/24`.

```yaml
proxmox_cluster_nfs_storages:
  - storage: proxmox-vms
    server: 192.0.2.48
    export: /mnt/user/proxmox-vms
    content:
      - images
```

After changing storage definitions, rerun:

```bash
make proxmox-cluster LIMIT='mbhome-proxmox-01:mbhome-proxmox-02'
```

The playbook recreates the Proxmox storage definition when immutable NFS fields
such as `server` or `export` drift from inventory. This removes/re-adds the
cluster storage entry but does not delete files from Unraid.

Verify from either node:

```bash
pvesm status
pvesm config proxmox-vms
```

Cluster backup jobs are also declared in the same inventory. Proxmox does not
have a VM-level default backup policy, but a Datacenter backup job with
`all: true` covers all current VMs/CTs and includes new guests automatically
unless they are explicitly excluded:

```yaml
proxmox_cluster_backup_jobs:
  - id: nightly-all-guests
    schedule: "03:00"
    storage: proxmox-backup
    mode: snapshot
    compress: zstd
    all: true
    enabled: true
    repeat_missed: true
    prune_backups: keep-daily=7,keep-weekly=4,keep-monthly=3
    notes_template: !unsafe "{{guestname}} - {{node}} - {{vmid}}"
```

After rerunning `make proxmox-cluster`, verify the job from a Proxmox node:

```bash
pvesh get /cluster/backup
pvesh get /cluster/backup/nightly-all-guests
```

### Configure Proxmox API automation users

Proxmox users, ACLs, and API tokens are cluster-wide. A token created for
`terraform@pve` can be used against any node's API URL in the cluster, as long
as that node is online and reachable.

The cluster playbook can create Proxmox-only automation users for Terraform.
These are not Linux/PAM users: they do not get SSH access, sudo, a shell, or a
Linux UID.

Create the local vars file:

```bash
cp infrastructure/ansible/vars/proxmox-api-users.local.example.yaml \
  infrastructure/ansible/vars/proxmox-api-users.local.yaml
```

The example creates `terraform@pve` with an API token named `mbhome` and grants
`Administrator` at `/`. That is intentionally broad for the first lab pass.
Later, tighten the role/path once the Terraform VM workflow is stable.

Run the cluster playbook again after editing the file:

```bash
make proxmox-cluster LIMIT='mbhome-proxmox-01:mbhome-proxmox-02'
```

If a token is created, Proxmox shows the token secret only once. The playbook
writes newly generated secrets to this git-ignored local file:

```text
infrastructure/ansible/vars/proxmox-api-tokens.local.generated
```

Copy the generated `user@realm!tokenid=secret` value into the relevant
Terraform vars file. Existing token secrets cannot be recovered; delete and
recreate the token if the secret is lost.

## Proxmox Terraform Workloads

### Create a disposable Proxmox smoke VM

Before building the real Kubernetes layout, use the smoke VM Terraform stack to verify
that the Proxmox API token, datastore, bridge, cloud-init, and VM boot path all
work through the cluster.

Install Terraform on the controller if it is not already available. The make
targets expect a `terraform` binary on `PATH`:

```bash
terraform version
```

Create the local secret vars file if it does not already exist:

```bash
cp infrastructure/terraform/proxmox.shared.example.tfvars \
  infrastructure/terraform/proxmox.shared.local.tfvars
```

Edit `proxmox.shared.local.tfvars` for the Proxmox API token:

- `proxmox_api_token`: token in `user@realm!tokenid=secret` format

Non-secret shared topology lives in `infrastructure/terraform/proxmox.shared.tfvars`.
Edit `proxmox-smoke-vm/terraform.tfvars` for the smoke VM values:

- `proxmox_node`: the Proxmox node that should create the VM
- `vm_datastore_id`: start with `local`; use `proxmox-vms` for live migration
- `cloud_init_datastore_id`: use the same shared datastore as the VM disk for live migration

The Proxmox API token and provider SSH access are separate. The `terraform@pve`
API user does not need SSH access. The BPG provider still uses SSH for some
host-side operations such as `qm disk import`; `~/.ssh/config` is not used by
the provider, so the SSH username must be set explicitly and the key must be
loaded in `ssh-agent`:

```bash
ssh-add -L
ssh root@<proxmox-node-ip>
```

Then create the VM:

```bash
make proxmox-smoke-vm-init
make proxmox-smoke-vm-plan
make proxmox-smoke-vm-apply
```

The stack creates a tiny Debian 13 cloud-init VM named `mbhome-smoke-01`, using
DHCP and the SSH key from `ssh_public_key_file`. Find its lease in the router
or Proxmox UI, then test:

```bash
ssh debian@<smoke-vm-ip>
```

If Proxmox rejects the imported Debian cloud image because `local` does not
allow imported disk images, enable the `Disk image` / `Import` content type on
that storage in the Proxmox UI, or point `image_datastore_id` at a datastore
that supports imports.

Destroy it when done:

```bash
make proxmox-smoke-vm-destroy
```

### Create a Home Assistant OS VM

Home Assistant OS is managed as its own Proxmox Terraform stack because it boots
from the official HAOS KVM/Proxmox qcow2 image rather than from an installer ISO
or cloud-init image.

The stack uses the same shared Proxmox API vars as the other Terraform stacks.
Review these committed topology values before applying:

```text
infrastructure/terraform/proxmox-home-assistant-vm/terraform.tfvars
```

Important values:

- `vm_name`: defaults to `mbhome-ha-01`
- `vm_id`: defaults to `9501`
- `vm_mac_address`: use this for a router DHCP reservation
- `vm_datastore_id`: defaults to `proxmox-vms`
- `haos_image_url`: pinned Home Assistant OS qcow2.xz image

Create the VM:

```bash
make proxmox-home-assistant-vm-init
make proxmox-home-assistant-vm-plan
make proxmox-home-assistant-vm-apply
```

The VM uses OVMF/UEFI with secure-boot keys disabled, q35, VirtIO networking,
and a visible VGA console for the HAOS boot screen. After boot, reserve the
configured MAC address in the router or DHCP server, then open:

```text
http://<home-assistant-ip>:8123
```

If migrating from a Home Assistant Container setup, do not point HAOS directly
at the old NFS-mounted `/config` directory. HAOS stores its data inside the VM
disk and should be migrated with a Home Assistant backup restore. Keep the old
container stopped during the first HAOS restore to avoid two instances using
the same integrations.

## Windows Server and AD DS

### Build a Windows Server template with Packer

The Windows Server Packer stack builds a reusable Proxmox template from a
Windows Server ISO. It uses the same shared Proxmox API vars as the Terraform
stacks, plus a local Packer vars file for Windows-specific settings.

Create the local vars files:

```bash
cp infrastructure/terraform/proxmox.shared.example.pkrvars.hcl \
  infrastructure/terraform/proxmox.shared.local.pkrvars.hcl

cp infrastructure/packer/proxmox-windows-server/packer.example.pkrvars.hcl \
  infrastructure/packer/proxmox-windows-server/packer.local.pkrvars.hcl
```

Packer requires var files to end in `.hcl` or `.json`, so the shared Packer
file is separate from `proxmox.shared.local.tfvars` even though most values are
the same.

Edit `packer.local.pkrvars.hcl`:

- `proxmox_node`: node where the temporary build VM should run
- `windows_iso_file_id`: Proxmox file ID for the Windows Server installer ISO
- `windows_image_name`: exact edition name inside the ISO
- `windows_image_index`: optional image index inside the ISO; when set, it
  overrides `windows_image_name`
- `windows_product_key`: optional installer key for media that requires one;
  leave empty for evaluation media
- `windows_admin_password`: temporary Administrator password used by Packer
- `template_vm_id` / `template_name`: final Proxmox template identity

If you are unsure about `windows_image_name`, list the ISO editions from a
Windows machine:

```powershell
dism /Get-WimInfo /WimFile:D:\sources\install.wim
```

For ISOs where unattended name matching still shows the installer's image
selection screen, set `windows_image_index` instead. For example, use `"2"` for
the second image shown by the installer.

Then build the template:

```bash
make proxmox-windows-template-init
make proxmox-windows-template-validate
make proxmox-windows-template-build
```

The validate/build targets generate an ignored local answer ISO at
`infrastructure/packer/proxmox-windows-server/generated/Autounattend.iso`.
When `windows_product_key` is set, it is embedded into that local answer ISO.
They also generate `generated/SysprepUnattend.xml`, which lets cloned VMs pass
through post-Sysprep OOBE without asking for a new local user. That generated
directory contains the rendered Administrator password, so it must stay out of
git.

The build uses `Autounattend.xml` to install Windows, enables WinRM, connects
once, runs the configured guest-tool/template preparation scripts, runs
Sysprep with a clone-time unattended file, and converts the VM into a Proxmox
template. Cloudbase-Init is optional; the AD VM flow below uses Ansible over
WinRM to set the hostname and static IPv4 address after the clone boots.

### Create Microsoft AD DS VMs

The AD VM Terraform stack creates two long-lived Windows Server VMs by cloning
the Packer-built Windows Server template. It intentionally enforces placement
on different Proxmox nodes and uses the shared `proxmox-vms` datastore.

Build the Windows Server template first. The template should have WinRM enabled
by the Packer build so Ansible can finish per-VM configuration after Terraform
creates the clones.

Create the local secret vars file if it does not already exist:

```bash
cp infrastructure/terraform/proxmox.shared.example.tfvars \
  infrastructure/terraform/proxmox.shared.local.tfvars
```

Edit `proxmox.shared.local.tfvars` for the Proxmox API token:

- `proxmox_api_token`: token in `user@realm!tokenid=secret` format

Non-secret shared topology lives in `infrastructure/terraform/proxmox.shared.tfvars`.
Edit `proxmox-ad-vms/terraform.tfvars` for AD-specific values:

- `template_vm_id`: VMID of the Packer-built Windows Server template
- `template_node_name`: Proxmox node that currently owns the template
- `ad_vms.*.node_name`: keep the two VMs on different Proxmox nodes
- `vm_datastore_id`: keep on shared storage, usually `proxmox-vms`
- `snippet_datastore_id`: snippets-capable storage for generated metadata, usually `proxmox-snippets`

Then create the VMs:

```bash
make proxmox-ad-vms-init
make proxmox-ad-vms-plan
make proxmox-ad-vms-apply
```

The stack creates full clones by default, because domain controllers are
long-lived infrastructure and should not depend on linked-clone parent disk
state. To confirm clone hardware and Cloudbase-Init metadata:

```bash
qm config 9201 | grep -E '^(name|boot|sata0|ide2|agent|net0|ostype):'
qm config 9202 | grep -E '^(name|boot|sata0|ide2|agent|net0|ostype):'
```

After the VMs boot and WinRM is reachable, add their temporary DHCP addresses
or final static addresses to `inventory/hosts.local.yaml` under
`windows_domain_controllers`, then install the Windows Ansible collection and
apply the simple Windows DC baseline:

```bash
make ansible-collections
make windows-dc-baseline LIMIT='mbhome-ad-01:mbhome-ad-02'
```

If Ansible reports that WinRM support is missing on the controller, install the
Python WinRM client used by Ansible:

```bash
python3 -m pip install pywinrm
```

The baseline sets the Windows hostname, reboots if the hostname changed, then
sets the static IPv4 address, gateway, and DNS servers from inventory. If the
first run uses temporary DHCP addresses, update `ansible_host` to the final
static addresses after the network task completes.

Set the AD forest variables in `inventory/hosts.local.yaml` before creating
the domain:

```yaml
windows_domain_controllers:
  vars:
    windows_ad_domain_name: ad.example.test
    windows_ad_domain_netbios_name: AD
    windows_ad_safe_mode_password: CHANGE_ME_DSRM
    windows_ad_domain_mode: WinThreshold
    windows_ad_forest_mode: WinThreshold
```

Then create the initial forest on the primary DC:

```bash
make windows-ad-forest
```

The forest playbook promotes `mbhome-ad-01`, creates a new forest, enables DNS,
uses the requested DSRM password, disables NetBIOS over TCP/IP, and leaves the
server ready for replica promotion. `WinThreshold` is the newest functional
level accepted by modern AD DS deployment cmdlets.

Then promote the second DC as a replica:

```bash
make windows-ad-replica
```

The replica playbook points `mbhome-ad-02` at the primary DC for DNS, promotes
it as an additional domain controller with DNS and Global Catalog enabled,
reboots, then confirms the server is a DC in the domain. If your domain admin
credential is not the default `Administrator@<domain>` with the same password
as `ansible_password`, set these local inventory variables:

```yaml
windows_ad_domain_admin_user: Administrator@ad.example.test
windows_ad_domain_admin_password: CHANGE_ME_DOMAIN_ADMIN
```

After replica promotion, WinRM should normally use the domain credential. If
needed, override the post-promotion connection explicitly:

```yaml
windows_ad_connection_user: Administrator@ad.example.test
windows_ad_connection_password: CHANGE_ME_DOMAIN_ADMIN
```

Install lab LDAPS certificates on the DCs before wiring LDAP-backed services
such as Dex. This creates a self-signed Server Authentication certificate in
each DC's LocalMachine certificate store, restarts AD DS only if TCP/636 is not
already listening, and confirms LDAPS from the Ansible controller:

```bash
make windows-ad-ldaps
```

These certificates are enough for encrypted LDAPS with clients that skip
certificate verification. Replace this with AD CS-issued DC certificates before
treating LDAPS as production-grade.

Validate the domain from either DC after replica promotion:

```powershell
dcdiag /v
repadmin /replsummary
repadmin /showrepl
Get-ADDomainController -Filter * |
  Select-Object HostName,Site,IsGlobalCatalog,IPv4Address
Get-DnsServerZone
w32tm /query /status
```

Expected shape:

- both `mbhome-ad-01` and `mbhome-ad-02` appear as domain controllers
- both DCs are Global Catalog servers
- `repadmin /replsummary` shows no failed replication
- DNS zones include the AD-integrated domain zone and `_msdcs` zone
- Windows Time reports a sane source; configure the PDC emulator time source
  before joining many clients

AD users, groups, and OUs can be managed declaratively with local desired-state
file:

```text
infrastructure/ad/directory.local.yaml
```

The real file is gitignored. It contains the desired directory shape such as
OUs, groups, users, service accounts, group memberships, and initial passwords.
Service accounts are declared separately for readability, but they are
reconciled as AD user objects. Start from the example:

```bash
cp infrastructure/ad/directory.local.example.yaml \
  infrastructure/ad/directory.local.yaml
```

Preview directory changes:

```bash
make windows-ad-directory-check
```

Apply directory changes:

```bash
make windows-ad-directory-apply
```

The reconciler creates missing OUs, groups, users, service accounts, and
declared memberships. It does not delete unmanaged AD objects, which keeps early
homelab iteration safer. Enabled new users and service accounts must include a
`password` in `directory.local.yaml` so they can be created.

For Linux/SSSD integration, configure `posix` ranges in
`directory.local.yaml`. The reconciler allocates the next available values from
AD, writes user UIDs as `uidNumber`, writes group GIDs as `gidNumber`, creates a
private POSIX group named `<username>-primary` for each normal user, and sets
the user's `gidNumber` to that private group's GID. AD users and groups share
the `sAMAccountName` namespace, so the private group needs the suffix even
though Linux commonly uses the same visible name for user-private groups.

AD DNS forwarders and records can also be managed declaratively from a
committed desired-state file:

```text
infrastructure/ad/dns.yaml
```

Example DNS state for public recursion and the Kubernetes API load balancer:

```yaml
forwarders:
  - 10.20.30.1
  - 1.1.1.1
  - 8.8.8.8

zones:
  - name: mbhome.biz
    records:
      - name: k8s-api
        type: A
        value: 10.20.30.50
        ttl: 300
        state: present
```

Preview DNS changes:

```bash
make windows-ad-dns-check
```

Apply DNS changes:

```bash
make windows-ad-dns-apply
```

The DNS reconciler currently supports `A` and `CNAME` records. It creates,
replaces, removes, and updates TTLs for declared records, but it does not delete
unmanaged DNS records. If `forwarders` is present, it becomes the desired DNS
forwarder list for the DC; omit `forwarders` if you only want to manage records.

Terraform should stop at VM lifecycle, placement, and basic hardware. Domain
creation, replication, DNS, time sync, and promotion/demotion are better
handled after boot with PowerShell DSC or Ansible Windows modules over WinRM.

This keeps Terraform from owning fragile, stateful domain-controller operations.

## Talos Kubernetes Cluster (Phase 2 — requires Proxmox)

The old k3s placeholder has been replaced by a Talos-first Kubernetes path.
Start with a single VM workflow. Once that is stable, expand it into a
multi-node Talos control-plane/worker layout, pin the Talos ISO version,
introduce a stable Kubernetes endpoint, bootstrap Kubernetes with `talosctl`,
and then let Flux manage everything under `kubernetes/`.

For the first stable Kubernetes API endpoint, use the HAProxy-on-Unraid bundle:

```text
infrastructure/unraid/haproxy-k8s-api/
```

Deploy it on Unraid, point `k8s-api.mbhome.biz` at the Unraid IP exposing
HAProxy, set `TALOS_K8S_ENDPOINT := k8s-api.mbhome.biz` in `local.mk`, then
regenerate/reapply the Talos config before adding more control-plane nodes.
Keep `TALOS_ENDPOINT` pointed at a real control-plane node IP unless HAProxy is
also proxying the Talos machine API on TCP/50000.

### Create the first Talos VM

The Kubernetes cluster will use Talos Linux instead of k3s-on-Linux. Talos keeps
the node operating system declarative and appliance-like: Terraform owns the VM
lifecycle, Talos owns the node OS configuration, and Kubernetes/Flux own the
cluster workloads.

The first step is a single Talos control-plane VM. This verifies Proxmox VM
creation, shared storage, ISO boot, and network placement before expanding to a
proper multi-node cluster.

Create the local secret vars file if it does not already exist:

```bash
cp infrastructure/terraform/proxmox.shared.example.tfvars \
  infrastructure/terraform/proxmox.shared.local.tfvars
```

Edit `proxmox.shared.local.tfvars` for the Proxmox API token:

- `proxmox_api_token`: token in `user@realm!tokenid=secret` format

Non-secret shared topology lives in `infrastructure/terraform/proxmox.shared.tfvars`.
Edit `proxmox-talos-vm/terraform.tfvars` for the Talos VM values:

- `proxmox_node`: Proxmox node that should create the VM
- `iso_datastore_id`: storage where Proxmox should cache the Talos ISO, usually `proxmox-isos`
- `vm_datastore_id`: storage for the Talos disk, usually `proxmox-vms`
- `talos_iso_url`: pin this to a specific Talos release URL before building the real cluster
- `vm_boot_from_iso`: default boot behavior for nodes that do not set `boot_from_iso`
- `talos_nodes.<name>.boot_from_iso`: per-node boot behavior; set `true` only for a node's first install or intentional reinstall, then set back to `false`
- `talos_nodes.<name>.storage_bridge`: optional second NIC bridge, usually `vmbr90`, for 10 GbE storage/NFS traffic
- `vm_mac_address`: optional fixed MAC for DHCP reservations
- `vm_agent_enabled`: enables the Proxmox QEMU guest-agent flag; Talos also needs a QEMU guest-agent system extension in the ISO/image for the agent to report data
- `vm_efi_disk_type`: OVMF EFI vars disk type, usually `4m`

For first install of a specific node, temporarily set that node entry:

```hcl
talos_nodes = {
  mbhome-talos-worker-03 = {
    role          = "worker"
    proxmox_node  = "mbhome-proxmox-03"
    vm_id         = 9413
    cores         = 4
    memory_mb     = 8192
    disk_gb       = 64
    mac_address   = null
    boot_from_iso = true
  }
}
```

Then create the VM and install Talos:

```bash
make proxmox-talos-vm-init
make proxmox-talos-vm-plan
make proxmox-talos-vm-apply
```

The stack creates one VM named `mbhome-talos-cp-01` by default. With
`boot_from_iso = true` for a node, that node boots the Talos metal ISO and
attaches a blank disk. The VM is not a usable Kubernetes node until Talos
machine configuration is generated and applied with `talosctl`; that comes
after the VM boot path and networking are verified.

After Talos has installed to disk and rebooted once, set that node back to:

```hcl
boot_from_iso = false
```

Then apply Terraform again. This changes the boot order to disk first, while
leaving the ISO attached for future reinstall work:

```bash
make proxmox-talos-vm-apply
```

To attach a Talos VM to the 10 GbE storage bridge, set `storage_bridge` on that
node:

```hcl
talos_nodes = {
  mbhome-talos-worker-01 = {
    role           = "worker"
    proxmox_node   = "mbhome-proxmox-01"
    vm_id          = 9411
    cores          = 4
    memory_mb      = 8192
    disk_gb        = 64
    mac_address    = null
    boot_from_iso  = false
    storage_bridge = "vmbr90"
  }
}
```

The NFS CSI mount is performed by the CSI node plugin on the Talos node, so
Unraid should allow the Talos node storage subnet, for example `10.20.90.0/24`.
You do not need to allow the Kubernetes pod CIDR for these NFS exports unless
you later run pods that mount NFS directly without CSI.

Install `talosctl` on the controller if it is not already available:

```bash
talosctl version --client
```

The Talos config inputs live under:

```text
infrastructure/talos/clusters/mbhome/
```

Committed files in that directory are patches. Generated files such as
`secrets.yaml`, `controlplane.yaml`, `worker.yaml`, `talosconfig`, and
`kubeconfig` are ignored because they contain cluster credentials.

For the first VM, the committed control-plane patch assumes:

- the install disk is `/dev/sda`
- the management NIC is `ens18` on the Proxmox Talos VMs
- networking uses DHCP
- automatic hostname generation is disabled
- the static Talos hostname is `mbhome-talos-cp-01`

After the VM boots the Talos ISO, get its IP address from the Proxmox console
or DHCP server. Add it to `local.mk`, or pass it on each command:

```make
TALOS_CLUSTER_NAME := mbhome
TALOS_CONTROL_PLANE_IP := 192.0.2.70
TALOS_K8S_ENDPOINT := $(TALOS_CONTROL_PLANE_IP)
TALOS_ENDPOINT := $(TALOS_CONTROL_PLANE_IP)
TALOS_NODE := $(TALOS_CONTROL_PLANE_IP)
TALOS_NODE_NAME := mbhome-talos-cp-01
TALOS_CONTROL_PLANE_NODES := mbhome-talos-cp-01 mbhome-talos-cp-02 mbhome-talos-cp-03
TALOS_WORKER_NODES := mbhome-talos-worker-01 mbhome-talos-worker-02 mbhome-talos-worker-03
```

`TALOS_K8S_ENDPOINT` is the Kubernetes API endpoint that gets written into the
cluster config, usually the future HAProxy/load-balancer DNS name.
`TALOS_ENDPOINT` is the Talos machine API endpoint used by `talosctl`; keep it
as a real node IP unless you also proxy TCP/50000. `TALOS_NODE` is the IP of
the machine being managed by the current command, and `TALOS_NODE_NAME` selects
which generated machine config from `infrastructure/talos/clusters/mbhome/nodes/`
should be applied.

Confirm the disk and link names before applying a config:

```bash
make talos-inspect
```

If the output shows a different install disk or NIC, update
`infrastructure/talos/clusters/mbhome/patches/controlplane.yaml` before
continuing.

Generate the Talos secrets and machine configs:

```bash
make talos-gen-secrets
make talos-gen-config
```

`talos-gen-config` writes the base generated role configs plus per-node configs
for the names in `TALOS_CONTROL_PLANE_NODES` and `TALOS_WORKER_NODES`.
The per-node files are ignored under:

```text
infrastructure/talos/clusters/mbhome/nodes/
```

Apply the control-plane machine config to the booted Talos VM:

```bash
make talos-apply-insecure
```

The node will install Talos to disk and reboot. After it comes back, bootstrap
Kubernetes once:

```bash
make talos-bootstrap
```

Fetch the kubeconfig and check health:

```bash
make talos-kubeconfig
```

Install Cilium before adding more nodes. The Talos patches in this repo disable
the default CNI and kube-proxy, so the first control plane may sit in a
not-ready state until Cilium is installed:

```bash
make gateway-api-crds-install
make cilium-helm-repo
make cilium-install
make cilium-status
make cilium-hubble-status
make talos-health
```

Check the installed Talos version:

```bash
make talos-version
```

Talos upgrades happen through the installed node, not by changing the boot ISO
after Talos is installed. The Terraform `talos_iso_url` only controls the ISO
used for bootstrapping/reinstalling a node. After installation, keep
`vm_boot_from_iso = false` so the VM boots from disk; changing the ISO does not
upgrade or downgrade the running Talos OS.

If a freshly rebuilt node does not match the pinned `talos_iso_url`, check the
Proxmox VM config and attached ISO first:

```bash
qm config <vmid> | grep -E '^(boot|ide2|sata|scsi)'
```

Also use a versioned `talos_iso_file_name` whenever you change
`talos_iso_url`, so Proxmox does not keep reusing a generic cached
`talos-metal-amd64.iso`.

To test a Talos upgrade, choose the target version and run the upgrade against
one node:

```bash
make talos-upgrade-plan \
  TALOS_NODE=192.0.2.70 \
  TALOS_UPGRADE_VERSION=v1.13.6

make talos-upgrade \
  TALOS_NODE=192.0.2.70 \
  TALOS_UPGRADE_VERSION=v1.13.6
```

For a single-control-plane lab cluster, set `TALOS_UPGRADE_DRAIN=false` if the
drain step blocks because there is no worker node to receive workloads:

```bash
make talos-upgrade \
  TALOS_NODE=192.0.2.70 \
  TALOS_UPGRADE_VERSION=v1.13.6 \
  TALOS_UPGRADE_DRAIN=false
```

Then verify:

```bash
make talos-version
make talos-health
```

The Cilium values live at:

```text
kubernetes/infrastructure/cilium/values.yaml
```

They use Kubernetes IPAM, Talos' cgroup mount, KubePrism on localhost port
`7445`, Cilium kube-proxy replacement, Gateway API support, and L2
announcements for on-LAN LoadBalancer services. Hubble Relay and Hubble UI are
enabled, with the UI exposed internally at `https://hubble.apps.mbhome.biz`.
The operator replica count starts at `1` for the first control-plane node;
raise it after adding more control-plane nodes.

Gateway API CRDs are installed explicitly by `make gateway-api-crds-install`
because they are cluster-scoped APIs and need to exist before Cilium's Gateway
controller is enabled. Check them with:

```bash
make gateway-api-status
```

### Operate Talos nodes

After the first config has been applied, Talos requires client certificates.
Use the authenticated target for later control-plane config changes:

```bash
make talos-apply
```

To apply a future node, set both the node IP and node config name:

```bash
make talos-apply-insecure \
  TALOS_NODE=192.0.2.71 \
  TALOS_NODE_NAME=mbhome-talos-cp-02

make talos-apply-insecure \
  TALOS_NODE=192.0.2.81 \
  TALOS_NODE_NAME=mbhome-talos-worker-01
```

For a single-node learning cluster only, you can temporarily allow workloads on
the control plane by changing `allowSchedulingOnControlPlanes` to `true` in
`infrastructure/talos/clusters/mbhome/patches/controlplane.yaml`, then
regenerating and reapplying the machine config. For the enterprise-shaped path,
keep it `false` and add separate worker nodes next.

Destroy the first Talos VM when done testing:

```bash
make proxmox-talos-vm-destroy
```

### Bootstrap Flux GitOps

Flux is the preferred GitOps controller for this cluster. It is lightweight,
does not require a UI service, and fits well with the Talos model: Talos owns
node configuration, Flux owns Kubernetes desired state from Git.

Install the Flux CLI on the workstation:

```bash
brew install fluxcd/tap/flux
```

Check the cluster before bootstrapping:

```bash
make flux-check
```

Commit and push the GitOps path before running bootstrap. Flux bootstrap works
against the GitHub repository, not uncommitted local files:

```bash
git add kubernetes
git commit -m "Add mbhome Flux GitOps bootstrap"
git push
```

Create a GitHub token for the bootstrap operation, export it in the current
shell, and bootstrap Flux from this repository:

```bash
export GITHUB_TOKEN=...
make flux-bootstrap-github
```

This target intentionally uses the GitHub bootstrap flow. The PAT is used by
the Flux CLI to talk to the GitHub API, write/update the Flux manifests, and
configure a deploy key. Flux then syncs the repo over SSH using the generated
deploy key stored in the cluster as the `flux-system` secret. We do not use
`--token-auth`, so the PAT is not used as the long-lived Git credential inside
the cluster.

For a fine-grained GitHub PAT on an existing repository, use:

- `Administration`: read and write
- `Contents`: read and write
- `Metadata`: read-only

The bootstrap target sets `FLUX_GITHUB_PRIVATE=false` because this repo is
public, but it still uses the authenticated GitHub bootstrap workflow for
learning the full deploy-key model.

The bootstrap path is:

```text
kubernetes/clusters/mbhome
```

Flux writes its own controller manifests under `flux-system/` and reconciles the
committed platform layers in order:

- `infrastructure`: Cilium CRs, Gateway API, cert-manager, NFS CSI, and operators
- `databases`: PostgreSQL clusters managed by CloudNativePG
- `identity`: Dex and Kubernetes OIDC RBAC
- `apps`: application workloads

Check Flux reconciliation:

```bash
make flux-status
```

Force a sync after pushing changes:

```bash
make flux-reconcile
```

### Flux-managed platform components

NFS CSI is managed here:

```text
kubernetes/infrastructure/nfs-csi/
```

Edit the NFS CSI Flux manifests there before Flux reconciles them if the
Unraid IP or exports change:

- `nfs-cache` `server` should be the Unraid 10 GbE IP, for example `10.20.90.10`
- `nfs-cache` `share` should be a direct cache export, for example `/mnt/cache/k8s-fast`
- `nfs-user` `server` should be the same Unraid 10 GbE IP
- `nfs-user` `share` should be a parity-backed export, for example `/mnt/user/k8s`

Create both paths on Unraid and export them over NFS to the Talos node subnet
before Flux reconciles NFS CSI. For the fast class, export the cache path
directly, for example `/mnt/cache/k8s-fast`, to bypass Unraid user shares and
parity/mover behavior. The CSI driver creates PVC subdirectories inside those
exports, but it does not create or export the top-level shares.

Cilium remains a bootstrap dependency for now because Flux needs a working CNI
before its controllers can run. Cilium values are still applied by
`make cilium-install`, while Cilium custom resources such as LB IPAM pools and
L2 announcement policies and the Hubble UI route are reconciled by Flux:

```text
kubernetes/infrastructure/cilium/
```

The current internal LoadBalancer pool is `10.20.30.200-10.20.30.209`, and the
internal Gateway is pinned to `10.20.30.200` for `*.apps.mbhome.biz`:

```text
kubernetes/infrastructure/gateway-api/
```

Create an internal DNS wildcard such as `*.apps.mbhome.biz -> 10.20.30.200`
before testing HTTPRoutes. This keeps the first Gateway internal-only; later
externally reachable services can be added with Cloudflare Tunnel without
changing the internal Gateway model.

cert-manager is managed by Flux under:

```text
kubernetes/infrastructure/cert-manager/
```

Install cert-manager CRDs before Flux sees cert-manager custom resources:

```bash
make cert-manager-crds-install
```

Create a scoped Cloudflare API token with permission to edit DNS for the
`mbhome.biz` zone, then store it as a Kubernetes Secret. The token is not
committed to Git:

```bash
export CLOUDFLARE_API_TOKEN=...
make cert-manager-cloudflare-secret
```

The committed ClusterIssuers use Let's Encrypt DNS-01 through Cloudflare and
request the wildcard certificate `*.apps.mbhome.biz`. The TLS Secret is created
in the Gateway namespace as:

```text
gateway-system/apps-mbhome-biz-tls
```

Monitoring is managed by Flux under:

```text
kubernetes/infrastructure/monitoring/
```

Metrics Server is managed by Flux under:

```text
kubernetes/infrastructure/metrics-server/
```

It provides the Kubernetes Metrics API for Headlamp usage views, `kubectl top`,
and HPA resource metrics. Check it with:

```bash
make metrics-server-status
```

Vault is managed by Flux under:

```text
kubernetes/infrastructure/vault/
```

It is deployed as an internal-only Vault server at:

```text
https://vault.apps.mbhome.biz
```

The first deployment uses HA Raft mode with a single replica and persistent
storage on `nfs-cache`. Vault starts uninitialized and sealed by design. Check
the deployment with:

```bash
make vault-status
```

Initialize Vault once, then store the unseal keys and initial root token outside
Git before closing the terminal:

```bash
make vault-init
make vault-unseal
make vault-bootstrap
make vault-status
```

`vault-init` defaults to 5 key shares with a threshold of 3. `vault-unseal`
discovers all Vault server pods, skips pods that are already unsealed, and
prompts for the unseal keys. To target one pod, run
`make vault-unseal VAULT_PODS=vault-1`. `vault-bootstrap` prompts for the
initial root token, enables file audit logging, and enables the initial `kv/` KV
v2 mount.

Vault uses Dex for AD-backed human login. Create one random client secret for
the Dex Vault OAuth client, reconcile Dex, and then bootstrap the Vault OIDC auth
method:

```bash
export VAULT_OIDC_CLIENT_SECRET='...'
make vault-oidc-secret
# Commit and push the Dex client change before reconciling.
make flux-reconcile
make vault-oidc-bootstrap
```

`vault-oidc-bootstrap` maps AD groups from Dex into Vault policies:

```text
vault-admins  -> vault-admin
vault-users   -> vault-user
vault-readers -> vault-reader
```

Keep the existing Make secret targets for bootstrap and break-glass until Vault
Secrets Operator is added and the current secrets are migrated.

Vault Secrets Operator is managed by Flux under:

```text
kubernetes/infrastructure/vault-secrets-operator/
```

It uses Vault Kubernetes auth and the internal Vault service
`http://vault-active.vault.svc.cluster.local:8200`. Bootstrap the Vault-side
auth role after Vault is initialized, unsealed, and reconciled:

```bash
make flux-reconcile
make vault-secrets-operator-bootstrap
make vault-secrets-operator-status
```

The initial operator policy is read-only and scoped to future secret paths under
`kv/platform/*` and `kv/apps/*`. Existing Kubernetes Secrets stay on the current
Make targets until their matching Vault KV entries and `VaultStaticSecret`
resources are added.

Create the Grafana admin secret before reconciling the monitoring stack:

```bash
export GRAFANA_ADMIN_PASSWORD='...'
make monitoring-grafana-secret
```

Grafana is configured to use Dex as a confidential OAuth client. Create one
random client secret and store it in both namespaces before reconciling:

```bash
export GRAFANA_OAUTH_CLIENT_SECRET='...'
make grafana-oauth-secret
```

Grafana maps AD groups through Dex:

```text
grafana-admins  -> GrafanaAdmin
grafana-editors -> Editor
grafana-viewers -> Viewer
k8s-admins      -> GrafanaAdmin
k8s-viewers     -> Viewer
```

Users outside those groups can authenticate at Dex but Grafana will reject them.
The local Grafana admin login remains enabled as a break-glass path.

Then reconcile and check the stack:

```bash
make flux-reconcile
make monitoring-status
```

The first internal endpoints are:

```text
https://grafana.apps.mbhome.biz
https://prometheus.apps.mbhome.biz
https://alertmanager.apps.mbhome.biz
```

`prometheus-node-exporter` runs in `kube-system` because it requires host
namespaces, hostPath mounts, and a host port for node metrics. The rest of the
monitoring stack remains in the `monitoring` namespace under Pod Security
`baseline`.

Check issuance with:

```bash
make cert-manager-status
```

cert-manager is configured to use public recursive resolvers for DNS-01
self-checks. This avoids false propagation failures when the cluster's internal
DNS is authoritative for `mbhome.biz` or forwards through AD.

CloudNativePG is managed by Flux under:

```text
kubernetes/infrastructure/cloudnative-pg/
```

It provides the PostgreSQL operator used by Dex. Check the operator with:

```bash
make cloudnative-pg-status
```

Dex's PostgreSQL database is managed by Flux under:

```text
kubernetes/databases/dex-postgres/
```

Create the database owner secret before reconciling the database layer:

```bash
export DEX_POSTGRES_PASSWORD='...'
make dex-postgres-secret
```

Check the database cluster with:

```bash
make dex-postgres-status
```

Dex is managed by Flux under:

```text
kubernetes/infrastructure/dex/
```

It exposes an internal OIDC issuer at:

```text
https://dex.apps.mbhome.biz
```

Dex uses AD DS over LDAPS and expects a non-interactive LDAP bind identity. The
bind DN and password are stored as a Kubernetes Secret, not committed to Git:

```bash
export DEX_LDAP_BIND_DN='CN=svc_dex,OU=Service Accounts,OU=home,DC=mbhome,DC=biz'
export DEX_LDAP_BIND_PASSWORD='...'
make dex-ldap-secret
```

Grafana is registered in Dex as a confidential OAuth client. The client secret
must match the one stored for Grafana:

```bash
export GRAFANA_OAUTH_CLIENT_SECRET='...'
make grafana-oauth-secret
```

After Flux deploys Dex, check the release and OIDC discovery endpoint:

```bash
make dex-status
```

The repo includes a credential-free OIDC kubeconfig template at
`kubernetes/clusters/mbhome/kubeconfig.oidc.yaml`. Install it into your home
directory for day-to-day access:

```bash
make kubernetes-oidc-context
export KUBECONFIG="${HOME}/.kube/mbhome-oidc"
kubectl auth whoami
```

`kubectl auth whoami` invokes `kubectl oidc-login` when no valid token is
cached. The committed OIDC kubeconfig uses `--skip-open-browser`, so the plugin
prints the localhost callback URL instead of opening browser tabs automatically.
That callback then redirects to Dex.

Or merge the OIDC context into the default kubeconfig and select it:

```bash
make kubernetes-oidc-merge-context
unset KUBECONFIG
kubectl auth whoami
```

If `KUBECONFIG` is still exported, plain `kubectl` keeps using that file
instead of the merged default `~/.kube/config`.

You can also test the merged mbhome OIDC context while ignoring the current
shell's `KUBECONFIG` value:

```bash
make kubernetes-oidc-whoami
```

If the Kubernetes API endpoint or cluster CA changes, regenerate the committed
template from the Talos admin kubeconfig:

```bash
make dex-generate-oidc-kubeconfig
```

The initial RBAC bindings expect AD groups named `k8s-admins` and
`k8s-viewers`. Kubernetes will see them as `oidc:k8s-admins` and
`oidc:k8s-viewers` after the Talos API server OIDC settings are applied.
