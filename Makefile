ANSIBLE_DIR       := infrastructure/ansible
KOLLA_DIR         := infrastructure/kolla-ansible
KOLLA_VENV        := $(KOLLA_DIR)/.venv
KOLLA             := $(KOLLA_VENV)/bin/kolla-ansible
KOLLA_OPTS        := --configdir $(KOLLA_DIR) -i $(KOLLA_DIR)/inventory/openstack-vm
# Ensure venv's ansible-playbook is used, not the system homebrew one
KOLLA_ENV         := PATH="$(CURDIR)/$(KOLLA_VENV)/bin:$$PATH"
openstack_release := 2026.1
ipa_kernel_image := ironic-deploy-kernel-$(openstack_release)
ipa_initramfs_image := ironic-deploy-initramfs-$(openstack_release)
ipa_kernel_file := ironic-agent-$(openstack_release).kernel
ipa_initramfs_file := ironic-agent-$(openstack_release).initramfs

-include local.mk

ANSIBLE_INVENTORY_LOCAL := $(if $(wildcard $(ANSIBLE_DIR)/inventory/hosts.local.yaml),-i inventory/hosts.local.yaml,)
ANSIBLE_INVENTORY_ROOT  := -i $(ANSIBLE_DIR)/inventory/hosts.yaml $(if $(wildcard $(ANSIBLE_DIR)/inventory/hosts.local.yaml),-i $(ANSIBLE_DIR)/inventory/hosts.local.yaml,)
ANSIBLE_INVENTORY       := -i inventory/hosts.yaml $(ANSIBLE_INVENTORY_LOCAL)

DIB_BASE := infrastructure/dib
PROXMOX_TF_SHARED_DIR := infrastructure/terraform
PROXMOX_TF_SHARED_VARS := $(if $(wildcard $(PROXMOX_TF_SHARED_DIR)/proxmox.shared.tfvars),-var-file=../proxmox.shared.tfvars,) $(if $(wildcard $(PROXMOX_TF_SHARED_DIR)/proxmox.shared.local.tfvars),-var-file=../proxmox.shared.local.tfvars,)
PROXMOX_SMOKE_TF_DIR := infrastructure/terraform/proxmox-smoke-vm
PROXMOX_SMOKE_TF_VARS := $(PROXMOX_TF_SHARED_VARS) $(if $(wildcard $(PROXMOX_SMOKE_TF_DIR)/terraform.tfvars),-var-file=terraform.tfvars,) $(if $(wildcard $(PROXMOX_SMOKE_TF_DIR)/terraform.local.tfvars),-var-file=terraform.local.tfvars,)
PROXMOX_TALOS_TF_DIR := infrastructure/terraform/proxmox-talos-vm
PROXMOX_TALOS_TF_VARS := $(PROXMOX_TF_SHARED_VARS) $(if $(wildcard $(PROXMOX_TALOS_TF_DIR)/terraform.tfvars),-var-file=terraform.tfvars,) $(if $(wildcard $(PROXMOX_TALOS_TF_DIR)/terraform.local.tfvars),-var-file=terraform.local.tfvars,)
PROXMOX_AD_TF_DIR := infrastructure/terraform/proxmox-ad-vms
PROXMOX_AD_TF_VARS := $(PROXMOX_TF_SHARED_VARS) $(if $(wildcard $(PROXMOX_AD_TF_DIR)/terraform.tfvars),-var-file=terraform.tfvars,) $(if $(wildcard $(PROXMOX_AD_TF_DIR)/terraform.local.tfvars),-var-file=terraform.local.tfvars,)
PROXMOX_WINDOWS_PACKER_DIR := infrastructure/packer/proxmox-windows-server
PROXMOX_WINDOWS_PACKER_SHARED_VARS := $(if $(wildcard $(PROXMOX_TF_SHARED_DIR)/proxmox.shared.pkrvars.hcl),-var-file=../../terraform/proxmox.shared.pkrvars.hcl,) $(if $(wildcard $(PROXMOX_TF_SHARED_DIR)/proxmox.shared.local.pkrvars.hcl),-var-file=../../terraform/proxmox.shared.local.pkrvars.hcl,)
PROXMOX_WINDOWS_PACKER_VARS := $(PROXMOX_WINDOWS_PACKER_SHARED_VARS) $(if $(wildcard $(PROXMOX_WINDOWS_PACKER_DIR)/packer.pkrvars.hcl),-var-file=packer.pkrvars.hcl,) $(if $(wildcard $(PROXMOX_WINDOWS_PACKER_DIR)/packer.local.pkrvars.hcl),-var-file=packer.local.pkrvars.hcl,)
TALOS_CLUSTER_DIR := infrastructure/talos/clusters/mbhome
TALOS_CLUSTER_NAME ?= mbhome
TALOS_CONTROL_PLANE_IP ?=
TALOS_K8S_ENDPOINT ?= $(TALOS_CONTROL_PLANE_IP)
TALOS_ENDPOINT ?= $(TALOS_CONTROL_PLANE_IP)
TALOS_NODE ?= $(TALOS_CONTROL_PLANE_IP)
TALOS_NODE_NAME ?= mbhome-talos-cp-01
TALOS_CONTROL_PLANE_NODES ?= mbhome-talos-cp-01 mbhome-talos-cp-02 mbhome-talos-cp-03
TALOS_WORKER_NODES ?= mbhome-talos-worker-01 mbhome-talos-worker-02 mbhome-talos-worker-03
TALOS_MACHINE_CONFIG ?= $(TALOS_CLUSTER_DIR)/nodes/$(TALOS_NODE_NAME).yaml
TALOSCONFIG := $(CURDIR)/$(TALOS_CLUSTER_DIR)/talosconfig
TALOS_UPGRADE_VERSION ?= v1.13.6
TALOS_UPGRADE_IMAGE ?= ghcr.io/siderolabs/installer:$(TALOS_UPGRADE_VERSION)
TALOS_UPGRADE_DRAIN ?= true
KUBECONFIG_FILE ?= $(CURDIR)/$(TALOS_CLUSTER_DIR)/kubeconfig
CILIUM_DIR := infrastructure/kubernetes/cilium
CILIUM_VERSION ?= 1.19.5

.PHONY: help ansible-collections openstack-vm openstack-stack-stop openstack-stack-start openstack-stack-status openstack-setup openstack-versions ironic-set-deploy-images ironic-deploy-proxmox ironic-build-image proxmox-baseline proxmox-cluster windows-dc-baseline windows-ad-forest windows-ad-replica windows-ad-directory-check windows-ad-directory-apply windows-ad-dns-check windows-ad-dns-apply proxmox-smoke-vm-init proxmox-smoke-vm-plan proxmox-smoke-vm-apply proxmox-smoke-vm-destroy proxmox-talos-vm-init proxmox-talos-vm-plan proxmox-talos-vm-apply proxmox-talos-vm-destroy talos-inspect talos-gen-secrets talos-gen-config talos-apply-insecure talos-apply talos-apply-controlplane-insecure talos-apply-controlplane talos-bootstrap talos-kubeconfig talos-health talos-version talos-upgrade-plan talos-upgrade cilium-helm-repo cilium-install cilium-status cilium-uninstall proxmox-ad-vms-init proxmox-ad-vms-plan proxmox-ad-vms-apply proxmox-ad-vms-destroy proxmox-windows-template-init proxmox-windows-template-answer-iso proxmox-windows-template-validate proxmox-windows-template-build bmc-baseline kolla-genpwd kolla-bootstrap kolla-prechecks kolla-deploy kolla-post-deploy kolla-reconfigure kolla-destroy kolla-ipa-images

help: ## Show available targets
	@grep -hE '^[a-zA-Z_-]+:.*##' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*##"}; {printf "  %-20s %s\n", $$1, $$2}'

ansible-collections: ## Install Ansible collections used by infrastructure playbooks
	cd $(ANSIBLE_DIR) && ansible-galaxy collection install -r collections/requirements.yaml

openstack-vm: ## Deploy (or start) the openstack VM on Unraid
	cd $(ANSIBLE_DIR) && ansible-playbook $(ANSIBLE_INVENTORY) playbooks/openstack-vm.yaml

openstack-stack-stop: ## Stop Kolla/OpenStack systemd units and Docker for maintenance
	ssh openstack 'set -e; \
		units=$$(systemctl list-units "kolla-*-container.service" --no-legend --plain | awk "{print \$$1}"); \
		if [ -n "$$units" ]; then sudo systemctl stop $$units; fi; \
		sudo systemctl stop docker.socket || true; \
		sudo systemctl stop docker || true; \
		sudo systemctl stop containerd || true'

openstack-stack-start: ## Start Docker and all Kolla/OpenStack systemd units after maintenance
	ssh openstack 'set -e; \
		sudo systemctl daemon-reload; \
		sudo systemctl start containerd || true; \
		sudo systemctl start docker; \
		units=$$(systemctl list-unit-files "kolla-*-container.service" --no-legend | awk "{print \$$1}"); \
		if [ -n "$$units" ]; then sudo systemctl start $$units; fi'

openstack-stack-status: ## Show OpenStack VM mounts and Kolla container health
	ssh openstack 'set -e; \
		echo "==> Systemd"; \
		systemctl is-active docker docker.socket containerd || true; \
		echo ""; \
		echo "==> Kolla units"; \
		systemctl list-units "kolla-*-container.service" --no-legend --plain | awk "{print \$$1, \$$3, \$$4}" | sort; \
		echo ""; \
		echo "==> Mounts"; \
		for target in /var/lib/openstack-data /var/lib/docker/volumes /var/lib/glance/images; do sudo findmnt -T "$$target" || true; done; \
		echo ""; \
		echo "==> Disk usage"; \
		sudo df -h / /var/lib/openstack-data /var/lib/docker/volumes /var/lib/glance/images; \
		echo ""; \
		echo "==> Containers"; \
		if systemctl is-active --quiet docker; then sudo docker ps --format "table {{.Names}}\t{{.Status}}" | sort; else echo "Docker is stopped"; fi'

openstack-setup: ## Upload IPA images to Glance and create Ironic provisioning/cleaning networks
	$(KOLLA_VENV)/bin/ansible-galaxy collection install openstack.cloud --upgrade
	env -u OS_SYSTEM_SCOPE \
		OPENSTACK_RELEASE=$(openstack_release) \
		OS_PASSWORD=$$(grep keystone_admin_password $(KOLLA_DIR)/passwords.yml | awk '{print $$2}') \
		$(KOLLA_ENV) $(KOLLA_VENV)/bin/ansible-playbook \
		$(ANSIBLE_INVENTORY_ROOT) \
		$(ANSIBLE_DIR)/playbooks/openstack-setup.yaml

openstack-versions: ## Print the OpenStack service version inside every running Kolla container
	@ssh openstack 'sudo docker ps --format "{{.Names}}" | sort | while read c; do \
		ver=$$(sudo docker exec "$$c" /var/lib/openstack/bin/pip list --format columns 2>/dev/null \
			| awk "NR>2" \
			| grep -iE "^(keystone|glance[^-]|neutron[^-]|ironic[^-]|nova[^-]|cinder[^-]|heat[^-]|horizon|placement|ironic-python-agent) " \
			| awk "{print \$$1\" \"\$$2}" | head -1); \
		[ -n "$$ver" ] && printf "%-45s %s\\n" "$$c" "$$ver"; \
	done'

ironic-set-deploy-images: ## Set deploy_kernel + deploy_ramdisk on an Ironic node (usage: make ironic-set-deploy-images NODE=mbhome-proxmox-01)
	@test -n "$(NODE)" || (echo "Usage: make ironic-set-deploy-images NODE=<node-name>"; exit 1)
	@set -e; \
	source $(KOLLA_DIR)/admin-openrc.sh; \
	KERNEL_ID=$$(env -u OS_SYSTEM_SCOPE $(KOLLA_VENV)/bin/openstack image show $(ipa_kernel_image) -c id -f value); \
	RAMDISK_ID=$$(env -u OS_SYSTEM_SCOPE $(KOLLA_VENV)/bin/openstack image show $(ipa_initramfs_image) -c id -f value); \
	echo "Setting deploy_kernel=$$KERNEL_ID deploy_ramdisk=$$RAMDISK_ID on $(NODE)"; \
	$(KOLLA_VENV)/bin/openstack baremetal node set $(NODE) \
		--driver-info deploy_kernel=$$KERNEL_ID \
		--driver-info deploy_ramdisk=$$RAMDISK_ID

PROXMOX_PREFIX ?= 24
PROXMOX_GATEWAY ?= 192.0.2.1
PROXMOX_DNS ?= $(PROXMOX_GATEWAY)
PROXMOX_MAC ?=
ANSIBLE_HOST ?= $(or $(PROXMOX_IP),$(NODE))

ironic-deploy-proxmox: ## Deploy Proxmox, wait for SSH, then run the Proxmox baseline (usage: make ironic-deploy-proxmox NODE=mbhome-proxmox-01 PROXMOX_IP=192.0.2.51)
	@test -n "$(NODE)" || (echo "Usage: make ironic-deploy-proxmox NODE=<node-name> [PROXMOX_IP=<static-ip>] [ANSIBLE_HOST=<ip-or-dns>]"; exit 1)
	@test -n "$(ANSIBLE_HOST)" || (echo "Usage: make ironic-deploy-proxmox NODE=<node-name> [PROXMOX_IP=<static-ip>] [ANSIBLE_HOST=<ip-or-dns>]"; exit 1)
	NODE="$(NODE)" \
	ANSIBLE_HOST="$(ANSIBLE_HOST)" \
	PROXMOX_IP="$(PROXMOX_IP)" \
	PROXMOX_PREFIX="$(PROXMOX_PREFIX)" \
	PROXMOX_GATEWAY="$(PROXMOX_GATEWAY)" \
	PROXMOX_DNS="$(PROXMOX_DNS)" \
	PROXMOX_MAC="$(PROXMOX_MAC)" \
	KOLLA_DIR="$(CURDIR)/$(KOLLA_DIR)" \
	KOLLA_VENV="$(CURDIR)/$(KOLLA_VENV)" \
	ANSIBLE_DIR="$(CURDIR)/$(ANSIBLE_DIR)" \
	./infrastructure/scripts/ironic-deploy-proxmox.sh

proxmox-baseline: ## Configure deployed Proxmox nodes (usage: make proxmox-baseline LIMIT=mbhome-proxmox-01)
	cd $(ANSIBLE_DIR) && ansible-playbook $(ANSIBLE_INVENTORY) playbooks/proxmox-baseline.yaml $(if $(LIMIT),--limit $(LIMIT),)

proxmox-cluster: ## Create/join the Proxmox cluster (usage: make proxmox-cluster LIMIT='mbhome-proxmox-01:mbhome-proxmox-02')
	cd $(ANSIBLE_DIR) && ansible-playbook $(ANSIBLE_INVENTORY) playbooks/proxmox-cluster.yaml $(if $(LIMIT),--limit $(LIMIT),)

windows-dc-baseline: ## Set hostname and static IPv4 on Windows DC VMs (usage: make windows-dc-baseline LIMIT=mbhome-ad-01)
	cd $(ANSIBLE_DIR) && OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES ANSIBLE_FORKS=1 ANSIBLE_LOCAL_TEMP=/private/tmp/ansible-local TMPDIR=/private/tmp ansible-playbook $(ANSIBLE_INVENTORY) playbooks/windows-dc-baseline.yaml $(if $(LIMIT),--limit $(LIMIT),)

windows-ad-forest: ## Create the AD DS forest on the primary Windows DC
	cd $(ANSIBLE_DIR) && OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES ANSIBLE_FORKS=1 ANSIBLE_LOCAL_TEMP=/private/tmp/ansible-local TMPDIR=/private/tmp ansible-playbook $(ANSIBLE_INVENTORY) playbooks/windows-ad-forest.yaml $(if $(LIMIT),--limit $(LIMIT),)

windows-ad-replica: ## Promote additional Windows DC replicas
	cd $(ANSIBLE_DIR) && OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES ANSIBLE_FORKS=1 ANSIBLE_LOCAL_TEMP=/private/tmp/ansible-local TMPDIR=/private/tmp ansible-playbook $(ANSIBLE_INVENTORY) playbooks/windows-ad-replica.yaml $(if $(LIMIT),--limit $(LIMIT),)

windows-ad-directory-check: ## Preview declarative AD users/groups/OUs changes
	cd $(ANSIBLE_DIR) && OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES ANSIBLE_FORKS=1 ANSIBLE_LOCAL_TEMP=/private/tmp/ansible-local TMPDIR=/private/tmp ansible-playbook $(ANSIBLE_INVENTORY) playbooks/windows-ad-directory.yaml -e ad_directory_check=true $(if $(LIMIT),--limit $(LIMIT),)

windows-ad-directory-apply: ## Apply declarative AD users/groups/OUs changes
	cd $(ANSIBLE_DIR) && OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES ANSIBLE_FORKS=1 ANSIBLE_LOCAL_TEMP=/private/tmp/ansible-local TMPDIR=/private/tmp ansible-playbook $(ANSIBLE_INVENTORY) playbooks/windows-ad-directory.yaml $(if $(LIMIT),--limit $(LIMIT),)

windows-ad-dns-check: ## Preview declarative AD DNS record changes
	cd $(ANSIBLE_DIR) && OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES ANSIBLE_FORKS=1 ANSIBLE_LOCAL_TEMP=/private/tmp/ansible-local TMPDIR=/private/tmp ansible-playbook $(ANSIBLE_INVENTORY) playbooks/windows-ad-dns.yaml -e ad_dns_check=true $(if $(LIMIT),--limit $(LIMIT),)

windows-ad-dns-apply: ## Apply declarative AD DNS record changes
	cd $(ANSIBLE_DIR) && OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES ANSIBLE_FORKS=1 ANSIBLE_LOCAL_TEMP=/private/tmp/ansible-local TMPDIR=/private/tmp ansible-playbook $(ANSIBLE_INVENTORY) playbooks/windows-ad-dns.yaml $(if $(LIMIT),--limit $(LIMIT),)

proxmox-smoke-vm-init: ## Initialize Terraform for the disposable Proxmox smoke VM
	cd $(PROXMOX_SMOKE_TF_DIR) && terraform init

proxmox-smoke-vm-plan: ## Plan the disposable Proxmox smoke VM
	cd $(PROXMOX_SMOKE_TF_DIR) && terraform plan $(PROXMOX_SMOKE_TF_VARS)

proxmox-smoke-vm-apply: ## Create/update the disposable Proxmox smoke VM
	cd $(PROXMOX_SMOKE_TF_DIR) && terraform apply $(PROXMOX_SMOKE_TF_VARS)

proxmox-smoke-vm-destroy: ## Destroy the disposable Proxmox smoke VM
	cd $(PROXMOX_SMOKE_TF_DIR) && terraform destroy $(PROXMOX_SMOKE_TF_VARS)

proxmox-talos-vm-init: ## Initialize Terraform for the first Talos Kubernetes VM
	cd $(PROXMOX_TALOS_TF_DIR) && terraform init

proxmox-talos-vm-plan: ## Plan the first Talos Kubernetes VM
	cd $(PROXMOX_TALOS_TF_DIR) && terraform plan $(PROXMOX_TALOS_TF_VARS)

proxmox-talos-vm-apply: ## Create/update the first Talos Kubernetes VM
	cd $(PROXMOX_TALOS_TF_DIR) && terraform apply $(PROXMOX_TALOS_TF_VARS)

proxmox-talos-vm-destroy: ## Destroy the first Talos Kubernetes VM
	cd $(PROXMOX_TALOS_TF_DIR) && terraform destroy $(PROXMOX_TALOS_TF_VARS)

talos-inspect: ## Inspect booted Talos ISO disks and network links before applying config
	@test -n "$(TALOS_NODE)" || (echo "Set TALOS_NODE=<talos-node-ip>"; exit 1)
	talosctl get disks --insecure --nodes "$(TALOS_NODE)"
	talosctl get links --insecure --nodes "$(TALOS_NODE)"

talos-gen-secrets: ## Generate ignored Talos cluster secrets
	@test -d "$(TALOS_CLUSTER_DIR)" || (echo "Missing $(TALOS_CLUSTER_DIR)"; exit 1)
	@test ! -f "$(TALOS_CLUSTER_DIR)/secrets.yaml" || (echo "$(TALOS_CLUSTER_DIR)/secrets.yaml already exists; move it away before regenerating"; exit 1)
	talosctl gen secrets -o "$(TALOS_CLUSTER_DIR)/secrets.yaml"

talos-gen-config: ## Generate ignored Talos controlplane/worker configs from patches
	@test -n "$(TALOS_K8S_ENDPOINT)" || (echo "Set TALOS_K8S_ENDPOINT=<kubernetes-api-dns-or-ip>"; exit 1)
	@test -f "$(TALOS_CLUSTER_DIR)/secrets.yaml" || (echo "Run make talos-gen-secrets first"; exit 1)
	talosctl gen config "$(TALOS_CLUSTER_NAME)" "https://$(TALOS_K8S_ENDPOINT):6443" \
		--with-secrets "$(TALOS_CLUSTER_DIR)/secrets.yaml" \
		--output-dir "$(TALOS_CLUSTER_DIR)" \
		--force \
		--config-patch-control-plane @"$(TALOS_CLUSTER_DIR)/patches/controlplane.yaml" \
		--config-patch-worker @"$(TALOS_CLUSTER_DIR)/patches/worker.yaml"
	@mkdir -p "$(TALOS_CLUSTER_DIR)/nodes"
	@for node in $(TALOS_CONTROL_PLANE_NODES); do \
		test -f "$(TALOS_CLUSTER_DIR)/patches/nodes/$$node.yaml" || (echo "Missing $(TALOS_CLUSTER_DIR)/patches/nodes/$$node.yaml"; exit 1); \
		talosctl machineconfig patch "$(TALOS_CLUSTER_DIR)/controlplane.yaml" \
			--patch @"$(TALOS_CLUSTER_DIR)/patches/nodes/$$node.yaml" \
			--output "$(TALOS_CLUSTER_DIR)/nodes/$$node.yaml"; \
	done
	@for node in $(TALOS_WORKER_NODES); do \
		test -f "$(TALOS_CLUSTER_DIR)/patches/nodes/$$node.yaml" || (echo "Missing $(TALOS_CLUSTER_DIR)/patches/nodes/$$node.yaml"; exit 1); \
		talosctl machineconfig patch "$(TALOS_CLUSTER_DIR)/worker.yaml" \
			--patch @"$(TALOS_CLUSTER_DIR)/patches/nodes/$$node.yaml" \
			--output "$(TALOS_CLUSTER_DIR)/nodes/$$node.yaml"; \
	done

talos-apply-insecure: ## Apply a generated Talos node config to an unconfigured ISO-booted VM
	@test -n "$(TALOS_NODE)" || (echo "Set TALOS_NODE=<talos-node-ip>"; exit 1)
	@test -f "$(TALOS_MACHINE_CONFIG)" || (echo "Run make talos-gen-config first or set TALOS_NODE_NAME=<node-name>"; exit 1)
	talosctl apply-config --insecure --nodes "$(TALOS_NODE)" --file "$(TALOS_MACHINE_CONFIG)"

talos-apply-controlplane-insecure: talos-apply-insecure

talos-apply: ## Reapply a generated Talos node config using generated talosconfig
	@test -n "$(TALOS_NODE)" || (echo "Set TALOS_NODE=<talos-node-ip>"; exit 1)
	@test -n "$(TALOS_ENDPOINT)" || (echo "Set TALOS_ENDPOINT=<control-plane-endpoint-ip-or-dns>"; exit 1)
	@test -f "$(TALOS_MACHINE_CONFIG)" || (echo "Run make talos-gen-config first or set TALOS_NODE_NAME=<node-name>"; exit 1)
	@test -f "$(TALOS_CLUSTER_DIR)/talosconfig" || (echo "Run make talos-gen-config first"; exit 1)
	TALOSCONFIG="$(TALOSCONFIG)" talosctl apply-config --nodes "$(TALOS_NODE)" --endpoints "$(TALOS_ENDPOINT)" --file "$(TALOS_MACHINE_CONFIG)"

talos-apply-controlplane: talos-apply

talos-bootstrap: ## Bootstrap Kubernetes on the first Talos control-plane node
	@test -n "$(TALOS_NODE)" || (echo "Set TALOS_NODE=<talos-node-ip>"; exit 1)
	@test -n "$(TALOS_ENDPOINT)" || (echo "Set TALOS_ENDPOINT=<control-plane-endpoint-ip-or-dns>"; exit 1)
	@test -f "$(TALOS_CLUSTER_DIR)/talosconfig" || (echo "Run make talos-gen-config first"; exit 1)
	TALOSCONFIG="$(TALOSCONFIG)" talosctl config endpoint "$(TALOS_ENDPOINT)"
	TALOSCONFIG="$(TALOSCONFIG)" talosctl config node "$(TALOS_NODE)"
	TALOSCONFIG="$(TALOSCONFIG)" talosctl bootstrap --nodes "$(TALOS_NODE)" --endpoints "$(TALOS_ENDPOINT)"

talos-kubeconfig: ## Fetch Kubernetes kubeconfig from Talos
	@test -n "$(TALOS_NODE)" || (echo "Set TALOS_NODE=<talos-node-ip>"; exit 1)
	@test -n "$(TALOS_ENDPOINT)" || (echo "Set TALOS_ENDPOINT=<control-plane-endpoint-ip-or-dns>"; exit 1)
	@test -f "$(TALOS_CLUSTER_DIR)/talosconfig" || (echo "Run make talos-gen-config first"; exit 1)
	TALOSCONFIG="$(TALOSCONFIG)" talosctl kubeconfig "$(TALOS_CLUSTER_DIR)" --nodes "$(TALOS_NODE)" --endpoints "$(TALOS_ENDPOINT)"

talos-health: ## Check Talos and Kubernetes control-plane health
	@test -n "$(TALOS_NODE)" || (echo "Set TALOS_NODE=<talos-node-ip>"; exit 1)
	@test -n "$(TALOS_ENDPOINT)" || (echo "Set TALOS_ENDPOINT=<control-plane-endpoint-ip-or-dns>"; exit 1)
	@test -f "$(TALOS_CLUSTER_DIR)/talosconfig" || (echo "Run make talos-gen-config first"; exit 1)
	TALOSCONFIG="$(TALOSCONFIG)" talosctl health --nodes "$(TALOS_NODE)" --endpoints "$(TALOS_ENDPOINT)"

talos-version: ## Show Talos client and node versions
	@test -n "$(TALOS_NODE)" || (echo "Set TALOS_NODE=<talos-node-ip>"; exit 1)
	@test -n "$(TALOS_ENDPOINT)" || (echo "Set TALOS_ENDPOINT=<control-plane-endpoint-ip-or-dns>"; exit 1)
	@test -f "$(TALOS_CLUSTER_DIR)/talosconfig" || (echo "Run make talos-gen-config first"; exit 1)
	TALOSCONFIG="$(TALOSCONFIG)" talosctl version --nodes "$(TALOS_NODE)" --endpoints "$(TALOS_ENDPOINT)"

talos-upgrade-plan: ## Show the Talos upgrade command for the selected node
	@test -n "$(TALOS_NODE)" || (echo "Set TALOS_NODE=<talos-node-ip>"; exit 1)
	@test -n "$(TALOS_ENDPOINT)" || (echo "Set TALOS_ENDPOINT=<control-plane-endpoint-ip-or-dns>"; exit 1)
	@echo 'TALOSCONFIG="$(TALOSCONFIG)" talosctl upgrade --nodes "$(TALOS_NODE)" --endpoints "$(TALOS_ENDPOINT)" --image "$(TALOS_UPGRADE_IMAGE)" --drain=$(TALOS_UPGRADE_DRAIN) --wait'

talos-upgrade: ## Upgrade Talos on the selected node (usage: make talos-upgrade TALOS_NODE=10.20.30.70 TALOS_UPGRADE_VERSION=v1.13.6)
	@test -n "$(TALOS_NODE)" || (echo "Set TALOS_NODE=<talos-node-ip>"; exit 1)
	@test -n "$(TALOS_ENDPOINT)" || (echo "Set TALOS_ENDPOINT=<control-plane-endpoint-ip-or-dns>"; exit 1)
	@test -f "$(TALOS_CLUSTER_DIR)/talosconfig" || (echo "Run make talos-gen-config first"; exit 1)
	TALOSCONFIG="$(TALOSCONFIG)" talosctl upgrade --nodes "$(TALOS_NODE)" --endpoints "$(TALOS_ENDPOINT)" --image "$(TALOS_UPGRADE_IMAGE)" --drain=$(TALOS_UPGRADE_DRAIN) --wait

cilium-helm-repo: ## Add/update the Cilium Helm repository
	helm repo add cilium https://helm.cilium.io
	helm repo update cilium

cilium-install: ## Install or upgrade Cilium on the Talos Kubernetes cluster
	@test -f "$(KUBECONFIG_FILE)" || (echo "Run make talos-kubeconfig first"; exit 1)
	@test -f "$(CILIUM_DIR)/values.yaml" || (echo "Missing $(CILIUM_DIR)/values.yaml"; exit 1)
	helm upgrade --install cilium cilium/cilium \
		--version "$(CILIUM_VERSION)" \
		--namespace kube-system \
		--kubeconfig "$(KUBECONFIG_FILE)" \
		--values "$(CILIUM_DIR)/values.yaml"

cilium-status: ## Show Cilium pods and Kubernetes node readiness
	@test -f "$(KUBECONFIG_FILE)" || (echo "Run make talos-kubeconfig first"; exit 1)
	kubectl --kubeconfig "$(KUBECONFIG_FILE)" -n kube-system get pods -l k8s-app=cilium -o wide
	kubectl --kubeconfig "$(KUBECONFIG_FILE)" -n kube-system get pods -l name=cilium-operator -o wide
	kubectl --kubeconfig "$(KUBECONFIG_FILE)" get nodes -o wide

cilium-uninstall: ## Remove Cilium from the cluster
	@test -f "$(KUBECONFIG_FILE)" || (echo "Run make talos-kubeconfig first"; exit 1)
	helm uninstall cilium --namespace kube-system --kubeconfig "$(KUBECONFIG_FILE)"

proxmox-ad-vms-init: ## Initialize Terraform for AD/domain-controller VM shells
	cd $(PROXMOX_AD_TF_DIR) && terraform init

proxmox-ad-vms-plan: ## Plan AD/domain-controller VM shells
	cd $(PROXMOX_AD_TF_DIR) && terraform plan $(PROXMOX_AD_TF_VARS)

proxmox-ad-vms-apply: ## Create/update AD/domain-controller VM shells
	cd $(PROXMOX_AD_TF_DIR) && terraform apply $(PROXMOX_AD_TF_VARS)

proxmox-ad-vms-destroy: ## Destroy AD/domain-controller VM shells
	cd $(PROXMOX_AD_TF_DIR) && terraform destroy $(PROXMOX_AD_TF_VARS)

proxmox-windows-template-init: ## Initialize Packer for the Windows Server Proxmox template
	cd $(PROXMOX_WINDOWS_PACKER_DIR) && packer init .

proxmox-windows-template-answer-iso: ## Generate the local Autounattend ISO used by the Windows Server Packer build
	cd $(PROXMOX_WINDOWS_PACKER_DIR) && ./render-autounattend-iso.sh ../../terraform/proxmox.shared.local.pkrvars.hcl packer.local.pkrvars.hcl

proxmox-windows-template-validate: proxmox-windows-template-answer-iso ## Validate the Windows Server Packer template
	cd $(PROXMOX_WINDOWS_PACKER_DIR) && packer validate $(PROXMOX_WINDOWS_PACKER_VARS) .

proxmox-windows-template-build: proxmox-windows-template-answer-iso ## Build a Windows Server Proxmox template with Packer
	cd $(PROXMOX_WINDOWS_PACKER_DIR) && packer build $(PROXMOX_WINDOWS_PACKER_VARS) .

bmc-baseline: ## Configure BMC users and board-specific settings (usage: make bmc-baseline LIMIT=mbhome-proxmox-01-bmc)
	cd $(ANSIBLE_DIR) && ansible-playbook $(ANSIBLE_INVENTORY) playbooks/bmc-baseline.yaml $(if $(LIMIT),--limit $(LIMIT),)

# Internal: create/update the venv (not listed in help)
_kolla-venv:
	python3.12 -m venv $(KOLLA_VENV)
	$(KOLLA_VENV)/bin/pip install --upgrade pip
	$(KOLLA_VENV)/bin/pip install -r $(KOLLA_DIR)/requirements.txt
	$(KOLLA_ENV) $(KOLLA_VENV)/bin/ansible-galaxy collection install \
		git+https://opendev.org/openstack/ansible-collection-kolla,stable/2026.1 \
		--force

kolla-genpwd: _kolla-venv ## Create venv (if needed) and generate Kolla passwords
	@if ! grep -qE '^[a-zA-Z_]' $(KOLLA_DIR)/passwords.yml 2>/dev/null; then \
		cp $(KOLLA_VENV)/share/kolla-ansible/etc_examples/kolla/passwords.yml $(KOLLA_DIR)/passwords.yml; \
	fi
	$(KOLLA_VENV)/bin/kolla-genpwd --passwords $(KOLLA_DIR)/passwords.yml

kolla-bootstrap: _kolla-venv ## Install Docker + Kolla deps on the openstack VM
	$(KOLLA_ENV) $(KOLLA) bootstrap-servers $(KOLLA_OPTS)

kolla-prechecks: _kolla-venv ## Validate Kolla-Ansible config before deploying
	$(KOLLA_ENV) $(KOLLA) prechecks $(KOLLA_OPTS) --use-test-images

kolla-deploy: _kolla-venv ## Deploy OpenStack services onto the openstack VM
	$(KOLLA_ENV) $(KOLLA) deploy $(KOLLA_OPTS)

kolla-post-deploy: _kolla-venv ## Generate admin openrc after a successful deploy
	$(KOLLA_ENV) $(KOLLA) post-deploy $(KOLLA_OPTS)
	@printf '# System-scoped credentials for Ironic baremetal commands.\n# Source admin-openrc.sh first, then this file.\nunset OS_PROJECT_NAME OS_PROJECT_DOMAIN_NAME OS_TENANT_NAME\nexport OS_SYSTEM_SCOPE=all\n' > $(KOLLA_DIR)/admin-openrc-system.sh
	@echo "Admin credentials written to $(KOLLA_DIR)/admin-openrc.sh"
	@echo "Source with: source $(KOLLA_DIR)/admin-openrc.sh"

kolla-reconfigure: _kolla-venv ## Push config changes to running containers (use TAGS=ironic to limit scope)
	$(KOLLA_ENV) $(KOLLA) reconfigure $(KOLLA_OPTS) $(if $(TAGS),--tags $(TAGS),)
	@# Kolla regenerates ipa.ipxe on reconfigure, overwriting our ipa-api-url addition.
	@# Redeploy the repo-managed version to the httpboot volume.
	ssh openstack 'sudo cp /dev/stdin /var/lib/docker/volumes/ironic/_data/httpboot/ipa.ipxe' \
		< $(KOLLA_DIR)/config/ironic/ipa.ipxe

kolla-destroy: _kolla-venv ## WARNING: destroy all OpenStack containers and volumes on the VM
	$(KOLLA_ENV) $(KOLLA) destroy --yes-i-really-really-mean-it $(KOLLA_OPTS)

kolla-ipa-images: ## Build IPA kernel + initramfs on the OpenStack VM, pinned to the conductor's IPA version
	@echo "==> Building IPA images on OpenStack VM (OpenStack $(openstack_release), ~20-40 min)..."
	scp $(KOLLA_DIR)/build-ipa.sh openstack:/tmp/build-ipa.sh
	ssh openstack "bash /tmp/build-ipa.sh /tmp/ipa-build $(openstack_release)"
	@echo "==> Copying built images locally for Glance upload..."
	mkdir -p $(KOLLA_DIR)/config/ironic
	scp openstack:/tmp/ipa-build/$(ipa_kernel_file)    $(KOLLA_DIR)/config/ironic/$(ipa_kernel_file)
	scp openstack:/tmp/ipa-build/$(ipa_initramfs_file) $(KOLLA_DIR)/config/ironic/$(ipa_initramfs_file)
	@echo "==> Images ready: $(ipa_kernel_file), $(ipa_initramfs_file)"
	@echo "==> Run 'make openstack-setup' to upload to Glance as $(ipa_kernel_image) and $(ipa_initramfs_image)."

SSH_KEY_FILE ?= ~/.ssh/id_ed25519.pub
DIB_ROOT_PASSWORD ?= ironic
DIB_IMAGE_DIR ?= /var/lib/openstack-data/dib

ironic-build-image: ## Build a raw OS image via DIB and upload to Glance (usage: make ironic-build-image OS=proxmox [SSH_KEY_FILE=~/.ssh/other.pub])
	@test -n "$(OS)" || (echo "Usage: make ironic-build-image OS=<os>  (e.g. OS=proxmox)"; exit 1)
	@test -d "$(DIB_BASE)/$(OS)" || (echo "No DIB config found at $(DIB_BASE)/$(OS)"; exit 1)
	@test -f $(SSH_KEY_FILE) || (echo "SSH key not found: $(SSH_KEY_FILE)"; exit 1)
	@echo "==> Copying DIB elements for '$(OS)' to OpenStack VM..."
	ssh openstack 'mkdir -p /tmp/dib-elements-$(OS)'
	scp -r $(DIB_BASE)/$(OS)/elements/. openstack:/tmp/dib-elements-$(OS)/
	scp $(DIB_BASE)/$(OS)/build.sh openstack:/tmp/dib-build-$(OS).sh
	@echo "==> Building image on OpenStack VM (this takes ~15-30 min)..."
	ssh openstack "sudo DIB_ROOT_SSH_KEY='$(shell cat $(SSH_KEY_FILE))' DIB_ROOT_PASSWORD='$(DIB_ROOT_PASSWORD)' DIB_IMAGE_DIR='$(DIB_IMAGE_DIR)' bash /tmp/dib-build-$(OS).sh"
	@echo "==> Uploading image to Glance from the VM (avoids local download)..."
	@# Ensure the openstack CLI is available on the VM (installed in a venv to avoid system conflicts).
	ssh openstack 'test -x /tmp/glance-upload-venv/bin/openstack || (python3 -m venv /tmp/glance-upload-venv && /tmp/glance-upload-venv/bin/pip install -q python-openstackclient)'
	@set -e; \
	source $(KOLLA_DIR)/admin-openrc.sh; \
	UPLOAD_CMD="set -e; \
		IMAGE_NAME=$(OS); \
		IMAGE_OS=$(OS); \
		IMAGE_OS_VERSION=unknown; \
		IMAGE_DISTRO=unknown; \
		IMAGE_DISTRO_VERSION=unknown; \
		IMAGE_BUILD_DATE=unknown; \
		IMAGE_FILE=$(DIB_IMAGE_DIR)/$(OS).raw; \
		IMAGE_INFO_FILE=$(DIB_IMAGE_DIR)/$(OS).image-info; \
		if [ -f \"\$$IMAGE_INFO_FILE\" ]; then . \"\$$IMAGE_INFO_FILE\"; fi; \
		OS_AUTH_URL=$$OS_AUTH_URL \
		OS_PROJECT_NAME=$$OS_PROJECT_NAME \
		OS_USERNAME=$$OS_USERNAME \
		OS_PASSWORD=$$OS_PASSWORD \
		OS_USER_DOMAIN_NAME=$$OS_USER_DOMAIN_NAME \
		OS_PROJECT_DOMAIN_NAME=$$OS_PROJECT_DOMAIN_NAME \
		OS_REGION_NAME=$$OS_REGION_NAME \
		/tmp/glance-upload-venv/bin/openstack image create \
			--disk-format raw \
			--container-format bare \
			--file \"\$$IMAGE_FILE\" \
			--property os_distro=\"\$$IMAGE_DISTRO\" \
			--property os_version=\"\$$IMAGE_OS_VERSION\" \
			--property mbhome_os=\"\$$IMAGE_OS\" \
			--property mbhome_os_version=\"\$$IMAGE_OS_VERSION\" \
			--property mbhome_distro=\"\$$IMAGE_DISTRO\" \
			--property mbhome_distro_version=\"\$$IMAGE_DISTRO_VERSION\" \
			--property mbhome_build_date=\"\$$IMAGE_BUILD_DATE\" \
			\"\$$IMAGE_NAME\""; \
	if ! ssh openstack "$$UPLOAD_CMD"; then \
		echo ""; \
		echo "ERROR: Glance upload failed, but the image should still be on the OpenStack VM at $(DIB_IMAGE_DIR)/$(OS).raw"; \
		echo ""; \
		echo "Retry manually with:"; \
		echo "  source $(KOLLA_DIR)/admin-openrc.sh"; \
		echo "  ssh openstack \"$$UPLOAD_CMD\""; \
		exit 1; \
	fi
	@echo "==> Done. Image '$(OS)' is now in Glance with OS version metadata."
