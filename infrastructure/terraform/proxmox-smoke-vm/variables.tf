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

variable "proxmox_node" {
  description = "Proxmox cluster node name that creates/hosts the smoke VM."
  type        = string
}

variable "image_datastore_id" {
  description = "Datastore on proxmox_node that stores imported cloud images."
  type        = string
  default     = "local"
}

variable "vm_datastore_id" {
  description = "Datastore for the smoke VM disk. Use shared storage later if testing migration."
  type        = string
  default     = "local"
}

variable "cloud_init_datastore_id" {
  description = "Datastore for the generated cloud-init disk."
  type        = string
  default     = "local"
}

variable "vm_network_bridge" {
  description = "Proxmox Linux bridge for the smoke VM NIC."
  type        = string
  default     = "vmbr0"
}

variable "cloud_image_url" {
  description = "Debian cloud image URL to import into Proxmox."
  type        = string
  default     = "https://cloud.debian.org/images/cloud/trixie/latest/debian-13-genericcloud-amd64.qcow2"
}

variable "cloud_image_file_name" {
  description = "File name for the imported cloud image in Proxmox."
  type        = string
  default     = "debian-13-genericcloud-amd64.qcow2"
}

variable "ssh_public_key_file" {
  description = "SSH public key injected into the smoke VM."
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "vm_name" {
  description = "Smoke VM name."
  type        = string
  default     = "mbhome-smoke-01"
}

variable "vm_id" {
  description = "Optional fixed Proxmox VM ID. Leave null to let Proxmox allocate one."
  type        = number
  default     = null
}

variable "vm_username" {
  description = "Cloud-init user created in the smoke VM."
  type        = string
  default     = "debian"
}

variable "vm_started" {
  description = "Start the VM after creation."
  type        = bool
  default     = true
}

variable "vm_cores" {
  description = "Smoke VM vCPU cores."
  type        = number
  default     = 1
}

variable "vm_cpu_type" {
  description = "Proxmox CPU type."
  type        = string
  default     = "x86-64-v2-AES"
}

variable "vm_memory_mb" {
  description = "Smoke VM memory in MiB."
  type        = number
  default     = 1024
}

variable "vm_disk_gb" {
  description = "Smoke VM disk size in GiB."
  type        = number
  default     = 8
}

variable "vm_ipv4_address" {
  description = "Cloud-init IPv4 address. Use dhcp for router-assigned addressing."
  type        = string
  default     = "dhcp"
}

variable "vm_ipv4_gateway" {
  description = "Cloud-init IPv4 gateway. Leave null when vm_ipv4_address is dhcp."
  type        = string
  default     = null
}
