# mbhome
Repo for cluster and infrastructure deployment.

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

### Configure Proxmox baseline and 10 GbE links

Router DHCP reservations provide the Proxmox management IPs. The baseline
playbook does not write static management networking; it only manages extra
10 GbE point-to-point interfaces from host variables. The public skeleton is
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

The 10 GbE links are configured with `systemd-networkd` files named
`/etc/systemd/network/05-proxmox-10gbe-*.network`, ahead of the image's
catch-all DHCP bootstrap file. NFS continues to mount through the management
address `192.0.2.48` until the USW-Pro-48 SFP+ storage VLAN is configured and
tested.

The `make ironic-deploy-proxmox` wrapper also runs this baseline from the real
inventory, so post-deploy configuration uses the same per-node variables. It
does not run the BMC baseline; run `make bmc-baseline LIMIT=<node-bmc>` before
registering the node in OpenStack.

NFS mounts are controlled by the `proxmox_nfs_mounts` list in
`infrastructure/ansible/inventory/hosts.local.yaml`; use
[`infrastructure/ansible/inventory/hosts.local.example.yaml`](infrastructure/ansible/inventory/hosts.local.example.yaml)
as the committed reference.
If an Unraid share does not exist yet, keep that mount with `enabled: false`.
When the share is created and exported from Unraid, flip it to `enabled: true`
and rerun the baseline.

The planned 10 GbE storage network is VLAN-only on the UniFi switch:

```text
VLAN 90, 198.51.100.0/24, no gateway, no DHCP
Unraid 10 GbE: 198.51.100.1
mbhome-proxmox-01 10 GbE: 198.51.100.11
mbhome-proxmox-02 10 GbE: 198.51.100.12
```

Use access/native VLAN 90 on the SFP+ ports so the hosts can use untagged
static IPs directly on their 10 GbE interfaces.

After connecting the SFP+ links, verify the storage network before moving NFS:

```bash
ip -br link show enp5s0f0
ip -br addr show enp5s0f0
ping -c3 198.51.100.1
```

Once a node can reach Unraid over the 10 GbE storage VLAN, change only that
node's `proxmox_nfs_server` inventory value, or promote it to a group default
after all nodes are tested:

```yaml
proxmox_nfs_server: 198.51.100.1
```

Then rerun the baseline for that node. Keep MTU at `1500` until both ends of a
storage link are intentionally moved to jumbo frames.

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

---

## k3s App Cluster (Phase 2 — requires Proxmox)

```bash
cd infrastructure/terraform/proxmox && terraform apply   # provision k3s VMs
make k3s-bootstrap                                        # install k3s + bootstrap Flux
# Flux then manages everything under kubernetes/app-cluster/
```
