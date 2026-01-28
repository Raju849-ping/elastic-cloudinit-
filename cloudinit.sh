#!/bin/bash
set -euo pipefail

LOG_FILE="/var/log/elastic-cloudinit.log"
INSTALL_BASE="/opt/elastic"
INSTALL_DIR="${INSTALL_BASE}/elastic-cloudinit"
TMP_DIR="/opt/elastic/.elastic-cloudinit-tmp"
REPO_URL="https://github.com/Raju849-ping/elastic-cloudinit-.git"

exec > >(tee -a "${LOG_FILE}") 2>&1

echo "==== Elastic CloudInit Started ===="
echo "Running as user: $(whoami)"
echo "PH value: ${PH:-dev}"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "ERROR: cloudinit.sh must be run as root"
  exit 1
fi

### Ensure base directory exists
mkdir -p "${INSTALL_BASE}"
chmod 0755 "${INSTALL_BASE}"

### Ensure /var/tmp usable
chmod 1777 /var/tmp
echo "${PH:-dev}" > /var/tmp/PH

install_prereqs() {
  echo "▶ Installing prerequisites"
  apt-get update -y
  apt-get install -y git ansible curl lvm2
}

clone_repo() {
  echo "▶ Cloning repository safely"

  rm -rf "${TMP_DIR}"
  git clone "${REPO_URL}" "${TMP_DIR}"

  rm -rf "${INSTALL_DIR}"
  mv "${TMP_DIR}" "${INSTALL_DIR}"
}

run_playbooks() {
  echo "▶ Running Ansible playbooks"
  cd "${INSTALL_DIR}"

  ansible-playbook -i localhost, -c local playbooks_elastic/elastic_create_users.yml
  ansible-playbook -i localhost, -c local playbooks_elastic/elastic_setlimits.yml
  ansible-playbook -i localhost, -c local playbooks_elastic/elastic_setkernel.yml
  ansible-playbook -i localhost, -c local playbooks_elastic/elastic_add_ssh_keys.yml -e "PH=$PH"
  ansible-playbook -i localhost, -c local playbooks_elastic/elastic_installrpms.yml
  ansible-playbook -i localhost, -c local playbooks_elastic/elastic_config.yml
  ansible-playbook -i localhost, -c local playbooks_elastic/elastic_service.yml
}

install_prereqs
clone_repo
run_playbooks

touch /var/tmp/elastic_cloudinit_complete
echo "==== Elastic CloudInit Completed Successfully ===="
