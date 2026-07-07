proxmox_api_url      = "https://192.0.2.51:8006/"
proxmox_api_token    = "CHANGE_ME@pam!terraform=CHANGE_ME"
proxmox_api_insecure = true

# The API token is for Proxmox API authorization. The provider also uses SSH
# for host-side disk import operations. ~/.ssh/config is not used by the
# provider, so keep the SSH username explicit and load the key with ssh-agent.
proxmox_ssh_agent    = true
proxmox_ssh_username = "root"

proxmox_node = "mbhome-proxmox-01"

# Use local for the first smoke test. For live migration, move vm_datastore_id
# and cloud_init_datastore_id to a shared Proxmox datastore such as proxmox-vms.
image_datastore_id      = "local"
vm_datastore_id         = "local"
cloud_init_datastore_id = "local"
vm_network_bridge       = "vmbr0"

ssh_public_key_file = "~/.ssh/id_ed25519.pub"

vm_name         = "mbhome-smoke-01"
vm_id           = 9100
vm_started      = true
vm_cores        = 1
vm_memory_mb    = 1024
vm_disk_gb      = 8
vm_ipv4_address = "dhcp"
