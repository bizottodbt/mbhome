# Shared Proxmox Terraform values used by every stack under infrastructure/terraform/*.
# Copy to proxmox.shared.local.tfvars and keep secrets there.

proxmox_api_url      = "https://192.0.2.51:8006/"
proxmox_api_token    = "CHANGE_ME@pve!mbhome=CHANGE_ME"
proxmox_api_insecure = true

# The API token is for Proxmox API authorization. The BPG provider also uses
# SSH for host-side disk import operations. ~/.ssh/config is not used by the
# provider, so keep the SSH username explicit and load the key with ssh-agent.
proxmox_ssh_agent    = true
proxmox_ssh_username = "root"

vm_network_bridge = "vmbr0"
