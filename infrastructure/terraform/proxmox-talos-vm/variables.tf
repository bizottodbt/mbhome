variable "proxmox_api_url" {
  description = "Proxmox API endpoint, e.g. https://10.20.30.51:8006/"
  type        = string
}

variable "proxmox_api_token" {
  description = "Proxmox API token in the format: user@realm!tokenid=<uuid>"
  type        = string
  sensitive   = true
}

variable "proxmox_api_insecure" {
  description = "Allow self-signed Proxmox certificates."
  type        = bool
  default     = true
}

variable "proxmox_ssh_agent" {
  description = "Use ssh-agent for provider SSH operations on the Proxmox host."
  type        = bool
  default     = true
}

variable "proxmox_ssh_username" {
  description = "SSH user for provider host-side Proxmox operations."
  type        = string
  default     = "root"
}

variable "proxmox_node" {
  description = "Legacy/default Proxmox node for the first Talos VM when talos_nodes is not set."
  type        = string
}

variable "iso_datastore_id" {
  description = "Datastore on proxmox_node used to store the Talos ISO."
  type        = string
  default     = "proxmox-isos"
}

variable "vm_datastore_id" {
  description = "Datastore for the Talos VM disk. Use shared storage if testing migration."
  type        = string
  default     = "proxmox-vms"
}

variable "vm_network_bridge" {
  description = "Proxmox Linux bridge for the Talos VM NIC."
  type        = string
  default     = "vmbr0"
}

variable "talos_iso_url" {
  description = "Talos metal ISO URL. Pin this to a release URL for reproducible clusters."
  type        = string
  default     = "https://github.com/siderolabs/talos/releases/latest/download/metal-amd64.iso"
}

variable "talos_iso_file_name" {
  description = "File name for the imported Talos ISO in Proxmox."
  type        = string
  default     = "talos-metal-amd64.iso"
}

variable "vm_name" {
  description = "Legacy/default Talos VM name when talos_nodes is not set."
  type        = string
  default     = "mbhome-talos-cp-01"
}

variable "vm_id" {
  description = "Legacy/default optional fixed Proxmox VM ID when talos_nodes is not set. Leave null to let Proxmox allocate one."
  type        = number
  default     = null
}

variable "talos_nodes" {
  description = "Declarative Talos VM map keyed by VM/hostname. Set only the nodes you want Terraform to create now."
  type = map(object({
    role                = string
    proxmox_node        = string
    vm_id               = optional(number)
    started             = optional(bool)
    on_boot             = optional(bool)
    cores               = optional(number)
    memory_mb           = optional(number)
    disk_gb             = optional(number)
    mac_address         = optional(string)
    vlan_id             = optional(number)
    boot_from_iso       = optional(bool)
    storage_bridge      = optional(string)
    storage_mac_address = optional(string)
    storage_vlan_id     = optional(number)
  }))
  default = null

  validation {
    condition = var.talos_nodes == null || alltrue([
      for node in values(var.talos_nodes) : contains(["controlplane", "worker"], node.role)
    ])
    error_message = "Each talos_nodes entry must use role \"controlplane\" or \"worker\"."
  }
}

variable "vm_started" {
  description = "Start the VM after creation."
  type        = bool
  default     = true
}

variable "vm_on_boot" {
  description = "Start the VM when the Proxmox node boots."
  type        = bool
  default     = false
}

variable "vm_boot_from_iso" {
  description = "Boot the Talos installer ISO before disk. Set true only for first install or intentional reinstall, then set false so host reboots boot the installed disk."
  type        = bool
  default     = false
}

variable "vm_agent_enabled" {
  description = "Enable the Proxmox QEMU guest agent flag. Talos also needs a QEMU guest agent system extension in the image for the agent to report data."
  type        = bool
  default     = true
}

variable "vm_cores" {
  description = "Talos VM vCPU cores."
  type        = number
  default     = 2
}

variable "vm_cpu_type" {
  description = "Proxmox CPU type."
  type        = string
  default     = "x86-64-v2-AES"
}

variable "vm_memory_mb" {
  description = "Talos VM memory in MiB."
  type        = number
  default     = 4096
}

variable "vm_disk_gb" {
  description = "Talos VM disk size in GiB."
  type        = number
  default     = 40
}

variable "vm_disk_format" {
  description = "Talos VM disk format."
  type        = string
  default     = "qcow2"
}

variable "vm_disk_interface" {
  description = "Talos VM disk interface."
  type        = string
  default     = "scsi0"
}

variable "iso_interface" {
  description = "CD-ROM interface used to boot the Talos ISO."
  type        = string
  default     = "ide2"
}

variable "vm_network_model" {
  description = "Talos VM network model."
  type        = string
  default     = "virtio"
}

variable "vm_mac_address" {
  description = "Optional fixed MAC address for DHCP reservations."
  type        = string
  default     = null
}

variable "vm_vlan_id" {
  description = "Optional VLAN tag for the Talos VM NIC."
  type        = number
  default     = null
}

variable "vm_storage_bridge" {
  description = "Optional Proxmox Linux bridge for a second Talos VM storage NIC, for example vmbr90. Leave null to create only the management NIC."
  type        = string
  default     = null
}

variable "vm_storage_mac_address" {
  description = "Optional fixed MAC address for the Talos VM storage NIC."
  type        = string
  default     = null
}

variable "vm_storage_vlan_id" {
  description = "Optional VLAN tag for the Talos VM storage NIC."
  type        = number
  default     = null
}

variable "vm_bios" {
  description = "Proxmox BIOS type."
  type        = string
  default     = "ovmf"
}

variable "vm_machine" {
  description = "Proxmox machine type."
  type        = string
  default     = "q35"
}

variable "vm_efi_disk_type" {
  description = "OVMF EFI vars disk type."
  type        = string
  default     = "4m"
}
