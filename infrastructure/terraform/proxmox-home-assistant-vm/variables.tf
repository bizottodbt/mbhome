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
  description = "Proxmox cluster node name that creates/hosts the Home Assistant VM."
  type        = string
}

variable "image_datastore_id" {
  description = "Datastore on proxmox_node used to store the imported HAOS image."
  type        = string
  default     = "local"
}

variable "vm_datastore_id" {
  description = "Datastore for the Home Assistant VM disk."
  type        = string
  default     = "proxmox-vms"
}

variable "vm_network_bridge" {
  description = "Proxmox Linux bridge for the Home Assistant VM NIC."
  type        = string
  default     = "vmbr0"
}

variable "haos_image_url" {
  description = "Home Assistant OS KVM/Proxmox qcow2.xz image URL. Pin this for reproducible VM rebuilds."
  type        = string
  default     = "https://github.com/home-assistant/operating-system/releases/download/18.1/haos_ova-18.1.qcow2.xz"
}

variable "haos_image_file_name" {
  description = "File name for the decompressed imported HAOS image in Proxmox ISO storage."
  type        = string
  default     = "haos_ova-18.1.qcow2.img"
}

variable "haos_image_decompression_algorithm" {
  description = "Proxmox download-url decompression algorithm. Proxmox handles HAOS qcow2.xz via zst decompression."
  type        = string
  default     = "zst"
}

variable "haos_image_checksum" {
  description = "Optional checksum for the HAOS image URL."
  type        = string
  default     = null
}

variable "haos_image_checksum_algorithm" {
  description = "Checksum algorithm used when haos_image_checksum is set."
  type        = string
  default     = "sha256"
}

variable "haos_image_upload_timeout" {
  description = "Timeout in seconds for the Proxmox node to download and unpack the HAOS image."
  type        = number
  default     = 3600
}

variable "vm_name" {
  description = "Home Assistant VM name."
  type        = string
  default     = "mbhome-ha-01"
}

variable "vm_id" {
  description = "Optional fixed Proxmox VM ID. Leave null to let Proxmox allocate one."
  type        = number
  default     = null
}

variable "vm_started" {
  description = "Start the VM after creation."
  type        = bool
  default     = true
}

variable "vm_on_boot" {
  description = "Start the VM when the Proxmox node boots."
  type        = bool
  default     = true
}

variable "vm_agent_enabled" {
  description = "Enable the Proxmox QEMU guest agent flag. HAOS includes QEMU guest agent support."
  type        = bool
  default     = true
}

variable "vm_cores" {
  description = "Home Assistant VM vCPU cores."
  type        = number
  default     = 2
}

variable "vm_cpu_type" {
  description = "Proxmox CPU type."
  type        = string
  default     = "host"
}

variable "vm_memory_mb" {
  description = "Home Assistant VM memory in MiB."
  type        = number
  default     = 4096
}

variable "vm_disk_gb" {
  description = "Home Assistant VM disk size in GiB. HAOS defaults around 32 GiB; use more for add-ons and history."
  type        = number
  default     = 64
}

variable "vm_disk_format" {
  description = "Home Assistant VM disk format."
  type        = string
  default     = "qcow2"
}

variable "vm_disk_interface" {
  description = "Home Assistant VM disk interface."
  type        = string
  default     = "scsi0"
}

variable "vm_scsi_hardware" {
  description = "SCSI controller model for the Home Assistant VM."
  type        = string
  default     = "virtio-scsi-single"
}

variable "vm_mac_address" {
  description = "Optional fixed MAC address for DHCP reservations."
  type        = string
  default     = null
}

variable "vm_vlan_id" {
  description = "Optional VLAN tag for the Home Assistant VM NIC."
  type        = number
  default     = null
}
