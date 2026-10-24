# Debian development VM

This Terraform stack creates a long-lived Debian 13 development VM in the
Proxmox cluster. It uses a static address and AD DNS from first boot, while
leaving operating-system configuration and Active Directory membership to
Ansible.

The committed defaults are:

- Hostname: `mbhome-dev-01`
- FQDN: `mbhome-dev-01.mbhome.biz`
- Address: `10.20.30.91/24`
- Gateway: `10.20.30.1`
- DNS: `10.20.30.11`, `10.20.30.12`
- Proxmox VM ID: `9601`
- Initial node: `mbhome-proxmox-03`
- VM and cloud-init storage: `proxmox-vms`

Before applying, reserve `10.20.30.91` or exclude it from the DHCP pool and
confirm that VM ID `9601` is unused. Override site-local values in
`terraform.local.tfvars` when needed.

```bash
make proxmox-development-vm-init
make proxmox-development-vm-plan
make proxmox-development-vm-apply
```

After first boot:

```bash
ssh debian@10.20.30.91
```

## Active Directory

Join AD afterward with Ansible. Terraform owns VM hardware, placement, and
cloud-init networking; Ansible owns Debian packages, time synchronization,
Kerberos, SSSD, PAM/NSS, access policy, and the domain join. This separation
keeps join credentials out of Terraform state and makes reconfiguration and
domain leave/rejoin operations safer and repeatable.

The configuration play installs the development toolchain, generates the
`en_US.UTF-8` locale, joins the host to AD with SSSD, permits `linux-users` and
`linux-admins` to sign in, and grants sudo to `linux-admins`. Supply the join
password only for the initial join:

```bash
export AD_JOIN_PASSWORD='the delegated join-account password'
make development-vm-configure
unset AD_JOIN_PASSWORD
```

`ad_join_user` is intentionally unqualified in inventory. Kerberos realm names
are case-sensitive, and `realmd` will qualify it with the discovered
`MBHOME.BIZ` realm.

The join is idempotent. Later runs do not require `AD_JOIN_PASSWORD` while the
machine remains joined. A delegated AD account with permission to create and
update objects in `OU=Computers,OU=home,DC=mbhome,DC=biz` is preferred over a
domain administrator.

SSSD uses the POSIX `uidNumber` and `gidNumber` values managed in AD rather
than deriving local IDs from object SIDs. Before granting login access, ensure
each user, its primary group, and permitted supplementary groups have unique
POSIX IDs in the directory state. Changing these values does not rewrite
ownership of files already created on Linux hosts.

SSH also resolves public keys from each AD user's `altSecurityIdentities`
attribute through SSSD. Store each key as a complete OpenSSH authorized-key
line, for example `ssh-ed25519 AAAA... user@host`. The attribute is
multi-valued, so a user may have multiple keys. Certificate-mapping values such
as `X509:<I>...` are not SSH keys and are ignored by OpenSSH.

The toolchain includes Python, `uv`, Node.js/npm, Codex CLI, PostgreSQL client
and headers, Docker/Compose, Ansible, Terraform, Packer, kubectl, Helm, Flux,
Talos CLI, Kustomize, Trivy, Git LFS, and the usual shell/build utilities. Log
out and back in after the first run so the `docker` group membership applies.

## Codex agent account

Create the always-on agent identity separately from interactive AD users:

```bash
make codex-agent-account
```

This creates the locked local `codex-agent` system account with `/bin/bash`, a
private home at `/var/lib/codex-agent`, and its repository workspace at
`/var/lib/codex-agent/workspaces`. The account has no sudo policy and is not a
member of `docker`, `libvirt`, or other supplementary groups. Its password is
locked; processes can be launched as this identity by systemd or root, but the
account cannot be used for password login.

Forgejo credentials, OpenAI authentication, Remote connectivity, and any
background service are intentionally configured in later steps so none of
those permissions are implied merely by creating the local account.
