output "home_assistant_vm" {
  description = "Home Assistant VM placement and identifiers."
  value = {
    name      = proxmox_virtual_environment_vm.home_assistant.name
    node_name = proxmox_virtual_environment_vm.home_assistant.node_name
    vm_id     = proxmox_virtual_environment_vm.home_assistant.vm_id
    on_boot   = proxmox_virtual_environment_vm.home_assistant.on_boot
    started   = proxmox_virtual_environment_vm.home_assistant.started
  }
}

output "home_assistant_url_hint" {
  description = "Home Assistant frontend URL once DHCP/DNS resolves the VM."
  value       = "http://${var.vm_name}:8123"
}
