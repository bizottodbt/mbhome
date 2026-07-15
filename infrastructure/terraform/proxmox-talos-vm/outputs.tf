output "talos_vms" {
  description = "Created Talos VM placement and boot details."
  value = {
    for name, vm in proxmox_virtual_environment_vm.talos : name => {
      name       = vm.name
      vm_id      = vm.vm_id
      node_name  = vm.node_name
      role       = local.talos_nodes[name].role
      iso_file   = proxmox_download_file.talos_iso.id
      disk_store = var.vm_datastore_id
    }
  }
}
