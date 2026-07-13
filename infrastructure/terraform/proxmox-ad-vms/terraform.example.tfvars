vm_datastore_id         = "proxmox-vms"
cloud_init_datastore_id = "proxmox-vms"
snippet_datastore_id    = "proxmox-snippets"
template_vm_id          = 9300
template_node_name      = "mbhome-proxmox-01"
template_full_clone     = true
windows_os_type         = "win11"
vm_bios                 = "ovmf"
vm_machine              = "q35"
vm_disk_interface       = "sata0"
vm_disk_format          = "qcow2"
vm_network_model        = "e1000"
vm_agent_enabled        = true
dns_domain              = "ad.example.test"
dns_servers             = []

ad_vms = {
  mbhome-ad-01 = {
    node_name    = "mbhome-proxmox-01"
    hostname     = "mbhome-ad-01"
    vm_id        = 9201
    ipv4_address = "192.0.2.61/24"
    ipv4_gateway = "192.0.2.1"
    cores        = 2
    memory_mb    = 4096
    disk_gb      = 60
  }

  mbhome-ad-02 = {
    node_name    = "mbhome-proxmox-02"
    hostname     = "mbhome-ad-02"
    vm_id        = 9202
    ipv4_address = "192.0.2.62/24"
    ipv4_gateway = "192.0.2.1"
    cores        = 2
    memory_mb    = 4096
    disk_gb      = 60
  }
}
