variable "proxmox_api_url" {
  description = "Proxmox API endpoint, e.g. https://10.20.30.51:8006/."
  type        = string
}

variable "proxmox_api_token" {
  description = "Proxmox API token in the format user@realm!tokenid=<uuid>."
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
  description = "Initial Proxmox node for the development VM."
  type        = string
}

variable "image_datastore_id" {
  description = "Node-local datastore used for the imported Debian cloud image."
  type        = string
  default     = "local"
}

variable "vm_datastore_id" {
  description = "Datastore for the VM disk. Shared storage permits migration between Proxmox nodes."
  type        = string
  default     = "proxmox-vms"
}

variable "cloud_init_datastore_id" {
  description = "Datastore for the generated cloud-init disk."
  type        = string
  default     = "proxmox-vms"
}

variable "vm_network_bridge" {
  description = "Proxmox bridge connected to the management network."
  type        = string
  default     = "vmbr0"
}

variable "cloud_image_url" {
  description = "Debian cloud image URL imported by Proxmox."
  type        = string
  default     = "https://cloud.debian.org/images/cloud/trixie/latest/debian-13-genericcloud-amd64.qcow2"
}

variable "cloud_image_file_name" {
  description = "File name for the imported Debian cloud image."
  type        = string
  default     = "debian-13-genericcloud-amd64.qcow2"
}

variable "ssh_public_key_file" {
  description = "SSH public key injected into the development VM."
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "vm_hostname" {
  description = "Static short hostname used by Proxmox and cloud-init."
  type        = string
  default     = "mbhome-dev-01"

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?$", var.vm_hostname))
    error_message = "vm_hostname must be a valid lowercase DNS hostname label."
  }
}

variable "vm_id" {
  description = "Fixed Proxmox VM ID."
  type        = number
  default     = 9601
}

variable "vm_username" {
  description = "Cloud-init user created for SSH and later Ansible management."
  type        = string
  default     = "debian"
}

variable "vm_started" {
  description = "Start the VM after creation."
  type        = bool
  default     = true
}

variable "vm_cores" {
  description = "Development VM vCPU cores."
  type        = number
  default     = 4
}

variable "vm_cpu_type" {
  description = "Proxmox CPU type."
  type        = string
  default     = "x86-64-v2-AES"
}

variable "vm_memory_mb" {
  description = "Development VM memory in MiB."
  type        = number
  default     = 8192
}

variable "vm_disk_gb" {
  description = "Development VM root disk size in GiB."
  type        = number
  default     = 64
}

variable "vm_ipv4_address" {
  description = "Static IPv4 address in CIDR notation."
  type        = string
  default     = "10.20.30.91/24"
}

variable "vm_ipv4_gateway" {
  description = "IPv4 default gateway."
  type        = string
  default     = "10.20.30.1"
  nullable    = true
}

variable "vm_dns_domain" {
  description = "DNS search domain."
  type        = string
  default     = "mbhome.biz"
}

variable "vm_dns_servers" {
  description = "DNS servers used by the VM. AD DNS must be first for domain discovery."
  type        = list(string)
  default     = ["10.20.30.11", "10.20.30.12"]
}
