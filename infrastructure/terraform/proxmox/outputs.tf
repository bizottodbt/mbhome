# Outputs are populated once VMs are defined in vms/.
# See vms/k3s-controlplane.tf and vms/k3s-workers.tf.

output "k3s_control_plane_ips" {
  description = "IP addresses of k3s control plane VMs"
  value       = { for k, v in proxmox_virtual_environment_vm.k3s_control_plane : k => v.ipv4_addresses }
}

output "k3s_worker_ips" {
  description = "IP addresses of k3s worker VMs"
  value       = { for k, v in proxmox_virtual_environment_vm.k3s_workers : k => v.ipv4_addresses }
}
