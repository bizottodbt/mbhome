proxmox_node = "mbhome-proxmox-01"

# Home Assistant OS KVM/Proxmox image. Pin to a known release for reproducible
# rebuilds, then update from inside Home Assistant OS after boot.
haos_image_url       = "https://github.com/home-assistant/operating-system/releases/download/18.1/haos_ova-18.1.qcow2.xz"
haos_image_file_name = "haos_ova-18.1.qcow2.img"

image_datastore_id = "local"
vm_datastore_id    = "proxmox-vms"

vm_name          = "mbhome-ha-01"
vm_id            = 9501
vm_started       = true
vm_on_boot       = true
vm_agent_enabled = true
vm_cores         = 2
vm_memory_mb     = 4096
vm_disk_gb       = 64
vm_mac_address   = "BC:24:11:48:41:01"

vm_network_bridge = "vmbr0"
