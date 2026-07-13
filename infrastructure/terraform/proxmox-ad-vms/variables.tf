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
  description = "SSH user for provider host-side Proxmox operations. This is separate from proxmox_api_token."
  type        = string
  default     = "root"
}

variable "vm_datastore_id" {
  description = "Shared datastore for AD VM disks."
  type        = string
  default     = "proxmox-vms"
}

variable "cloud_init_datastore_id" {
  description = "Datastore for the generated Cloudbase-Init/cloud-init drive."
  type        = string
  default     = "proxmox-vms"
}

variable "snippet_datastore_id" {
  description = "Datastore that stores generated Cloudbase-Init metadata snippets."
  type        = string
  default     = "proxmox-snippets"
}

variable "vm_network_bridge" {
  description = "Proxmox Linux bridge for AD VM NICs."
  type        = string
  default     = "vmbr0"
}

variable "windows_os_type" {
  description = "Proxmox guest OS type for Windows Server. Use win11 for newer Windows Server releases, or win10 if needed."
  type        = string
  default     = "win11"
}

variable "vm_cpu_type" {
  description = "Proxmox CPU type."
  type        = string
  default     = "x86-64-v2-AES"
}

variable "vm_bios" {
  description = "Proxmox BIOS type. Modern Windows Server installer media should use ovmf."
  type        = string
  default     = "ovmf"
}

variable "vm_machine" {
  description = "Proxmox machine type."
  type        = string
  default     = "q35"
}

variable "vm_disk_interface" {
  description = "Disk interface for cloned AD VMs. Keep aligned with the Packer template unless intentionally changing hardware."
  type        = string
  default     = "sata0"
}

variable "vm_disk_format" {
  description = "Disk format for cloned AD VM disks."
  type        = string
  default     = "qcow2"
}

variable "vm_network_model" {
  description = "Network model. Use virtio only when the Windows template includes VirtIO drivers."
  type        = string
  default     = "e1000"
}

variable "vm_agent_enabled" {
  description = "Enable the Proxmox QEMU guest agent flag. Enable only when the Packer template includes QEMU guest tools."
  type        = bool
  default     = false
}

variable "template_vm_id" {
  description = "VM ID of the Packer-built Windows Server template."
  type        = number
  default     = 9300
}

variable "template_node_name" {
  description = "Proxmox node that currently owns the Packer-built Windows Server template."
  type        = string
}

variable "template_full_clone" {
  description = "Create full clones from the Windows template. Keep true for resilient long-lived domain controllers."
  type        = bool
  default     = true
}

variable "dns_domain" {
  description = "Optional DNS search domain passed to Cloudbase-Init."
  type        = string
  default     = null
}

variable "dns_servers" {
  description = "Optional DNS servers passed to Cloudbase-Init."
  type        = list(string)
  default     = []
}

variable "ad_vms" {
  description = "Exactly two AD/domain-controller VM definitions. node_name values must be different."
  type = map(object({
    node_name    = string
    hostname     = optional(string)
    vm_id        = optional(number)
    ipv4_address = string
    ipv4_gateway = optional(string)
    cores        = optional(number, 2)
    memory_mb    = optional(number, 4096)
    disk_gb      = optional(number, 60)
    on_boot      = optional(bool, true)
    started      = optional(bool, true)
  }))

  validation {
    condition     = length(var.ad_vms) == 2
    error_message = "ad_vms must contain exactly two VM definitions: one primary and one replica."
  }

  validation {
    condition     = length(distinct([for vm in values(var.ad_vms) : vm.node_name])) == length(var.ad_vms)
    error_message = "Each AD VM must target a different Proxmox node."
  }
}
