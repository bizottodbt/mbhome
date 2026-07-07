output "vm_name" {
  description = "Smoke VM name."
  value       = proxmox_virtual_environment_vm.smoke.name
}

output "vm_id" {
  description = "Smoke VM ID."
  value       = proxmox_virtual_environment_vm.smoke.vm_id
}

output "node_name" {
  description = "Proxmox node hosting the smoke VM."
  value       = proxmox_virtual_environment_vm.smoke.node_name
}

output "ssh_user" {
  description = "Cloud-init user configured for SSH."
  value       = var.vm_username
}

output "network_bridge" {
  description = "Bridge attached to the smoke VM."
  value       = var.vm_network_bridge
}
