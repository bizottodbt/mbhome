# k3s control plane VMs — persistent, hosted on Proxmox NFS storage (proxmox-vm share).
# Disks are on Unraid NFS to enable live migration between Proxmox nodes.
# TODO: implement after Proxmox cluster is operational (Phase 2).

# resource "proxmox_virtual_environment_vm" "k3s_control_plane" {
#   for_each  = toset(["cp-01"])
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
#     user_data_file_id = proxmox_virtual_environment_file.k3s_cp_cloud_init[each.key].id
#   }
# }
