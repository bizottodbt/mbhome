# Homelab Network Plan

## Goals

This plan keeps the current Google Home router setup working while leaving a
clean path to UniFi VLANs later.

Current constraints:

- The home LAN is a flat `192.0.2.0/24`.
- The current router does not provide VLANs.
- A UniFi USW-Pro-48 switch is available and can provide layer-2 VLANs through
  the UniFi Network controller running on Unraid.
- PXE/Ironic provisioning happens on the same flat LAN.
- Only Unraid and the two MJ11/Proxmox nodes are expected to have 10 GbE at
  first.
- The USW-Pro-48 has four SFP+ ports, so the initial 10 GbE topology is a
  switched storage network instead of direct-attached host-to-host links.

Important rule: IP ranges inside one `/24` are only an address-management
convention. They do not isolate traffic. Real BMC, management, and storage
separation requires VLANs or physically separate networks.

## Current Flat LAN

Network:

```text
192.0.2.0/24
Gateway/DNS: 192.0.2.1
```

Recommended address reservations while the network is still flat:

| Range | Purpose | Notes |
|---|---|---|
| `192.0.2.1` | Router/gateway/DNS | Google Home router today |
| `192.0.2.2-192.0.2.9` | Reserved infrastructure | Future network devices, switches, controllers |
| `192.0.2.10-192.0.2.19` | Core services | OpenStack VM is `192.0.2.10` |
| `192.0.2.20-192.0.2.39` | BMC/IPMI/Redfish | Server management controllers |
| `192.0.2.40-192.0.2.59` | Proxmox management | Proxmox web UI, SSH, cluster management |
| `192.0.2.60-192.0.2.79` | Unraid and storage services | Unraid is currently `192.0.2.48` |
| `192.0.2.80-192.0.2.99` | Static service VMs | Later DNS, AD, monitoring, GitOps services |
| `192.0.2.100-192.0.2.200` | Ironic PXE/DHCP pool | Served by Ironic dnsmasq, not Neutron DHCP |
| `192.0.2.201-192.0.2.239` | General DHCP clients | Phones, laptops, temporary devices |
| `192.0.2.240-192.0.2.254` | Reserved | Break-glass, experiments, future migration |

Suggested current assignments:

| Device | Role | Address |
|---|---|---|
| Google Home router | Gateway/DNS | `192.0.2.1` |
| OpenStack VM | Ironic controller | `192.0.2.10` |
| Unraid | Storage and VM host | `192.0.2.48` |
| `mbhome-proxmox-01` BMC | Redfish/IPMI | `192.0.2.20` if the router can reserve it later |
| `mbhome-proxmox-02` BMC | Redfish/IPMI | `192.0.2.21` if the router can reserve it later |
| `mbhome-proxmox-01` OS | Proxmox management | `192.0.2.51` |
| `mbhome-proxmox-02` OS | Proxmox management | `192.0.2.52` |

If the router cannot reserve an address until a device appears, deploy the node
with Ironic config-drive static networking:

```bash
make ironic-deploy-proxmox NODE=mbhome-proxmox-01 PROXMOX_IP=192.0.2.51
```

Keep any static `PROXMOX_IP` values outside the router's normal DHCP pool when
possible.

## Current 10 GbE Switched Storage Plan

The USW-Pro-48 provides a proper shared 10 GbE layer-2 segment, so the storage
network no longer needs point-to-point `/30` links. Use one static subnet across
the SFP+ ports:

```text
198.51.100.0/24
No gateway
No DHCP in the first phase
```

Recommended addressing on the 10 GbE storage network:

| Device/interface | Address | CIDR | Purpose |
|---|---:|---|---|
| Unraid 10 GbE | `198.51.100.1` | `198.51.100.0/24` | NFS/storage endpoint |
| `mbhome-proxmox-01` `vmbr90` | `198.51.100.11` | `198.51.100.0/24` | NFS, migration, replication, VM storage network |
| `mbhome-proxmox-02` `vmbr90` | `198.51.100.12` | `198.51.100.0/24` | NFS, migration, replication, VM storage network |
| `mbhome-proxmox-03` `vmbr90` | `198.51.100.13` | `198.51.100.0/24` | Future, when a 10 GbE NIC is added |

These bridges should not have a default gateway. The default route stays on the
`192.0.2.0/24` management LAN. The physical 10 GbE NIC, for example
`enp5s0f0`, is a bridge port; the IP belongs on `vmbr90`.

For Proxmox storage mounts, prefer the Unraid 10 GbE IP after the switch ports
and Unraid interface are configured and ping-tested:

```text
mbhome-proxmox-* mounts Unraid from 198.51.100.1
```

Recommended usage by traffic type:

| Traffic | Preferred network |
|---|---|
| PXE/Ironic deployment | `192.0.2.0/24` management LAN |
| Proxmox web UI and SSH | `192.0.2.0/24` management LAN |
| Proxmox cluster/quorum | `192.0.2.0/24` management LAN initially |
| NFS storage | `198.51.100.0/24` 10 GbE storage VLAN |
| Proxmox migration/replication between 10 GbE nodes | `198.51.100.0/24` 10 GbE storage VLAN |

This keeps management/PXE on the router LAN and moves storage plus heavy
node-to-node traffic onto the SFP+ switch fabric.

### UniFi Switch Setup Before a UniFi Router

The UniFi Network controller running in Docker on Unraid manages switch config;
it does not need to be the router. Before a UniFi router exists, use a VLAN-only
network for storage:

| Setting | Value |
|---|---|
| Network name | `Storage` |
| VLAN ID | `90` |
| Gateway/DHCP | None on UniFi for now |
| Subnet documentation | `198.51.100.0/24` |
| SFP+ ports for Unraid/Proxmox | Access/native network `Storage` |
| Switch uplink and 1 GbE management ports | Default/current LAN |

With access ports, the hosts do not need VLAN subinterfaces. Configure the 10
GbE NICs directly with static `198.51.100.x/24` addresses and no gateway.

If a port is later changed to a trunk, then the host should move the storage IP
onto a VLAN subinterface such as `enp5s0f0.90`. Do not mix access-port and
host-tagged VLAN config on the same link.

The fourth SFP+ port can be kept for a future 10 GbE NIC in `mbhome-proxmox-03`,
for a future 10 GbE uplink, or for a temporary test host.

## Future UniFi VLAN Plan

When a UniFi router and managed switch are added, move from range conventions to
actual VLAN separation.

Recommended VLANs:

| VLAN | Name | Subnet | Purpose |
|---:|---|---|---|
| 10 | BMC | TBD | IPMI/Redfish management controllers |
| 20 | Management/PXE | TBD | Proxmox management, OpenStack/Ironic, PXE |
| 90 | Storage | TBD | NFS, backups, Proxmox storage, migration |
| 40 | Services | TBD | AD, DNS, monitoring, GitOps, app services |
| 50 | Clients | TBD | Laptops, phones, general home clients |

The current `192.0.2.0/24` remains the temporary flat management LAN. Storage
uses `198.51.100.0/24` now, so it can carry forward into the future routed UniFi
design without colliding with the current router LAN.

Future VLAN placement:

| Device/interface | VLAN |
|---|---|
| BMC ports | VLAN 10, access |
| Proxmox 1 GbE management/PXE NICs | VLAN 20, access |
| OpenStack VM management/provisioning NIC | VLAN 20 |
| Unraid 1 GbE management | VLAN 20 or VLAN 30, depending on operational preference |
| 10 GbE storage switch ports | VLAN 90, access initially |
| User devices | VLAN 50 |

Firewall policy later:

| Source | Destination | Policy |
|---|---|---|
| Management/PXE -> BMC | Allow admin workstation, OpenStack/Ironic, Ansible |
| Clients -> BMC | Deny |
| Management/PXE -> Storage | Allow required NFS/SSH/API |
| Storage -> Clients | Deny by default |
| Services -> Management | Allow only specific admin paths |

## Naming

Suggested names:

| Name | Meaning |
|---|---|
| `mbhome-nas-01` | Unraid |
| `openstack` | OpenStack/Ironic controller VM |
| `mbhome-proxmox-01` | First Proxmox node |
| `mbhome-proxmox-02` | Second Proxmox node |
| `mbhome-proxmox-01-bmc` | First node BMC |
| `mbhome-proxmox-02-bmc` | Second node BMC |

## Operating Rules

- Keep PXE and the installed Proxmox management interface reachable on the flat
  LAN until VLANs exist.
- Keep BMCs on known static/reserved addresses, even before VLANs.
- Use Ironic config-drive static IPs for Proxmox nodes when the router cannot
  reserve leases ahead of time.
- Use the switched `198.51.100.0/24` storage VLAN for SFP+ traffic.
- Do not use the 10 GbE storage VLAN as a default route.
- Move storage mounts to `198.51.100.1` only after link detection and basic ping
  tests pass.
