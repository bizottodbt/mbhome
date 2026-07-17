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

locals {
  talos_nodes = var.talos_nodes != null ? var.talos_nodes : {
    (var.vm_name) = {
      role                = "controlplane"
      proxmox_node        = var.proxmox_node
      vm_id               = var.vm_id
      started             = var.vm_started
      on_boot             = var.vm_on_boot
      cores               = var.vm_cores
      memory_mb           = var.vm_memory_mb
      disk_gb             = var.vm_disk_gb
      mac_address         = var.vm_mac_address
      vlan_id             = var.vm_vlan_id
      boot_from_iso       = var.vm_boot_from_iso
      storage_bridge      = var.vm_storage_bridge
      storage_mac_address = var.vm_storage_mac_address
      storage_vlan_id     = var.vm_storage_vlan_id
    }
  }

  talos_node_storage_bridges = {
    for name, node in local.talos_nodes :
    name => try(node.storage_bridge, null) != null ? node.storage_bridge : var.vm_storage_bridge
  }

  talos_node_storage_mac_addresses = {
    for name, node in local.talos_nodes :
    name => try(node.storage_mac_address, null) != null ? node.storage_mac_address : var.vm_storage_mac_address
  }

  talos_node_storage_vlan_ids = {
    for name, node in local.talos_nodes :
    name => try(node.storage_vlan_id, null) != null ? node.storage_vlan_id : var.vm_storage_vlan_id
  }
}

resource "proxmox_download_file" "talos_iso" {
  content_type = "iso"
  datastore_id = var.iso_datastore_id
  file_name    = var.talos_iso_file_name
  node_name    = var.proxmox_node
  url          = var.talos_iso_url
}

// Preserve state when moving from the original single-VM resource to the
// multi-node map using the default first control-plane node name.
moved {
  from = proxmox_virtual_environment_vm.talos
  to   = proxmox_virtual_environment_vm.talos["mbhome-talos-cp-01"]
}

resource "proxmox_virtual_environment_vm" "talos" {
  for_each = local.talos_nodes

  name        = each.key
  description = "Talos Linux ${each.value.role} VM for the mbhome Kubernetes cluster."
  tags        = ["mbhome", "terraform", "talos", "kubernetes", each.value.role]
  node_name   = each.value.proxmox_node
  vm_id       = try(each.value.vm_id, null)
  bios        = var.vm_bios
  machine     = var.vm_machine

  boot_order = coalesce(try(each.value.boot_from_iso, null), var.vm_boot_from_iso) ? [var.iso_interface, var.vm_disk_interface] : [var.vm_disk_interface, var.iso_interface]

  on_boot         = coalesce(try(each.value.on_boot, null), var.vm_on_boot)
  started         = coalesce(try(each.value.started, null), var.vm_started)
  stop_on_destroy = true

  agent {
    enabled = var.vm_agent_enabled

    wait_for_ip {
      disabled = true
    }
  }

  cpu {
    cores = coalesce(try(each.value.cores, null), var.vm_cores)
    type  = var.vm_cpu_type
  }

  memory {
    dedicated = coalesce(try(each.value.memory_mb, null), var.vm_memory_mb)
  }

  efi_disk {
    datastore_id = var.vm_datastore_id
    file_format  = "raw"
    type         = var.vm_efi_disk_type
  }

  cdrom {
    file_id   = proxmox_download_file.talos_iso.id
    interface = var.iso_interface
  }

  disk {
    datastore_id = var.vm_datastore_id
    discard      = "on"
    file_format  = var.vm_disk_format
    interface    = var.vm_disk_interface
    size         = coalesce(try(each.value.disk_gb, null), var.vm_disk_gb)
  }

  network_device {
    bridge      = var.vm_network_bridge
    mac_address = try(each.value.mac_address, null)
    model       = var.vm_network_model
    vlan_id     = try(each.value.vlan_id, null)
  }

  dynamic "network_device" {
    for_each = local.talos_node_storage_bridges[each.key] != null ? [1] : []

    content {
      bridge      = local.talos_node_storage_bridges[each.key]
      mac_address = local.talos_node_storage_mac_addresses[each.key]
      model       = var.vm_network_model
      vlan_id     = local.talos_node_storage_vlan_ids[each.key]
    }
  }

  operating_system {
    type = "l26"
  }
}
