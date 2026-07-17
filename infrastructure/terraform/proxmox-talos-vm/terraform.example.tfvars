proxmox_node = "mbhome-proxmox-01"

# Pin this URL once you choose the Talos version for the real cluster. The
# default uses GitHub's latest release redirect for quick smoke testing.
# talos_iso_url       = "https://github.com/siderolabs/talos/releases/download/vX.Y.Z/metal-amd64.iso"
# talos_iso_file_name = "talos-vX.Y.Z-metal-amd64.iso"

iso_datastore_id = "proxmox-isos"
vm_datastore_id  = "proxmox-vms"

# Defaults used by each talos_nodes entry unless overridden.
vm_cores         = 2
vm_memory_mb     = 4096
vm_disk_gb       = 32
vm_started       = true
vm_on_boot       = false
vm_boot_from_iso = false
vm_agent_enabled = true
vm_efi_disk_type = "4m"
# Optional default for a second Talos VM storage NIC. Leave null and set
# storage_bridge per node while rolling this out gradually.
vm_storage_bridge = null

# Declare only the nodes Terraform should create now. Keep future nodes
# commented until DNS/DHCP reservations and Proxmox placement are ready.
talos_nodes = {
  mbhome-talos-cp-01 = {
    role                = "controlplane"
    proxmox_node        = "mbhome-proxmox-01"
    vm_id               = 9401
    cores               = 2
    memory_mb           = 4096
    disk_gb             = 32
    mac_address         = null
    boot_from_iso       = false
    storage_bridge      = "vmbr90"
    storage_mac_address = "BC:24:11:75:1D:59"
  }

  # mbhome-talos-cp-02 = {
  #   role                = "controlplane"
  #   proxmox_node        = "mbhome-proxmox-02"
  #   vm_id               = 9402
  #   cores               = 2
  #   memory_mb           = 4096
  #   disk_gb             = 32
  #   mac_address         = null
  #   boot_from_iso       = false
  #   storage_bridge      = "vmbr90"
  #   storage_mac_address = "02:90:20:30:72:02"
  # }

  # mbhome-talos-cp-03 = {
  #   role                = "controlplane"
  #   proxmox_node        = "mbhome-proxmox-03"
  #   vm_id               = 9403
  #   cores               = 2
  #   memory_mb           = 4096
  #   disk_gb             = 32
  #   mac_address         = null
  #   boot_from_iso       = false
  #   storage_bridge      = "vmbr90"
  #   storage_mac_address = "02:90:20:30:73:02"
  # }

  # mbhome-talos-worker-01 = {
  #   role                = "worker"
  #   proxmox_node        = "mbhome-proxmox-01"
  #   vm_id               = 9411
  #   cores               = 4
  #   memory_mb           = 8192
  #   disk_gb             = 64
  #   mac_address         = null
  #   boot_from_iso       = false
  #   storage_bridge      = "vmbr90"
  #   storage_mac_address = "02:90:20:30:81:02"
  # }

  # mbhome-talos-worker-02 = {
  #   role                = "worker"
  #   proxmox_node        = "mbhome-proxmox-02"
  #   vm_id               = 9412
  #   cores               = 4
  #   memory_mb           = 8192
  #   disk_gb             = 64
  #   mac_address         = null
  #   boot_from_iso       = false
  #   storage_bridge      = "vmbr90"
  #   storage_mac_address = "02:90:20:30:82:02"
  # }

  # mbhome-talos-worker-03 = {
  #   role         = "worker"
  #   proxmox_node = "mbhome-proxmox-03"
  #   vm_id        = 9413
  #   cores        = 4
  #   memory_mb    = 8192
  #   disk_gb      = 64
  #   mac_address  = null
  #   boot_from_iso = false
  #   storage_bridge = null
  # }
}
