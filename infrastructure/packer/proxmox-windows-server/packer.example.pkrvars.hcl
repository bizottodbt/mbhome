proxmox_node = "mbhome-proxmox-01"

template_vm_id = 9300
template_name  = "tpl-windows-server-2025"

windows_iso_file_id  = "proxmox-isos:iso/Windows_Server_2025_Eval.iso"
windows_iso_checksum = "none"
windows_image_name   = "Windows Server 2025 SERVERSTANDARD"

windows_admin_password = "CHANGE_ME_BUILD_ONLY"
winrm_host             = ""
windows_computer_name  = "PACKER-WIN"
windows_timezone       = "W. Europe Standard Time"

vm_datastore_id                    = "proxmox-vms"
packer_iso_datastore_id            = "proxmox-isos"
attach_autounattend_iso            = true
virtio_win_iso_file_id             = "proxmox-isos:iso/virtio-win.iso"
enable_qemu_agent                  = true
enable_cloudbase_init              = false
cloudbase_init_msi_url             = "https://www.cloudbase.it/downloads/CloudbaseInitSetup_Stable_x64.msi"
enable_windows_update              = false
windows_update_strict              = false
disable_insecure_winrm_after_build = false
vm_network_bridge                  = "vmbr0"
vm_mac_address                     = ""
vm_disk_size                       = "60G"
vm_disk_format                     = "qcow2"
vm_cpu_type                        = "x86-64-v2-AES"
vm_scsi_controller                 = "virtio-scsi-pci"
vm_cores                           = 2
vm_memory_mb                       = 4096
