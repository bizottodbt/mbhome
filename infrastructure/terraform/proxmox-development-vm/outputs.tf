output "vm" {
  description = "Development VM identity, placement, and network configuration."
  value = {
    name         = proxmox_virtual_environment_vm.development.name
    vm_id        = proxmox_virtual_environment_vm.development.vm_id
    node_name    = proxmox_virtual_environment_vm.development.node_name
    ipv4_address = var.vm_ipv4_address
    fqdn         = "${var.vm_hostname}.${var.vm_dns_domain}"
    ssh_user     = var.vm_username
  }
}
