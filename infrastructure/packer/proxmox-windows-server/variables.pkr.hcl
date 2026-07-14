variable "proxmox_api_url" {
  description = "Proxmox API endpoint. The shared Terraform value without /api2/json is accepted."
  type        = string
}

variable "proxmox_api_token" {
  description = "Proxmox API token in the Terraform-style format: user@realm!tokenid=secret."
  type        = string
  sensitive   = true
}

variable "proxmox_api_insecure" {
  description = "Allow self-signed Proxmox certificates."
  type        = bool
  default     = true
}

variable "vm_network_bridge" {
  description = "Proxmox bridge for the template NIC. Kept compatible with proxmox.shared.local.tfvars."
  type        = string
  default     = "vmbr0"
}

variable "proxmox_node" {
  description = "Proxmox node where Packer creates the temporary VM."
  type        = string
}

variable "template_vm_id" {
  description = "VMID for the generated Windows Server template."
  type        = number
  default     = 9300
}

variable "template_name" {
  description = "Name of the generated Proxmox template."
  type        = string
  default     = "tpl-windows-server-2025"
}

variable "windows_iso_file_id" {
  description = "Proxmox ISO file ID for the Windows Server installer."
  type        = string
}

variable "windows_iso_checksum" {
  description = "Windows ISO checksum. Use sha256:<hash> when known; 'none' is accepted for local lab iteration."
  type        = string
  default     = "none"
}

variable "windows_image_name" {
  description = "Windows image name inside install.wim. Must match the ISO edition exactly."
  type        = string
  default     = "Windows Server 2025 SERVERSTANDARD"
}

variable "windows_image_index" {
  description = "Optional Windows image index inside install.wim. When set, Autounattend selects by index instead of windows_image_name."
  type        = string
  default     = ""
}

variable "windows_product_key" {
  description = "Optional Windows product key. Leave empty for evaluation media."
  type        = string
  default     = ""
  sensitive   = true
}

variable "windows_admin_password" {
  description = "Temporary local Administrator password used during Packer build and Sysprep."
  type        = string
  sensitive   = true
}

variable "winrm_host" {
  description = "Optional explicit IP or DNS name for Packer WinRM. Use this when the build VM has no guest agent for IP discovery."
  type        = string
  default     = ""
}

variable "windows_computer_name" {
  description = "Temporary hostname used while building the template."
  type        = string
  default     = "PACKER-WIN"
}

variable "windows_os_type" {
  description = "Proxmox OS type."
  type        = string
  default     = "win11"
}

variable "windows_input_locale" {
  description = "Windows input/system/user locale."
  type        = string
  default     = "en-US"
}

variable "windows_timezone" {
  description = "Windows time zone ID."
  type        = string
  default     = "W. Europe Standard Time"
}

variable "vm_datastore_id" {
  description = "Proxmox datastore for the template disk and EFI disk."
  type        = string
  default     = "proxmox-vms"
}

variable "vm_mac_address" {
  description = "Optional fixed MAC address for the build VM NIC. Useful with DHCP reservations and winrm_host."
  type        = string
  default     = ""
}

variable "packer_iso_datastore_id" {
  description = "Proxmox datastore where Packer uploads temporary generated ISOs."
  type        = string
  default     = "proxmox-isos"
}

variable "attach_autounattend_iso" {
  description = "Attach the generated Autounattend.iso as a second CD-ROM. Disable only while debugging Windows ISO boot."
  type        = bool
  default     = true
}

variable "virtio_win_iso_file_id" {
  description = "Optional Proxmox file ID for a virtio-win ISO. When set, Packer attaches it and installs QEMU guest tools/drivers."
  type        = string
  default     = ""
}

variable "enable_qemu_agent" {
  description = "Enable the Proxmox QEMU guest agent flag on the template VM. Install guest tools with virtio_win_iso_file_id."
  type        = bool
  default     = false
}

variable "enable_cloudbase_init" {
  description = "Install Cloudbase-Init for per-clone Windows customization."
  type        = bool
  default     = false
}

variable "cloudbase_init_msi_url" {
  description = "Cloudbase-Init MSI URL. Used only when enable_cloudbase_init is true."
  type        = string
  default     = "https://www.cloudbase.it/downloads/CloudbaseInitSetup_Stable_x64.msi"
}

variable "enable_windows_update" {
  description = "Run Windows Update during template build. This can add a lot of time."
  type        = bool
  default     = false
}

variable "windows_update_strict" {
  description = "Fail the build when Windows Update fails. Keep false for lab templates because Windows Update can fail under WinRM."
  type        = bool
  default     = false
}

variable "disable_insecure_winrm_after_build" {
  description = "Disable the temporary Basic/unencrypted WinRM settings before Sysprep. Keep false if post-clone automation needs simple WinRM."
  type        = bool
  default     = false
}

variable "vm_disk_size" {
  description = "Template disk size."
  type        = string
  default     = "60G"
}

variable "vm_disk_format" {
  description = "Template disk format."
  type        = string
  default     = "qcow2"
}

variable "vm_cpu_type" {
  description = "CPU type for the build VM. Keep aligned with Terraform-created Windows VMs."
  type        = string
  default     = "x86-64-v2-AES"
}

variable "vm_scsi_controller" {
  description = "SCSI controller model for the build VM. Keep aligned with Terraform-created Windows VMs."
  type        = string
  default     = "virtio-scsi-pci"
}

variable "vm_cores" {
  description = "CPU cores for the build VM."
  type        = number
  default     = 2
}

variable "vm_memory_mb" {
  description = "Memory for the build VM."
  type        = number
  default     = 4096
}
