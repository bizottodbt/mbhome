proxmox_node = "mbhome-proxmox-01"

# Keep the imported base image on local storage, but put all VM disks on the
# shared NFS datastore so online migration can work.
image_datastore_id      = "local"
vm_datastore_id         = "proxmox-vms"
cloud_init_datastore_id = "proxmox-vms"

ssh_public_key_file = "~/.ssh/id_ed25519.pub"

vm_name         = "mbhome-smoke-01"
vm_id           = 9100
vm_started      = true
vm_cores        = 1
vm_memory_mb    = 1024
vm_disk_gb      = 8
vm_ipv4_address = "dhcp"
