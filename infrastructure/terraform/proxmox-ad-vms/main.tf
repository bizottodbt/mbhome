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
  ad_vms = {
    for name, vm in var.ad_vms : name => merge(vm, {
      hostname = coalesce(vm.hostname, name)
    })
  }

  ad_vm_ipv4 = {
    for name, vm in local.ad_vms : name => {
      address = split("/", vm.ipv4_address)[0]
      prefix  = tonumber(split("/", vm.ipv4_address)[1])
    }
  }
}

resource "proxmox_virtual_environment_file" "ad_meta_data" {
  for_each = local.ad_vms

  content_type = "snippets"
  datastore_id = var.snippet_datastore_id
  node_name    = each.value.node_name

  source_raw {
    data = <<-EOF
    instance-id: ${each.value.hostname}
    local-hostname: ${each.value.hostname}
    EOF

    file_name = "${each.value.hostname}.meta-data.yaml"
  }
}

resource "proxmox_virtual_environment_file" "ad_user_data" {
  for_each = local.ad_vms

  content_type = "snippets"
  datastore_id = var.snippet_datastore_id
  node_name    = each.value.node_name

  source_raw {
    data = <<-EOF
    #ps1_sysnative
    $ErrorActionPreference = "Stop"
    $DesiredHostname = "${each.value.hostname}"
    $DesiredAddress = "${local.ad_vm_ipv4[each.key].address}"
    $DesiredPrefix = ${local.ad_vm_ipv4[each.key].prefix}
    $DesiredGateway = "${coalesce(each.value.ipv4_gateway, "")}"
    $DesiredDnsServers = @(${join(", ", [for server in var.dns_servers : "\"${server}\""])})
    $NeedsReboot = $false

    $Adapter = Get-NetAdapter |
        Where-Object { $_.Status -eq "Up" -and $_.HardwareInterface } |
        Sort-Object -Property InterfaceMetric |
        Select-Object -First 1

    if ($Adapter) {
        $Current = Get-NetIPAddress -InterfaceIndex $Adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
            Where-Object { $_.IPAddress -eq $DesiredAddress -and $_.PrefixLength -eq $DesiredPrefix }

        if (-not $Current) {
            Get-NetIPAddress -InterfaceIndex $Adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
                Where-Object { $_.PrefixOrigin -ne "WellKnown" } |
                Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue

            Get-NetRoute -InterfaceIndex $Adapter.ifIndex -AddressFamily IPv4 -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue |
                Remove-NetRoute -Confirm:$false -ErrorAction SilentlyContinue

            if ($DesiredGateway) {
                New-NetIPAddress -InterfaceIndex $Adapter.ifIndex -IPAddress $DesiredAddress -PrefixLength $DesiredPrefix -DefaultGateway $DesiredGateway
            } else {
                New-NetIPAddress -InterfaceIndex $Adapter.ifIndex -IPAddress $DesiredAddress -PrefixLength $DesiredPrefix
            }
        }

        if ($DesiredDnsServers.Count -gt 0) {
            Set-DnsClientServerAddress -InterfaceIndex $Adapter.ifIndex -ServerAddresses $DesiredDnsServers
        }
    }

    if ($env:COMPUTERNAME -ine $DesiredHostname) {
        Rename-Computer -NewName $DesiredHostname -Force
        $NeedsReboot = $true
    }

    if ($NeedsReboot) {
        Restart-Computer -Force
    }
    EOF

    file_name = "${each.value.hostname}.user-data.ps1"
  }
}

resource "proxmox_virtual_environment_vm" "ad" {
  for_each = local.ad_vms

  name        = each.value.hostname
  description = "Microsoft AD DS Windows Server VM cloned from the Packer template and managed by Terraform."
  tags        = ["mbhome", "terraform", "ad", "windows"]
  node_name   = each.value.node_name
  vm_id       = each.value.vm_id
  bios        = var.vm_bios
  machine     = var.vm_machine

  boot_order = [var.vm_disk_interface]

  on_boot         = each.value.on_boot
  started         = each.value.started
  stop_on_destroy = true

  agent {
    enabled = var.vm_agent_enabled

    wait_for_ip {
      disabled = true
    }
  }

  cpu {
    cores = each.value.cores
    type  = var.vm_cpu_type
  }

  memory {
    dedicated = each.value.memory_mb
  }

  clone {
    vm_id        = var.template_vm_id
    node_name    = var.template_node_name
    datastore_id = var.vm_datastore_id
    full         = var.template_full_clone
    retries      = 3
  }

  disk {
    datastore_id = var.vm_datastore_id
    discard      = "on"
    file_format  = var.vm_disk_format
    interface    = var.vm_disk_interface
    size         = each.value.disk_gb
  }

  initialization {
    datastore_id      = var.cloud_init_datastore_id
    meta_data_file_id = proxmox_virtual_environment_file.ad_meta_data[each.key].id
    user_data_file_id = proxmox_virtual_environment_file.ad_user_data[each.key].id

    dynamic "dns" {
      for_each = length(var.dns_servers) > 0 || var.dns_domain != null ? [1] : []

      content {
        domain  = var.dns_domain
        servers = var.dns_servers
      }
    }

    ip_config {
      ipv4 {
        address = each.value.ipv4_address
        gateway = each.value.ipv4_gateway
      }
    }
  }

  network_device {
    bridge = var.vm_network_bridge
    model  = var.vm_network_model
  }

  operating_system {
    type = var.windows_os_type
  }
}
