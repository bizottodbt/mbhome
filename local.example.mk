# Copy to local.mk and fill in values for your own network.
# local.mk is git-ignored and automatically included by Makefile.

HOMELAB_GATEWAY := 192.0.2.1
HOMELAB_DNS := 192.0.2.1

PROXMOX_GATEWAY := $(HOMELAB_GATEWAY)
PROXMOX_DNS := $(HOMELAB_DNS)

# Talos/Kubernetes bootstrap helpers. Copy to local.mk and set after the first
# Talos VM receives an IP from DHCP or a reservation.
TALOS_CLUSTER_NAME := mbhome
TALOS_CONTROL_PLANE_IP := 192.0.2.70
# Kubernetes API endpoint embedded in Talos cluster config. Use the HAProxy/LB
# DNS name once it exists, for example k8s-api.example.test.
TALOS_K8S_ENDPOINT := $(TALOS_CONTROL_PLANE_IP)
# Talos machine API endpoint used by talosctl. Keep this as a node IP unless
# you also proxy TCP/50000 through the load balancer.
TALOS_ENDPOINT := $(TALOS_CONTROL_PLANE_IP)
TALOS_NODE := $(TALOS_CONTROL_PLANE_IP)
TALOS_NODE_NAME := mbhome-talos-cp-01
TALOS_CONTROL_PLANE_NODES := mbhome-talos-cp-01 mbhome-talos-cp-02 mbhome-talos-cp-03
TALOS_WORKER_NODES := mbhome-talos-worker-01 mbhome-talos-worker-02 mbhome-talos-worker-03
