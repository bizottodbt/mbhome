variable "proxmox_api_url" {
  description = "Proxmox API endpoint, e.g. https://192.0.2.51:8006/"
  type        = string
}

variable "proxmox_api_token" {
  description = "Proxmox API token in the format: user@realm!tokenid=<uuid>"
  type        = string
  sensitive   = true
}

variable "proxmox_node" {
  description = "Primary Proxmox node name for VM creation (as shown in Proxmox UI)"
  type        = string
  default     = "pve-01"
}

variable "vm_network_bridge" {
  description = "Proxmox network bridge for VM NICs"
  type        = string
  default     = "vmbr0"
}

variable "nfs_storage_id" {
  description = "Proxmox storage ID for Unraid NFS VM disks (proxmox-vm share)"
  type        = string
  default     = "unraid-vm"
}
