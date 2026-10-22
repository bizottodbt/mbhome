terraform {
  required_version = ">= 1.17.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.118"
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

resource "proxmox_download_file" "debian_cloud_image" {
  content_type = "import"
  datastore_id = var.image_datastore_id
  file_name    = var.cloud_image_file_name
  node_name    = var.proxmox_node
  url          = var.cloud_image_url
}

resource "proxmox_virtual_environment_vm" "development" {
  name        = var.vm_hostname
  description = "Debian development VM managed by Terraform. Guest configuration and AD membership are managed by Ansible."
  tags        = ["mbhome", "terraform", "development", "debian"]
  node_name   = var.proxmox_node
  vm_id       = var.vm_id

  on_boot         = true
  started         = var.vm_started
  stop_on_destroy = true

  agent {
    enabled = false

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

  disk {
    datastore_id = var.vm_datastore_id
    discard      = "on"
    file_id      = proxmox_download_file.debian_cloud_image.id
    interface    = "scsi0"
    size         = var.vm_disk_gb
  }

  initialization {
    datastore_id = var.cloud_init_datastore_id

    dns {
      domain  = var.vm_dns_domain
      servers = var.vm_dns_servers
    }

    ip_config {
      ipv4 {
        address = var.vm_ipv4_address
        gateway = var.vm_ipv4_gateway
      }
    }

    user_account {
      keys     = [trimspace(file(pathexpand(var.ssh_public_key_file)))]
      username = var.vm_username
    }
  }

  network_device {
    bridge = var.vm_network_bridge
    model  = "virtio"
  }

  operating_system {
    type = "l26"
  }

  serial_device {}

  vga {
    type = "serial0"
  }

  lifecycle {
    precondition {
      condition     = var.vm_ipv4_address != "dhcp" && var.vm_ipv4_gateway != null
      error_message = "The development VM requires a static CIDR address and IPv4 gateway."
    }
  }
}
