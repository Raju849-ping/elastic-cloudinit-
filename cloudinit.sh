#!/bin/bash
set -euo pipefail

### ---------- FUNCTIONS ----------
ERR() {
  echo "❌ $*" | tee /tmp/error.log
  exit 1
}

### ---------- ROOT CHECK ----------
if [[ $EUID -ne 0 ]]; then
  echo "❌ This script must be run as root"
  exit 1
fi

### ---------- FIX TMP PERMS ----------
chmod 1777 /var/tmp

### ---------- ENV ----------
PH=${PH:-dev}
echo "$PH" > /var/tmp/PH

### ---------- VARS ----------
REPO_URL="https://github.com/Raju849-ping/elastic-cloudinit-.git"
INSTALL_DIR="/opt/elastic/elastic-cloudinit"
LOG="/var/log/elastic-cloudinit.log"

exec > >(tee -a "$LOG") 2>&1

echo "▶ Elastic cloudinit started (PH=$PH)"

### ---------- FUNCTIONS ----------
install_prereqs () {
  echo "▶ Installing prerequisites"
  apt-get update -y
  apt-get install -y git ansible curl lvm2
}

clone_repo () {
  echo "▶ Cloning repository"
  rm -rf "$INSTALL_DIR"
  mkdir -p /opt/elastic
  git clone "$REPO_URL" "$INSTALL_DIR" || ERR "Git clone failed"
}

run_playbooks () {
  echo "▶ Running Ansible playbooks"
  cd "$INSTALL_DIR"

  ansible-playbook -i inventory/hosts.ini playbooks_elastic/elastic_create_users.yml
  ansible-playbook -i inventory/hosts.ini playbooks_elastic/elastic_setlimits.yml
  ansible-playbook -i inventory/hosts.ini playbooks_elastic/elastic_setkernel.yml
  ansible-playbook -i inventory/hosts.ini playbooks_elastic/elastic_add_ssh_keys.yml -e "PH=$PH"
  ansible-playbook -i inventory/hosts.ini playbooks_elastic/elastic_installrpms.yml
  ansible-playbook -i inventory/hosts.ini playbooks_elastic/elastic_config.yml
  ansible-playbook -i inventory/hosts.ini playbooks_elastic/elastic_service.yml
}

### ---------- EXECUTION ----------
install_prereqs
clone_repo
run_playbooks

touch /var/tmp/elastic_cloudinit_complete
echo "✅ Elastic cloudinit completed successfully"
