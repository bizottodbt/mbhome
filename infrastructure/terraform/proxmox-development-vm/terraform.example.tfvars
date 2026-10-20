proxmox_node = "mbhome-proxmox-03"

image_datastore_id      = "local"
vm_datastore_id         = "proxmox-vms"
cloud_init_datastore_id = "proxmox-vms"

ssh_public_key_file = "~/.ssh/id_ed25519.pub"

vm_hostname     = "mbhome-dev-01"
vm_id           = 9601
vm_started      = true
vm_cores        = 4
vm_memory_mb    = 8192
vm_disk_gb      = 64
vm_ipv4_address = "10.20.30.91/24"
vm_ipv4_gateway = "10.20.30.1"
vm_dns_domain   = "mbhome.biz"
vm_dns_servers  = ["10.20.30.11", "10.20.30.12"]
