# Shared Proxmox Packer values.
# Copy to proxmox.shared.local.pkrvars.hcl and keep secrets there.
#
# Packer requires var files to end in .hcl or .json, so this is separate from
# proxmox.shared.local.tfvars even though most values are the same.

proxmox_api_url      = "https://192.0.2.51:8006/"
proxmox_api_token    = "CHANGE_ME@pve!mbhome=CHANGE_ME"
proxmox_api_insecure = true

vm_network_bridge = "vmbr0"
