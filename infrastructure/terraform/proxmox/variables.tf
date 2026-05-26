variable "proxmox_api_url" {
  description = "Proxmox API endpoint, e.g. https://10.20.30.51:8006/"
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

variable "k3s_version" {
  description = "k3s version to install on VMs via cloud-init"
  type        = string
  default     = "v1.35.5+k3s1"
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

variable "k3s_token" {
  description = "Shared token for k3s cluster join"
  type        = string
  sensitive   = true
}
