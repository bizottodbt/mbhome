output "ad_vms" {
  description = "Created Microsoft AD DS VM placement, hostname, and desired IP details."
  value = {
    for name, vm in proxmox_virtual_environment_vm.ad : name => {
      vm_id          = vm.vm_id
      hostname       = local.ad_vms[name].hostname
      node_name      = vm.node_name
      ipv4_address   = var.ad_vms[name].ipv4_address
      network_bridge = var.vm_network_bridge
      datastore_id   = var.vm_datastore_id
      template_vm_id = var.template_vm_id
    }
  }
}
