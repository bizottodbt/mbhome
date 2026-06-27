#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

NODE="${NODE:?NODE is required}"
ANSIBLE_HOST="${ANSIBLE_HOST:-${PROXMOX_IP:-${NODE}}}"
PROXMOX_IP="${PROXMOX_IP:-}"
PROXMOX_PREFIX="${PROXMOX_PREFIX:-24}"
PROXMOX_GATEWAY="${PROXMOX_GATEWAY:-192.0.2.1}"
PROXMOX_DNS="${PROXMOX_DNS:-${PROXMOX_GATEWAY}}"
PROXMOX_MAC="${PROXMOX_MAC:-}"

KOLLA_DIR="${KOLLA_DIR:-${repo_root}/infrastructure/kolla-ansible}"
KOLLA_VENV="${KOLLA_VENV:-${KOLLA_DIR}/.venv}"
ANSIBLE_DIR="${ANSIBLE_DIR:-${repo_root}/infrastructure/ansible}"
OPENSTACK="${KOLLA_VENV}/bin/openstack"
ANSIBLE_INVENTORY=("-i" "inventory/hosts.yaml")
ANSIBLE_INVENTORY_ABS=("-i" "${ANSIBLE_DIR}/inventory/hosts.yaml")
if [[ -f "${ANSIBLE_DIR}/inventory/hosts.local.yaml" ]]; then
    ANSIBLE_INVENTORY+=("-i" "inventory/hosts.local.yaml")
    ANSIBLE_INVENTORY_ABS+=("-i" "${ANSIBLE_DIR}/inventory/hosts.local.yaml")
fi

source "${KOLLA_DIR}/admin-openrc.sh"

configdrive="$(mktemp "${TMPDIR:-/tmp}/configdrive-${NODE}.XXXXXX.json")"
trap 'rm -f "${configdrive}"' EXIT

mac_address=""
if [[ -n "${PROXMOX_IP}" ]]; then
    mac_address="${PROXMOX_MAC,,}"
    if [[ -z "${mac_address}" ]]; then
        mac_address="$(env -u OS_SYSTEM_SCOPE "${OPENSTACK}" baremetal port list \
            --node "${NODE}" -f value -c Address | awk 'NR == 1 { print tolower($1); exit }')"
    fi
    if [[ -z "${mac_address}" ]]; then
        echo "No Ironic port MAC found for ${NODE}; cannot build static network config." >&2
        exit 1
    fi
fi

python3 - "${configdrive}" "${NODE}" "${PROXMOX_IP}" "${PROXMOX_PREFIX}" "${PROXMOX_GATEWAY}" "${PROXMOX_DNS}" "${mac_address}" <<'PY'
import json
import sys
from pathlib import Path

path, node, ip, prefix, gateway, dns, mac = sys.argv[1:]
configdrive = {
    "meta_data": {
        "hostname": node,
    },
}

if ip:
    configdrive["user_data"] = f"""#cloud-config
bootcmd:
  - mkdir -p /etc/systemd/network
  - rm -f /etc/systemd/network/10-dhcp-all-ether.network
  - |
    cat > /etc/systemd/network/05-ironic-static.network <<'EOF'
    [Match]
    MACAddress={mac}

    [Network]
    Address={ip}/{prefix}
    Gateway={gateway}
    DNS={dns}
    DHCP=no
    EOF
runcmd:
  - rm -f /etc/systemd/network/10-dhcp-all-ether.network
  - systemctl restart systemd-networkd
  - sleep 3
  - /usr/local/sbin/proxmox-bootstrap-hosts || true
"""

Path(path).write_text(json.dumps(configdrive), encoding="utf-8")
PY

image_id="$(env -u OS_SYSTEM_SCOPE "${OPENSTACK}" image show proxmox -c id -f value)"
echo "==> Setting Proxmox image ${image_id} on ${NODE}"
env -u OS_SYSTEM_SCOPE "${OPENSTACK}" baremetal node set "${NODE}" \
    --instance-info "image_source=${image_id}" \
    --instance-info image_disk_format=raw \
    --instance-info root_gb=119

if [[ -n "${PROXMOX_IP}" ]]; then
    echo "==> Deploying ${NODE} with static first-boot IP ${PROXMOX_IP}/${PROXMOX_PREFIX} on MAC ${mac_address}"
else
    echo "==> Deploying ${NODE} with DHCP first-boot networking"
fi

env -u OS_SYSTEM_SCOPE "${OPENSTACK}" baremetal node deploy "${NODE}" \
    --config-drive "${configdrive}"

echo "==> Waiting for Ironic to mark ${NODE} active"
deadline=$((SECONDS + 7200))
while true; do
    state="$(env -u OS_SYSTEM_SCOPE "${OPENSTACK}" baremetal node show "${NODE}" -c provision_state -f value)"
    last_error="$(env -u OS_SYSTEM_SCOPE "${OPENSTACK}" baremetal node show "${NODE}" -c last_error -f value || true)"
    printf "    provision_state=%s\n" "${state}"
    if [[ "${state}" == "active" ]]; then
        break
    fi
    if [[ "${state}" == "deploy failed" || "${state}" == "error" ]]; then
        echo "${last_error}"
        exit 1
    fi
    if [[ ${SECONDS} -ge ${deadline} ]]; then
        echo "Timed out waiting for Ironic active state"
        exit 1
    fi
    sleep 20
done

if [[ -z "${ANSIBLE_HOST}" || "${ANSIBLE_HOST}" == "${NODE}" ]]; then
    inventory_ansible_host="$(
        ANSIBLE_LOCAL_TEMP=/private/tmp/ansible-local TMPDIR=/private/tmp \
            ansible-inventory "${ANSIBLE_INVENTORY_ABS[@]}" --host "${NODE}" 2>/dev/null \
        | python3 -c 'import json, sys; print(json.load(sys.stdin).get("ansible_host", ""))'
    )"
    if [[ -n "${inventory_ansible_host}" ]]; then
        ANSIBLE_HOST="${inventory_ansible_host}"
    fi
fi

echo "==> Waiting for SSH on root@${ANSIBLE_HOST}"
ssh-keygen -R "${ANSIBLE_HOST}" >/dev/null 2>&1 || true
deadline=$((SECONDS + 900))
until ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 "root@${ANSIBLE_HOST}" true; do
    if [[ ${SECONDS} -ge ${deadline} ]]; then
        echo "Timed out waiting for SSH on ${ANSIBLE_HOST}"
        exit 1
    fi
    sleep 10
done

echo "==> Running Proxmox baseline on ${ANSIBLE_HOST}"
(
    cd "${ANSIBLE_DIR}"
    ANSIBLE_LOCAL_TEMP=/private/tmp/ansible-local TMPDIR=/private/tmp \
        ansible-playbook "${ANSIBLE_INVENTORY[@]}" "playbooks/proxmox-baseline.yaml" \
        --limit "${NODE}" \
        -e target_hosts=proxmox_nodes \
        -e ansible_host="${ANSIBLE_HOST}" \
        -e ansible_user=root
)
