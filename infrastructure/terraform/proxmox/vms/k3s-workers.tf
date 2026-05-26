# k3s worker VMs — stateless, reprovisioned via cloud-init on redeploy.
# Disks on Unraid NFS for live migration. Proxmox HA restarts on node failure.
# TODO: implement after Proxmox cluster is operational (Phase 2).

# resource "proxmox_virtual_environment_vm" "k3s_workers" {
#   for_each  = toset(["worker-01", "worker-02", "worker-03"])
#   name      = "k3s-${each.key}"
#   node_name = var.proxmox_node
#
#   cpu {
#     cores = 4
#     type  = "host"
#   }
#
#   memory {
#     dedicated = 8192
#   }
#
#   disk {
#     datastore_id = var.nfs_storage_id
#     size         = 40
#     interface    = "virtio0"
#   }
#
#   network_device {
#     bridge = var.vm_network_bridge
#     model  = "virtio"
#   }
#
#   initialization {
#     datastore_id = "local"
#     ip_config {
#       ipv4 {
#         address = "dhcp"
#       }
#     }
#     user_data_file_id = proxmox_virtual_environment_file.k3s_worker_cloud_init[each.key].id
#   }
# }
