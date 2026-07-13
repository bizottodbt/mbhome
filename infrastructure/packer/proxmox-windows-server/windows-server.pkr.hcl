packer {
  required_version = ">= 1.10.0"

  required_plugins {
    proxmox = {
      source  = "github.com/hashicorp/proxmox"
      version = ">= 1.2.3"
    }
  }
}

locals {
  proxmox_api_url_base = trimsuffix(var.proxmox_api_url, "/")
  proxmox_api_url      = endswith(local.proxmox_api_url_base, "/api2/json") ? local.proxmox_api_url_base : "${local.proxmox_api_url_base}/api2/json"
  proxmox_token_parts  = split("=", var.proxmox_api_token)
}

source "proxmox-iso" "windows_server" {
  proxmox_url              = local.proxmox_api_url
  username                 = local.proxmox_token_parts[0]
  token                    = local.proxmox_token_parts[1]
  insecure_skip_tls_verify = var.proxmox_api_insecure

  node                 = var.proxmox_node
  vm_id                = var.template_vm_id
  vm_name              = var.template_name
  template_name        = var.template_name
  template_description = "Windows Server template built by Packer on ${formatdate("YYYY-MM-DD hh:mm:ss ZZZ", timestamp())}."
  tags                 = "mbhome;packer;windows;template"

  os              = var.windows_os_type
  bios            = "ovmf"
  machine         = "q35"
  boot            = "order=sata2;sata0"
  cpu_type        = var.vm_cpu_type
  scsi_controller = var.vm_scsi_controller

  efi_config {
    efi_storage_pool  = var.vm_datastore_id
    efi_format        = "raw"
    efi_type          = "4m"
    pre_enrolled_keys = false
  }

  boot_iso {
    type         = "sata"
    index        = 2
    iso_file     = var.windows_iso_file_id
    iso_checksum = var.windows_iso_checksum
    unmount      = true
  }

  dynamic "additional_iso_files" {
    for_each = var.attach_autounattend_iso ? [1] : []

    content {
      type             = "ide"
      index            = 0
      iso_url          = "file://${abspath("${path.root}/generated/Autounattend.iso")}"
      iso_checksum     = "none"
      iso_storage_pool = var.packer_iso_datastore_id
      unmount          = true
    }
  }

  dynamic "additional_iso_files" {
    for_each = var.virtio_win_iso_file_id != "" ? [1] : []

    content {
      type     = "ide"
      index    = 1
      iso_file = var.virtio_win_iso_file_id
      unmount  = true
    }
  }

  boot_wait         = "1s"
  boot_key_interval = "1s"
  boot_command = [
    "<spacebar><spacebar><spacebar><spacebar><spacebar><spacebar><spacebar><spacebar><spacebar><spacebar><spacebar><spacebar>"
  ]

  cores   = var.vm_cores
  memory  = var.vm_memory_mb
  sockets = 1

  disks {
    type         = "sata"
    disk_size    = var.vm_disk_size
    storage_pool = var.vm_datastore_id
    format       = var.vm_disk_format
    cache_mode   = "none"
    io_thread    = false
    discard      = true
  }

  network_adapters {
    model       = "e1000"
    bridge      = var.vm_network_bridge
    mac_address = var.vm_mac_address != "" ? var.vm_mac_address : null
  }

  communicator   = "winrm"
  winrm_host     = var.winrm_host != "" ? var.winrm_host : null
  winrm_username = "Administrator"
  winrm_password = var.windows_admin_password
  winrm_timeout  = "6h"
  winrm_use_ssl  = false
  winrm_insecure = true
  winrm_use_ntlm = true

  qemu_agent = var.enable_qemu_agent
}

build {
  name = "windows-server"

  sources = [
    "source.proxmox-iso.windows_server"
  ]

  provisioner "powershell" {
    environment_vars = [
      "CLOUDBASE_INIT_MSI_URL=${var.cloudbase_init_msi_url}",
      "ENABLE_CLOUDBASE_INIT=${var.enable_cloudbase_init}",
      "ENABLE_WINDOWS_UPDATE=${var.enable_windows_update}",
      "WINDOWS_UPDATE_STRICT=${var.windows_update_strict}",
      "VIRTIO_WIN_ISO_ATTACHED=${var.virtio_win_iso_file_id != ""}"
    ]
    scripts = [
      "scripts/install-guest-tools.ps1",
      "scripts/install-cloudbase-init.ps1",
      "scripts/install-windows-updates.ps1"
    ]
  }

  provisioner "file" {
    source      = "${path.root}/generated/SysprepUnattend.xml"
    destination = "C:/Windows/Panther/SysprepUnattend.xml"
  }

  provisioner "powershell" {
    environment_vars = [
      "DISABLE_INSECURE_WINRM_AFTER_BUILD=${var.disable_insecure_winrm_after_build}",
      "ENABLE_CLOUDBASE_INIT=${var.enable_cloudbase_init}"
    ]
    scripts = [
      "scripts/prepare-sysprep.ps1"
    ]
  }
}
