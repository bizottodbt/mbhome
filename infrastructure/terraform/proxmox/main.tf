terraform {
  required_version = ">= 1.6.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.61"
    }
  }

  # Recommended: S3-compatible backend for remote state (e.g., Unraid + MinIO).
  # Uncomment and configure before running terraform init in a team/persistent setup.
  # backend "s3" {
  #   bucket                      = "terraform-state"
  #   key                         = "proxmox/terraform.tfstate"
  #   region                      = "us-east-1"  # required by S3 provider, value unused by MinIO
  #   endpoint                    = "http://10.20.30.48:9000"
  #   skip_credentials_validation = true
  #   skip_metadata_api_check     = true
  #   skip_region_validation      = true
  #   force_path_style            = true
  # }
}

provider "proxmox" {
  endpoint  = var.proxmox_api_url
  api_token = var.proxmox_api_token
  insecure  = false

  ssh {
    agent = true  # uses ssh-agent forwarding for Proxmox SSH tasks
  }
}
