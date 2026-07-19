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
KUBERNETES_ADMIN_CONTEXT ?= admin@$(TALOS_CLUSTER_NAME)
KUBECTL_ADMIN := kubectl --kubeconfig "$(KUBECONFIG_FILE)" --context "$(KUBERNETES_ADMIN_CONTEXT)"
FLUX_ADMIN := flux --kubeconfig "$(KUBECONFIG_FILE)" --context "$(KUBERNETES_ADMIN_CONTEXT)"
HELM_ADMIN_KUBE_ARGS := --kubeconfig "$(KUBECONFIG_FILE)" --kube-context "$(KUBERNETES_ADMIN_CONTEXT)"
KUBERNETES_OIDC_ADMIN_CONTEXT ?= $(KUBERNETES_ADMIN_CONTEXT)
KUBERNETES_OIDC_CONTEXT ?= oidc@$(TALOS_CLUSTER_NAME)
KUBERNETES_OIDC_TEMPLATE ?= kubernetes/clusters/$(TALOS_CLUSTER_NAME)/kubeconfig.oidc.yaml
KUBERNETES_OIDC_KUBECONFIG ?= $(HOME)/.kube/$(TALOS_CLUSTER_NAME)-oidc
KUBERNETES_DEFAULT_KUBECONFIG ?= $(HOME)/.kube/config
KUBERNETES_OIDC_USER ?= oidc
KUBERNETES_OIDC_ISSUER_URL ?= https://dex.apps.mbhome.biz
KUBERNETES_OIDC_CLIENT_ID ?= kubernetes
DEX_POSTGRES_USER ?= dex
GRAFANA_ADMIN_USER ?= admin
VAULT_POD ?= vault-0
VAULT_UNSEAL_STEPS ?= 3
VAULT_KEY_SHARES ?= 5
VAULT_KEY_THRESHOLD ?= 3
VAULT_AUDIT_PATH ?= /vault/audit/vault-audit.log
VAULT_KV_MOUNT ?= kv
VAULT_OIDC_ISSUER_URL ?= https://dex.apps.mbhome.biz
VAULT_OIDC_CLIENT_ID ?= vault
VAULT_OIDC_DEFAULT_ROLE ?= default
VAULT_OIDC_UI_REDIRECT_URI ?= https://vault.apps.mbhome.biz/ui/vault/auth/oidc/oidc/callback
VAULT_OIDC_CLI_REDIRECT_URI ?= http://localhost:8250/oidc/callback
VAULT_ADMIN_GROUP ?= vault-admins
VAULT_USER_GROUP ?= vault-users
VAULT_READER_GROUP ?= vault-readers
VAULT_ADMIN_POLICY ?= vault-admin
VAULT_USER_POLICY ?= vault-user
VAULT_READER_POLICY ?= vault-reader
CILIUM_DIR := kubernetes/infrastructure/cilium
CILIUM_VERSION ?= 1.19.5
GATEWAY_API_VERSION ?= v1.4.1
GATEWAY_API_STANDARD_INSTALL_URL := https://github.com/kubernetes-sigs/gateway-api/releases/download/$(GATEWAY_API_VERSION)/standard-install.yaml
CERT_MANAGER_VERSION ?= v1.21.0
CERT_MANAGER_CRDS_URL := https://github.com/cert-manager/cert-manager/releases/download/$(CERT_MANAGER_VERSION)/cert-manager.crds.yaml
FLUX_CLUSTER_PATH ?= kubernetes/clusters/mbhome
FLUX_GITHUB_OWNER ?= bizottodbt
FLUX_GITHUB_REPOSITORY ?= mbhome
FLUX_GIT_BRANCH ?= main
FLUX_GITHUB_PERSONAL ?= true
FLUX_GITHUB_PRIVATE ?= false

.PHONY: help ansible-collections openstack-vm openstack-stack-stop openstack-stack-start openstack-stack-status openstack-setup openstack-versions ironic-set-deploy-images ironic-deploy-proxmox ironic-build-image proxmox-baseline proxmox-cluster windows-dc-baseline windows-ad-forest windows-ad-replica windows-ad-ldaps windows-ad-directory-check windows-ad-directory-apply windows-ad-dns-check windows-ad-dns-apply proxmox-smoke-vm-init proxmox-smoke-vm-plan proxmox-smoke-vm-apply proxmox-smoke-vm-destroy proxmox-talos-vm-init proxmox-talos-vm-plan proxmox-talos-vm-apply proxmox-talos-vm-destroy talos-inspect talos-gen-secrets talos-gen-config talos-apply-insecure talos-apply talos-apply-controlplane-insecure talos-apply-controlplane talos-bootstrap talos-kubeconfig talos-health talos-version talos-upgrade-plan talos-upgrade talos-restart-kube-apiserver dex-generate-oidc-kubeconfig kubernetes-oidc-context kubernetes-oidc-merge-context kubernetes-oidc-whoami gateway-api-crds-install gateway-api-status cilium-helm-repo cilium-install cilium-status cilium-hubble-status cilium-uninstall cert-manager-crds-install cert-manager-cloudflare-secret cert-manager-status cloudnative-pg-status metrics-server-status vault-status vault-init vault-unseal vault-bootstrap vault-oidc-secret vault-oidc-bootstrap monitoring-grafana-secret grafana-oauth-secret monitoring-required-secrets-check monitoring-status dex-postgres-secret dex-postgres-status dex-ldap-secret dex-required-secrets-check dex-status nfs-csi-status flux-check flux-bootstrap-github flux-status flux-tree flux-reconcile proxmox-ad-vms-init proxmox-ad-vms-plan proxmox-ad-vms-apply proxmox-ad-vms-destroy proxmox-windows-template-init proxmox-windows-template-answer-iso proxmox-windows-template-validate proxmox-windows-template-build bmc-baseline kolla-genpwd kolla-bootstrap kolla-prechecks kolla-deploy kolla-post-deploy kolla-reconfigure kolla-destroy kolla-ipa-images

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

windows-ad-ldaps: ## Install lab LDAPS certificates on Windows DCs and confirm TCP/636
	cd $(ANSIBLE_DIR) && OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES ANSIBLE_FORKS=1 ANSIBLE_LOCAL_TEMP=/private/tmp/ansible-local TMPDIR=/private/tmp ansible-playbook $(ANSIBLE_INVENTORY) playbooks/windows-ad-ldaps.yaml $(if $(LIMIT),--limit $(LIMIT),)

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

dex-generate-oidc-kubeconfig: ## Regenerate the committed credential-free OIDC kubeconfig template from Talos admin kubeconfig
	@test -f "$(KUBECONFIG_FILE)" || (echo "Run make talos-kubeconfig first"; exit 1)
	@cluster=$$(kubectl --kubeconfig "$(KUBECONFIG_FILE)" config view --minify --context="$(KUBERNETES_OIDC_ADMIN_CONTEXT)" -o jsonpath='{.contexts[0].context.cluster}'); \
	server=$$(kubectl --kubeconfig "$(KUBECONFIG_FILE)" config view --raw --minify --context="$(KUBERNETES_OIDC_ADMIN_CONTEXT)" -o jsonpath='{.clusters[0].cluster.server}'); \
	ca=$$(kubectl --kubeconfig "$(KUBECONFIG_FILE)" config view --raw --minify --context="$(KUBERNETES_OIDC_ADMIN_CONTEXT)" -o jsonpath='{.clusters[0].cluster.certificate-authority-data}'); \
	if [ -z "$$cluster" ]; then echo "Could not find cluster from context $(KUBERNETES_OIDC_ADMIN_CONTEXT) in $(KUBECONFIG_FILE)"; exit 1; fi; \
	if [ -z "$$server" ]; then echo "Could not find cluster server from context $(KUBERNETES_OIDC_ADMIN_CONTEXT) in $(KUBECONFIG_FILE)"; exit 1; fi; \
	if [ -z "$$ca" ]; then echo "Could not find cluster certificate-authority-data from context $(KUBERNETES_OIDC_ADMIN_CONTEXT) in $(KUBECONFIG_FILE)"; exit 1; fi; \
	tmpfile=$$(mktemp); \
	kubectl --kubeconfig "$$tmpfile" config set-cluster "$$cluster" --server="$$server" >/dev/null; \
	kubectl --kubeconfig "$$tmpfile" config set "clusters.$$cluster.certificate-authority-data" "$$ca" >/dev/null; \
	kubectl --kubeconfig "$$tmpfile" config set-credentials "$(KUBERNETES_OIDC_USER)" \
		--exec-api-version=client.authentication.k8s.io/v1 \
		--exec-interactive-mode=IfAvailable \
		--exec-command=kubectl \
		--exec-arg=oidc-login \
		--exec-arg=get-token \
		--exec-arg=--oidc-issuer-url="$(KUBERNETES_OIDC_ISSUER_URL)" \
		--exec-arg=--oidc-client-id="$(KUBERNETES_OIDC_CLIENT_ID)" \
		--exec-arg=--skip-open-browser \
		--exec-arg=--oidc-extra-scope=email \
		--exec-arg=--oidc-extra-scope=groups \
		--exec-arg=--oidc-extra-scope=profile >/dev/null; \
	kubectl --kubeconfig "$$tmpfile" config set-context "$(KUBERNETES_OIDC_CONTEXT)" --cluster="$$cluster" --user="$(KUBERNETES_OIDC_USER)" >/dev/null; \
	kubectl --kubeconfig "$$tmpfile" config use-context "$(KUBERNETES_OIDC_CONTEXT)" >/dev/null; \
	mkdir -p "$$(dirname "$(KUBERNETES_OIDC_TEMPLATE)")"; \
	install -m 0644 "$$tmpfile" "$(KUBERNETES_OIDC_TEMPLATE)"; \
	rm -f "$$tmpfile"; \
	if grep -Eq 'client-certificate-data|client-key-data|(^|[[:space:]])token:|password|secret' "$(KUBERNETES_OIDC_TEMPLATE)"; then echo "Generated $(KUBERNETES_OIDC_TEMPLATE) appears to contain credentials"; exit 1; fi; \
	echo "Regenerated $(KUBERNETES_OIDC_TEMPLATE)"

kubernetes-oidc-context: ## Create/update local kubeconfig OIDC user and context for Dex
	@test -f "$(KUBERNETES_OIDC_TEMPLATE)" || (echo "Missing $(KUBERNETES_OIDC_TEMPLATE)"; exit 1)
	@kubectl oidc-login --help >/dev/null 2>&1 || (echo "Missing kubectl oidc-login plugin. Install kubelogin before using the OIDC context."; exit 1)
	mkdir -p "$$(dirname "$(KUBERNETES_OIDC_KUBECONFIG)")"
	install -m 0600 "$(KUBERNETES_OIDC_TEMPLATE)" "$(KUBERNETES_OIDC_KUBECONFIG)"
	kubectl --kubeconfig "$(KUBERNETES_OIDC_KUBECONFIG)" config use-context "$(KUBERNETES_OIDC_CONTEXT)"
	@echo "Created/updated OIDC kubeconfig: $(KUBERNETES_OIDC_KUBECONFIG)"
	@echo "Use isolated kubeconfig with:"
	@echo "export KUBECONFIG=$(KUBERNETES_OIDC_KUBECONFIG)"
	@echo "kubectl auth whoami"
	@echo "That command invokes kubectl oidc-login if no valid token is cached."
	@echo "Or merge into the default kubeconfig with:"
	@echo "make kubernetes-oidc-merge-context"

kubernetes-oidc-merge-context: kubernetes-oidc-context ## Merge OIDC context into ~/.kube/config and select it
	@mkdir -p "$$(dirname "$(KUBERNETES_DEFAULT_KUBECONFIG)")"
	@if [ -n "$$KUBECONFIG" ]; then \
		echo "WARNING: KUBECONFIG is currently set to $$KUBECONFIG"; \
		echo "Plain kubectl commands will keep using that value until you unset it."; \
	fi
	@if [ -f "$(KUBERNETES_DEFAULT_KUBECONFIG)" ]; then \
		backup="$(KUBERNETES_DEFAULT_KUBECONFIG).bak.$$(date +%Y%m%d%H%M%S)"; \
		install -m 0600 "$(KUBERNETES_DEFAULT_KUBECONFIG)" "$$backup"; \
		echo "Backed up $(KUBERNETES_DEFAULT_KUBECONFIG) to $$backup"; \
	fi
	@tmpfile=$$(mktemp); \
	if [ -f "$(KUBERNETES_DEFAULT_KUBECONFIG)" ]; then \
		KUBECONFIG="$(KUBERNETES_OIDC_KUBECONFIG):$(KUBERNETES_DEFAULT_KUBECONFIG)" kubectl config view --flatten > "$$tmpfile"; \
	else \
		KUBECONFIG="$(KUBERNETES_OIDC_KUBECONFIG)" kubectl config view --flatten > "$$tmpfile"; \
	fi; \
	install -m 0600 "$$tmpfile" "$(KUBERNETES_DEFAULT_KUBECONFIG)"; \
	rm -f "$$tmpfile"; \
	kubectl --kubeconfig "$(KUBERNETES_DEFAULT_KUBECONFIG)" config use-context "$(KUBERNETES_OIDC_CONTEXT)"; \
	echo "Merged $(KUBERNETES_OIDC_CONTEXT) into $(KUBERNETES_DEFAULT_KUBECONFIG)"; \
	echo "Login/test with:"; \
	echo "unset KUBECONFIG"; \
	echo "kubectl auth whoami"; \
	echo "Or ignore the current shell KUBECONFIG with:"; \
	echo "make kubernetes-oidc-whoami"; \
	echo "That command invokes kubectl oidc-login if no valid token is cached."

kubernetes-oidc-whoami: ## Test OIDC auth using the intended mbhome OIDC kubeconfig, ignoring ambient KUBECONFIG
	@test -f "$(KUBERNETES_DEFAULT_KUBECONFIG)" || (echo "Missing $(KUBERNETES_DEFAULT_KUBECONFIG). Run make kubernetes-oidc-merge-context first"; exit 1)
	KUBECONFIG="$(KUBERNETES_DEFAULT_KUBECONFIG)" kubectl config use-context "$(KUBERNETES_OIDC_CONTEXT)"
	KUBECONFIG="$(KUBERNETES_DEFAULT_KUBECONFIG)" kubectl auth whoami

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

talos-restart-kube-apiserver: ## Restart kube-apiserver containers sequentially on control planes after OIDC signing-key changes
	@test -n "$(TALOS_ENDPOINT)" || (echo "Set TALOS_ENDPOINT=<control-plane-endpoint-ip-or-dns>"; exit 1)
	@test -f "$(TALOS_CLUSTER_DIR)/talosconfig" || (echo "Run make talos-gen-config first"; exit 1)
	@test -f "$(KUBECONFIG_FILE)" || (echo "Run make talos-kubeconfig first"; exit 1)
	@nodes="$$($(KUBECTL_ADMIN) get nodes -l node-role.kubernetes.io/control-plane -o jsonpath='{range .items[*]}{.status.addresses[?(@.type=="InternalIP")].address}{" "}{end}')"; \
	test -n "$$nodes" || (echo "No control-plane nodes found"; exit 1); \
	for node in $$nodes; do \
		container_id="$$(TALOSCONFIG="$(TALOSCONFIG)" talosctl containers --nodes "$$node" --endpoints "$(TALOS_ENDPOINT)" --kubernetes | awk '/kube-apiserver.*CONTAINER_RUNNING/ {print $$4; exit}')"; \
		test -n "$$container_id" || (echo "Could not find running kube-apiserver container on $$node"; exit 1); \
		echo "Restarting kube-apiserver on $$node"; \
		TALOSCONFIG="$(TALOSCONFIG)" talosctl restart --kubernetes "$$container_id" --nodes "$$node" --endpoints "$(TALOS_ENDPOINT)"; \
		sleep 10; \
	done

gateway-api-crds-install: ## Install or upgrade standard Gateway API CRDs before enabling Cilium Gateway API
	@test -f "$(KUBECONFIG_FILE)" || (echo "Run make talos-kubeconfig first"; exit 1)
	$(KUBECTL_ADMIN) apply --server-side -f "$(GATEWAY_API_STANDARD_INSTALL_URL)"

gateway-api-status: ## Show Gateway API CRDs, classes, and gateways
	@test -f "$(KUBECONFIG_FILE)" || (echo "Run make talos-kubeconfig first"; exit 1)
	$(KUBECTL_ADMIN) get crd gatewayclasses.gateway.networking.k8s.io gateways.gateway.networking.k8s.io httproutes.gateway.networking.k8s.io grpcroutes.gateway.networking.k8s.io referencegrants.gateway.networking.k8s.io
	$(KUBECTL_ADMIN) get gatewayclass
	$(KUBECTL_ADMIN) get gateways.gateway.networking.k8s.io --all-namespaces -o wide

cilium-helm-repo: ## Add/update the Cilium Helm repository
	helm repo add cilium https://helm.cilium.io
	helm repo update cilium

cilium-install: ## Install or upgrade Cilium on the Talos Kubernetes cluster
	@test -f "$(KUBECONFIG_FILE)" || (echo "Run make talos-kubeconfig first"; exit 1)
	@test -f "$(CILIUM_DIR)/values.yaml" || (echo "Missing $(CILIUM_DIR)/values.yaml"; exit 1)
	@$(KUBECTL_ADMIN) get crd gateways.gateway.networking.k8s.io >/dev/null || (echo "Run make gateway-api-crds-install before make cilium-install"; exit 1)
	helm upgrade --install cilium cilium/cilium \
		--version "$(CILIUM_VERSION)" \
		--namespace kube-system \
		$(HELM_ADMIN_KUBE_ARGS) \
		--values "$(CILIUM_DIR)/values.yaml"
	$(KUBECTL_ADMIN) -n kube-system rollout restart deployment/cilium-operator
	$(KUBECTL_ADMIN) -n kube-system rollout restart ds/cilium
	$(KUBECTL_ADMIN) -n kube-system rollout status deployment/cilium-operator --timeout=5m
	$(KUBECTL_ADMIN) -n kube-system rollout status ds/cilium --timeout=5m
	$(KUBECTL_ADMIN) -n kube-system rollout status deployment/hubble-relay --timeout=5m
	$(KUBECTL_ADMIN) -n kube-system rollout status deployment/hubble-ui --timeout=5m

cilium-status: ## Show Cilium pods and Kubernetes node readiness
	@test -f "$(KUBECONFIG_FILE)" || (echo "Run make talos-kubeconfig first"; exit 1)
	$(KUBECTL_ADMIN) -n kube-system get pods -l k8s-app=cilium -o wide
	$(KUBECTL_ADMIN) -n kube-system get pods -l name=cilium-operator -o wide
	$(KUBECTL_ADMIN) -n kube-system get pods -l k8s-app=hubble-relay -o wide || true
	$(KUBECTL_ADMIN) -n kube-system get pods -l k8s-app=hubble-ui -o wide || true
	$(KUBECTL_ADMIN) get nodes -o wide

cilium-hubble-status: ## Show Hubble relay, UI, service, and internal route
	@test -f "$(KUBECONFIG_FILE)" || (echo "Run make talos-kubeconfig first"; exit 1)
	$(KUBECTL_ADMIN) -n kube-system get pods -l k8s-app=hubble-relay -o wide
	$(KUBECTL_ADMIN) -n kube-system get pods -l k8s-app=hubble-ui -o wide
	$(KUBECTL_ADMIN) -n kube-system get svc hubble-relay hubble-ui
	$(KUBECTL_ADMIN) -n kube-system get httproute hubble-ui

cilium-uninstall: ## Remove Cilium from the cluster
	@test -f "$(KUBECONFIG_FILE)" || (echo "Run make talos-kubeconfig first"; exit 1)
	helm uninstall cilium --namespace kube-system $(HELM_ADMIN_KUBE_ARGS)

cert-manager-crds-install: ## Install or upgrade cert-manager CRDs before Flux reconciles cert-manager resources
	@test -f "$(KUBECONFIG_FILE)" || (echo "Run make talos-kubeconfig first"; exit 1)
	$(KUBECTL_ADMIN) apply --server-side -f "$(CERT_MANAGER_CRDS_URL)"

cert-manager-cloudflare-secret: ## Create/update the Cloudflare DNS-01 API token secret from CLOUDFLARE_API_TOKEN
	@test -f "$(KUBECONFIG_FILE)" || (echo "Run make talos-kubeconfig first"; exit 1)
	@test -n "$$CLOUDFLARE_API_TOKEN" || (echo "Export CLOUDFLARE_API_TOKEN before running this target"; exit 1)
	$(KUBECTL_ADMIN) create namespace cert-manager --dry-run=client -o yaml | $(KUBECTL_ADMIN) apply -f -
	$(KUBECTL_ADMIN) -n cert-manager create secret generic cloudflare-api-token --from-literal=api-token="$$CLOUDFLARE_API_TOKEN" --dry-run=client -o yaml | $(KUBECTL_ADMIN) apply -f -

cert-manager-status: ## Show cert-manager pods, issuers, and wildcard certificate status
	@test -f "$(KUBECONFIG_FILE)" || (echo "Run make talos-kubeconfig first"; exit 1)
	$(KUBECTL_ADMIN) -n cert-manager get pods
	$(KUBECTL_ADMIN) get clusterissuers.cert-manager.io
	$(KUBECTL_ADMIN) -n gateway-system get certificates.cert-manager.io,certificaterequests.cert-manager.io,orders.acme.cert-manager.io,challenges.acme.cert-manager.io || true
	$(KUBECTL_ADMIN) -n gateway-system get secret apps-mbhome-biz-tls || true

cloudnative-pg-status: ## Show CloudNativePG operator and CRD status
	@test -f "$(KUBECONFIG_FILE)" || (echo "Run make talos-kubeconfig first"; exit 1)
	$(KUBECTL_ADMIN) -n flux-system get helmrelease cloudnative-pg
	$(KUBECTL_ADMIN) -n cnpg-system get pods
	$(KUBECTL_ADMIN) get crd clusters.postgresql.cnpg.io backups.postgresql.cnpg.io scheduledbackups.postgresql.cnpg.io

metrics-server-status: ## Show metrics-server and Kubernetes Metrics API status
	@test -f "$(KUBECONFIG_FILE)" || (echo "Run make talos-kubeconfig first"; exit 1)
	$(KUBECTL_ADMIN) -n flux-system get helmrelease metrics-server
	$(KUBECTL_ADMIN) -n kube-system get pods -l app.kubernetes.io/instance=metrics-server -o wide
	$(KUBECTL_ADMIN) get apiservice v1beta1.metrics.k8s.io
	$(KUBECTL_ADMIN) top nodes
	$(KUBECTL_ADMIN) top pods -A

vault-status: ## Show Vault release, pods, services, route, PVCs, and seal status
	@test -f "$(KUBECONFIG_FILE)" || (echo "Run make talos-kubeconfig first"; exit 1)
	$(KUBECTL_ADMIN) -n flux-system get helmrelease vault
	$(KUBECTL_ADMIN) -n vault get pods -l app.kubernetes.io/instance=vault -o wide
	$(KUBECTL_ADMIN) -n vault get svc vault vault-active vault-standby vault-internal vault-ui
	$(KUBECTL_ADMIN) -n vault get httproute vault
	$(KUBECTL_ADMIN) -n vault get httproute vault -o jsonpath='{range .status.parents[*].conditions[*]}{.type}={.status} {.reason} {.message}{"\n"}{end}' || true
	$(KUBECTL_ADMIN) -n vault get pvc
	$(KUBECTL_ADMIN) -n vault exec vault-0 -- vault status || true

vault-init: ## Initialize Vault and print unseal keys/root token once
	@test -f "$(KUBECONFIG_FILE)" || (echo "Run make talos-kubeconfig first"; exit 1)
	@echo "This initializes $(VAULT_POD) with $(VAULT_KEY_SHARES) key shares and threshold $(VAULT_KEY_THRESHOLD)."
	@echo "The unseal keys and initial root token are printed once. Store them outside Git before closing this terminal."
	@printf "Type 'initialize vault' to continue: "; \
	read confirm; \
	if [ "$$confirm" != "initialize vault" ]; then echo "Cancelled"; exit 1; fi
	$(KUBECTL_ADMIN) -n vault exec "$(VAULT_POD)" -- vault operator init -key-shares="$(VAULT_KEY_SHARES)" -key-threshold="$(VAULT_KEY_THRESHOLD)"

vault-unseal: ## Interactively submit Vault unseal keys
	@test -f "$(KUBECONFIG_FILE)" || (echo "Run make talos-kubeconfig first"; exit 1)
	@for step in $$(seq 1 "$(VAULT_UNSEAL_STEPS)"); do \
		echo "Vault unseal step $$step/$(VAULT_UNSEAL_STEPS) for $(VAULT_POD)"; \
		$(KUBECTL_ADMIN) -n vault exec -it "$(VAULT_POD)" -- vault operator unseal; \
	done
	$(KUBECTL_ADMIN) -n vault exec "$(VAULT_POD)" -- vault status || true

vault-bootstrap: ## Interactively login with root token, enable audit logging and KV v2
	@test -f "$(KUBECONFIG_FILE)" || (echo "Run make talos-kubeconfig first"; exit 1)
	@echo "Enter the initial root token at the Vault prompt. It will be stored only inside $(VAULT_POD)'s transient CLI token file for this bootstrap."
	$(KUBECTL_ADMIN) -n vault exec -it "$(VAULT_POD)" -- vault login
	$(KUBECTL_ADMIN) -n vault exec "$(VAULT_POD)" -- sh -ec 'vault audit list -format=json | grep -q "\"file/\"" || vault audit enable file file_path="$(VAULT_AUDIT_PATH)"'
	$(KUBECTL_ADMIN) -n vault exec "$(VAULT_POD)" -- sh -ec 'vault secrets list -format=json | grep -q "\"$(VAULT_KV_MOUNT)/\"" || vault secrets enable -path="$(VAULT_KV_MOUNT)" kv-v2'
	$(KUBECTL_ADMIN) -n vault exec "$(VAULT_POD)" -- sh -ec 'rm -f "$$HOME/.vault-token"'
	$(KUBECTL_ADMIN) -n vault exec "$(VAULT_POD)" -- vault status || true

vault-oidc-secret: ## Create/update the Dex Vault OAuth client secret from VAULT_OIDC_CLIENT_SECRET
	@test -f "$(KUBECONFIG_FILE)" || (echo "Run make talos-kubeconfig first"; exit 1)
	@test -n "$$VAULT_OIDC_CLIENT_SECRET" || (echo "Export VAULT_OIDC_CLIENT_SECRET before running this target"; exit 1)
	$(KUBECTL_ADMIN) create namespace dex --dry-run=client -o yaml | $(KUBECTL_ADMIN) apply -f -
	$(KUBECTL_ADMIN) -n dex create secret generic dex-vault-client --from-literal=DEX_VAULT_CLIENT_SECRET="$$VAULT_OIDC_CLIENT_SECRET" --dry-run=client -o yaml | $(KUBECTL_ADMIN) apply -f -

vault-oidc-bootstrap: ## Interactively configure Vault OIDC auth against Dex
	@test -f "$(KUBECONFIG_FILE)" || (echo "Run make talos-kubeconfig first"; exit 1)
	@test -n "$$VAULT_OIDC_CLIENT_SECRET" || (echo "Export VAULT_OIDC_CLIENT_SECRET before running this target"; exit 1)
	@echo "Enter a Vault token with enough privilege to configure auth methods, policies, and identity groups."
	$(KUBECTL_ADMIN) -n vault exec -it "$(VAULT_POD)" -- vault login
	$(KUBECTL_ADMIN) -n vault exec "$(VAULT_POD)" -- sh -ec 'vault auth list | grep -q "^oidc/" || vault auth enable oidc'
	@printf '%s' "$$VAULT_OIDC_CLIENT_SECRET" | $(KUBECTL_ADMIN) -n vault exec -i "$(VAULT_POD)" -- sh -ec 'IFS= read -r client_secret; vault write auth/oidc/config oidc_discovery_url="$(VAULT_OIDC_ISSUER_URL)" oidc_client_id="$(VAULT_OIDC_CLIENT_ID)" oidc_client_secret="$$client_secret" default_role="$(VAULT_OIDC_DEFAULT_ROLE)"'
	$(KUBECTL_ADMIN) -n vault exec "$(VAULT_POD)" -- vault write auth/oidc/role/"$(VAULT_OIDC_DEFAULT_ROLE)" role_type="oidc" user_claim="email" groups_claim="groups" oidc_scopes="openid,email,profile,groups" allowed_redirect_uris="$(VAULT_OIDC_UI_REDIRECT_URI)" allowed_redirect_uris="$(VAULT_OIDC_CLI_REDIRECT_URI)" token_policies="default" ttl="1h" max_ttl="8h"
	@printf '%s\n' 'path "*" {' '  capabilities = ["create", "read", "update", "delete", "list", "sudo"]' '}' | $(KUBECTL_ADMIN) -n vault exec -i "$(VAULT_POD)" -- vault policy write "$(VAULT_ADMIN_POLICY)" -
	@printf '%s\n' 'path "sys/mounts" {' '  capabilities = ["read", "list"]' '}' '' 'path "$(VAULT_KV_MOUNT)/metadata" {' '  capabilities = ["list"]' '}' '' 'path "$(VAULT_KV_MOUNT)/metadata/*" {' '  capabilities = ["read", "list"]' '}' '' 'path "$(VAULT_KV_MOUNT)/data/*" {' '  capabilities = ["create", "read", "update", "delete"]' '}' | $(KUBECTL_ADMIN) -n vault exec -i "$(VAULT_POD)" -- vault policy write "$(VAULT_USER_POLICY)" -
	@printf '%s\n' 'path "sys/mounts" {' '  capabilities = ["read", "list"]' '}' '' 'path "$(VAULT_KV_MOUNT)/metadata" {' '  capabilities = ["list"]' '}' '' 'path "$(VAULT_KV_MOUNT)/metadata/*" {' '  capabilities = ["read", "list"]' '}' '' 'path "$(VAULT_KV_MOUNT)/data/*" {' '  capabilities = ["read"]' '}' | $(KUBECTL_ADMIN) -n vault exec -i "$(VAULT_POD)" -- vault policy write "$(VAULT_READER_POLICY)" -
	$(KUBECTL_ADMIN) -n vault exec "$(VAULT_POD)" -- sh -ec 'set -eu; accessor=$$(vault read -field=accessor sys/auth/oidc); for mapping in "$(VAULT_ADMIN_GROUP):$(VAULT_ADMIN_POLICY)" "$(VAULT_USER_GROUP):$(VAULT_USER_POLICY)" "$(VAULT_READER_GROUP):$(VAULT_READER_POLICY)"; do group="$${mapping%%:*}"; policy="$${mapping#*:}"; vault write identity/group name="$$group" type="external" policies="$$policy" >/dev/null; group_id=$$(vault read -field=id identity/group/name/"$$group"); vault write identity/group-alias name="$$group" mount_accessor="$$accessor" canonical_id="$$group_id" >/dev/null || true; done'
	$(KUBECTL_ADMIN) -n vault exec "$(VAULT_POD)" -- sh -ec 'rm -f "$$HOME/.vault-token"'

monitoring-grafana-secret: ## Create/update the Grafana admin secret from GRAFANA_ADMIN_PASSWORD
	@test -f "$(KUBECONFIG_FILE)" || (echo "Run make talos-kubeconfig first"; exit 1)
	@test -n "$$GRAFANA_ADMIN_PASSWORD" || (echo "Export GRAFANA_ADMIN_PASSWORD before running this target"; exit 1)
	$(KUBECTL_ADMIN) create namespace monitoring --dry-run=client -o yaml | $(KUBECTL_ADMIN) apply -f -
	$(KUBECTL_ADMIN) -n monitoring create secret generic grafana-admin --from-literal=admin-user="$(GRAFANA_ADMIN_USER)" --from-literal=admin-password="$$GRAFANA_ADMIN_PASSWORD" --dry-run=client -o yaml | $(KUBECTL_ADMIN) apply -f -

grafana-oauth-secret: ## Create/update Dex and Grafana OAuth client secrets from GRAFANA_OAUTH_CLIENT_SECRET
	@test -f "$(KUBECONFIG_FILE)" || (echo "Run make talos-kubeconfig first"; exit 1)
	@test -n "$$GRAFANA_OAUTH_CLIENT_SECRET" || (echo "Export GRAFANA_OAUTH_CLIENT_SECRET before running this target"; exit 1)
	$(KUBECTL_ADMIN) create namespace dex --dry-run=client -o yaml | $(KUBECTL_ADMIN) apply -f -
	$(KUBECTL_ADMIN) create namespace monitoring --dry-run=client -o yaml | $(KUBECTL_ADMIN) apply -f -
	$(KUBECTL_ADMIN) -n dex create secret generic dex-grafana-client --from-literal=DEX_GRAFANA_CLIENT_SECRET="$$GRAFANA_OAUTH_CLIENT_SECRET" --dry-run=client -o yaml | $(KUBECTL_ADMIN) apply -f -
	$(KUBECTL_ADMIN) -n monitoring create secret generic grafana-oauth --from-literal=GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET="$$GRAFANA_OAUTH_CLIENT_SECRET" --dry-run=client -o yaml | $(KUBECTL_ADMIN) apply -f -

monitoring-required-secrets-check: ## Confirm monitoring secrets exist before Flux reconciles monitoring
	@test -f "$(KUBECONFIG_FILE)" || (echo "Run make talos-kubeconfig first"; exit 1)
	@$(KUBECTL_ADMIN) -n monitoring get secret grafana-admin >/dev/null || (echo "Missing monitoring/grafana-admin. Run: export GRAFANA_ADMIN_PASSWORD='...' && make monitoring-grafana-secret"; exit 1)
	@$(KUBECTL_ADMIN) -n monitoring get secret grafana-oauth >/dev/null || (echo "Missing monitoring/grafana-oauth. Run: export GRAFANA_OAUTH_CLIENT_SECRET='...' && make grafana-oauth-secret"; exit 1)

monitoring-status: ## Show kube-prometheus-stack pods, services, routes, and PVCs
	@test -f "$(KUBECONFIG_FILE)" || (echo "Run make talos-kubeconfig first"; exit 1)
	$(KUBECTL_ADMIN) -n flux-system get helmrelease kube-prometheus-stack
	$(KUBECTL_ADMIN) -n monitoring get pods -o wide
	$(KUBECTL_ADMIN) -n monitoring get svc kube-prometheus-stack-grafana kube-prometheus-stack-prometheus kube-prometheus-stack-alertmanager
	$(KUBECTL_ADMIN) -n monitoring get httproute grafana prometheus alertmanager
	$(KUBECTL_ADMIN) -n monitoring get pvc
	$(KUBECTL_ADMIN) get prometheus,alertmanager --all-namespaces

dex-postgres-secret: ## Create/update the Dex Postgres application owner secret from DEX_POSTGRES_PASSWORD
	@test -f "$(KUBECONFIG_FILE)" || (echo "Run make talos-kubeconfig first"; exit 1)
	@test -n "$$DEX_POSTGRES_PASSWORD" || (echo "Export DEX_POSTGRES_PASSWORD before running this target"; exit 1)
	$(KUBECTL_ADMIN) create namespace dex --dry-run=client -o yaml | $(KUBECTL_ADMIN) apply -f -
	$(KUBECTL_ADMIN) -n dex create secret generic dex-postgres-app --type=kubernetes.io/basic-auth --from-literal=username="$(DEX_POSTGRES_USER)" --from-literal=password="$$DEX_POSTGRES_PASSWORD" --dry-run=client -o yaml | $(KUBECTL_ADMIN) apply -f -

dex-postgres-status: ## Show Dex PostgreSQL cluster, pods, services, and PVCs
	@test -f "$(KUBECONFIG_FILE)" || (echo "Run make talos-kubeconfig first"; exit 1)
	$(KUBECTL_ADMIN) -n dex get clusters.postgresql.cnpg.io
	$(KUBECTL_ADMIN) -n dex get pods,svc,pvc -l cnpg.io/cluster=dex-postgres

dex-ldap-secret: ## Create/update the Dex AD LDAP bind secret from DEX_LDAP_BIND_DN and DEX_LDAP_BIND_PASSWORD
	@test -f "$(KUBECONFIG_FILE)" || (echo "Run make talos-kubeconfig first"; exit 1)
	@test -n "$$DEX_LDAP_BIND_DN" || (echo "Export DEX_LDAP_BIND_DN before running this target"; exit 1)
	@test -n "$$DEX_LDAP_BIND_PASSWORD" || (echo "Export DEX_LDAP_BIND_PASSWORD before running this target"; exit 1)
	$(KUBECTL_ADMIN) create namespace dex --dry-run=client -o yaml | $(KUBECTL_ADMIN) apply -f -
	$(KUBECTL_ADMIN) -n dex create secret generic dex-ldap-bind --from-literal=DEX_LDAP_BIND_DN="$$DEX_LDAP_BIND_DN" --from-literal=DEX_LDAP_BIND_PASSWORD="$$DEX_LDAP_BIND_PASSWORD" --dry-run=client -o yaml | $(KUBECTL_ADMIN) apply -f -

dex-required-secrets-check: ## Confirm Dex database and LDAP secrets exist before Flux reconciles dependent layers
	@test -f "$(KUBECONFIG_FILE)" || (echo "Run make talos-kubeconfig first"; exit 1)
	@$(KUBECTL_ADMIN) -n dex get secret dex-postgres-app >/dev/null || (echo "Missing dex/dex-postgres-app. Run: export DEX_POSTGRES_PASSWORD='...' && make dex-postgres-secret"; exit 1)
	@$(KUBECTL_ADMIN) -n dex get secret dex-ldap-bind >/dev/null || (echo "Missing dex/dex-ldap-bind. Run: export DEX_LDAP_BIND_DN='...' DEX_LDAP_BIND_PASSWORD='...' && make dex-ldap-secret"; exit 1)
	@$(KUBECTL_ADMIN) -n dex get secret dex-grafana-client >/dev/null || (echo "Missing dex/dex-grafana-client. Run: export GRAFANA_OAUTH_CLIENT_SECRET='...' && make grafana-oauth-secret"; exit 1)
	@$(KUBECTL_ADMIN) -n dex get secret dex-vault-client >/dev/null || (echo "Missing dex/dex-vault-client. Run: export VAULT_OIDC_CLIENT_SECRET='...' && make vault-oidc-secret"; exit 1)

dex-status: ## Show Dex pods, route, RBAC bindings, and OIDC discovery
	@test -f "$(KUBECONFIG_FILE)" || (echo "Run make talos-kubeconfig first"; exit 1)
	$(KUBECTL_ADMIN) -n dex get secret dex-ldap-bind dex-postgres-app dex-grafana-client dex-vault-client -o custom-columns='NAME:.metadata.name,TYPE:.type' || true
	$(KUBECTL_ADMIN) -n dex get deployment dex
	$(KUBECTL_ADMIN) -n dex get pods -l app.kubernetes.io/instance=dex -o wide
	$(KUBECTL_ADMIN) -n dex get svc dex
	$(KUBECTL_ADMIN) -n dex get httproute dex
	$(KUBECTL_ADMIN) -n dex get deployment,replicaset
	$(KUBECTL_ADMIN) -n flux-system get helmrelease dex
	$(KUBECTL_ADMIN) get clusterrolebinding oidc-k8s-admins-cluster-admin oidc-k8s-viewers-view
	$(KUBECTL_ADMIN) -n dex get events --sort-by=.lastTimestamp | tail -20
	@curl -fsS https://dex.apps.mbhome.biz/.well-known/openid-configuration | sed -n '1,20p'

nfs-csi-status: ## Show Flux-managed NFS CSI pods and StorageClasses
	@test -f "$(KUBECONFIG_FILE)" || (echo "Run make talos-kubeconfig first"; exit 1)
	$(KUBECTL_ADMIN) -n kube-system get pods -l app=csi-nfs-controller -o wide
	$(KUBECTL_ADMIN) -n kube-system get pods -l app=csi-nfs-node -o wide
	$(KUBECTL_ADMIN) get storageclass

flux-check: ## Check Flux prerequisites against the Kubernetes cluster
	@test -f "$(KUBECONFIG_FILE)" || (echo "Run make talos-kubeconfig first"; exit 1)
	$(FLUX_ADMIN) check --pre

flux-bootstrap-github: ## Bootstrap Flux from this GitHub repo
	@test -f "$(KUBECONFIG_FILE)" || (echo "Run make talos-kubeconfig first"; exit 1)
	@test -n "$$GITHUB_TOKEN" || (echo "Export GITHUB_TOKEN with repo admin access before bootstrapping Flux"; exit 1)
	@test -z "$$(git status --porcelain -- kubernetes)" || (echo "Commit and push kubernetes before bootstrapping Flux"; exit 1)
	$(FLUX_ADMIN) bootstrap github \
		--owner="$(FLUX_GITHUB_OWNER)" \
		--repository="$(FLUX_GITHUB_REPOSITORY)" \
		--branch="$(FLUX_GIT_BRANCH)" \
		--path="$(FLUX_CLUSTER_PATH)" \
		--private="$(FLUX_GITHUB_PRIVATE)" \
		$(if $(filter true,$(FLUX_GITHUB_PERSONAL)),--personal,)

flux-status: ## Show Flux reconciliation state
	@test -f "$(KUBECONFIG_FILE)" || (echo "Run make talos-kubeconfig first"; exit 1)
	$(FLUX_ADMIN) get sources git
	$(FLUX_ADMIN) get sources helm || true
	$(FLUX_ADMIN) get kustomizations || true
	$(FLUX_ADMIN) get helmreleases --all-namespaces || true

flux-tree: ## Show Flux-managed layers and applied revisions
	@test -f "$(KUBECONFIG_FILE)" || (echo "Run make talos-kubeconfig first"; exit 1)
	@echo "==> Git sources"
	@$(KUBECTL_ADMIN) -n flux-system get gitrepositories.source.toolkit.fluxcd.io \
		-o custom-columns='NAME:.metadata.name,READY:.status.conditions[?(@.type=="Ready")].status,REVISION:.status.artifact.revision,URL:.spec.url' || true
	@echo ""
	@echo "==> Flux Kustomizations"
	@$(KUBECTL_ADMIN) -n flux-system get kustomizations.kustomize.toolkit.fluxcd.io \
		-o custom-columns='NAME:.metadata.name,READY:.status.conditions[?(@.type=="Ready")].status,REVISION:.status.lastAppliedRevision,PATH:.spec.path,DEPENDS-ON:.spec.dependsOn[*].name' || true
	@echo ""
	@echo "==> Helm sources"
	@$(KUBECTL_ADMIN) -n flux-system get helmrepositories.source.toolkit.fluxcd.io \
		-o custom-columns='NAME:.metadata.name,READY:.status.conditions[?(@.type=="Ready")].status,REVISION:.status.artifact.revision,URL:.spec.url' || true
	@echo ""
	@echo "==> Helm releases"
	@$(KUBECTL_ADMIN) get helmreleases.helm.toolkit.fluxcd.io --all-namespaces \
		-o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,READY:.status.conditions[?(@.type=="Ready")].status,REVISION:.status.lastAppliedRevision,CHART:.spec.chart.spec.chart,TARGET:.spec.targetNamespace' || true

flux-reconcile: monitoring-required-secrets-check dex-required-secrets-check ## Force Flux to pull Git and reconcile mbhome platform layers
	@test -f "$(KUBECONFIG_FILE)" || (echo "Run make talos-kubeconfig first"; exit 1)
	$(FLUX_ADMIN) reconcile source git flux-system --namespace flux-system
	$(FLUX_ADMIN) reconcile kustomization infrastructure --namespace flux-system --with-source
	$(FLUX_ADMIN) reconcile kustomization databases --namespace flux-system --with-source
	$(FLUX_ADMIN) reconcile kustomization identity --namespace flux-system --with-source
	$(FLUX_ADMIN) reconcile kustomization apps --namespace flux-system --with-source

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
