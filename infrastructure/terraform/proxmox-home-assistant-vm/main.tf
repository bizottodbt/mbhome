terraform {
  required_version = ">= 1.6.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.61"
    }
  }
}

provider "proxmox" {
  endpoint  = var.proxmox_api_url
  api_token = var.proxmox_api_token
  insecure  = var.proxmox_api_insecure

  ssh {
    agent    = var.proxmox_ssh_agent
    username = var.proxmox_ssh_username
  }
}

resource "proxmox_download_file" "haos_image" {
  content_type            = "iso"
  datastore_id            = var.image_datastore_id
  decompression_algorithm = var.haos_image_decompression_algorithm
  file_name               = var.haos_image_file_name
  node_name               = var.proxmox_node
  overwrite               = false
  upload_timeout          = var.haos_image_upload_timeout
  url                     = var.haos_image_url
  checksum                = var.haos_image_checksum
  checksum_algorithm      = var.haos_image_checksum != null ? var.haos_image_checksum_algorithm : null
}

resource "proxmox_virtual_environment_vm" "home_assistant" {
  name        = var.vm_name
  description = "Home Assistant OS VM for mbhome."
  tags        = ["mbhome", "terraform", "home-assistant", "haos"]
  node_name   = var.proxmox_node
  vm_id       = var.vm_id
  bios        = "ovmf"
  machine     = "q35"

  boot_order = [var.vm_disk_interface]

  on_boot         = var.vm_on_boot
  started         = var.vm_started
  stop_on_destroy = true
  scsi_hardware   = var.vm_scsi_hardware

  agent {
    enabled = var.vm_agent_enabled

    wait_for_ip {
      disabled = true
    }
  }

  cpu {
    cores = var.vm_cores
    type  = var.vm_cpu_type
  }

  memory {
    dedicated = var.vm_memory_mb
  }

  efi_disk {
    datastore_id      = var.vm_datastore_id
    file_format       = "raw"
    pre_enrolled_keys = false
    type              = "4m"
  }

  disk {
    datastore_id = var.vm_datastore_id
    discard      = "on"
    file_format  = var.vm_disk_format
    file_id      = proxmox_download_file.haos_image.id
    interface    = var.vm_disk_interface
    iothread     = true
    size         = var.vm_disk_gb
  }

  network_device {
    bridge      = var.vm_network_bridge
    mac_address = var.vm_mac_address
    model       = "virtio"
    vlan_id     = var.vm_vlan_id
  }

  operating_system {
    type = "l26"
  }

  vga {
    type = "std"
  }
}
