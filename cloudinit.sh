#!/bin/bash
set -e

ERR() {
  echo "$*" > /tmp/error.log
  exit 1
}

export PH=${PH:-dev}
echo "$PH" | sudo tee /var/tmp/PH >/dev/null

REPO_URL="https://github.com/Raju849-ping/elastic-cloudinit-/edit/main/cloudinit.sh"
INSTALL_DIR="/opt/elastic/elastic-cloudinit"

install_prereqs () {
  apt-get update
  apt-get install -y git ansible curl lvm2
}

clone_repo () {
  rm -rf $INSTALL_DIR
  git clone "$REPO_URL" "$INSTALL_DIR" || ERR "Git clone failed"
}

run_playbooks () {
  cd $INSTALL_DIR
  ansible-playbook -i inventory/hosts.ini playbooks_elastic/elastic_create_users.yml
  ansible-playbook -i inventory/hosts.ini playbooks_elastic/elastic_setlimits.yml
  ansible-playbook -i inventory/hosts.ini playbooks_elastic/elastic_setkernel.yml
  ansible-playbook -i inventory/hosts.ini playbooks_elastic/elastic_add_ssh_keys.yml -e "PH=$PH"
  ansible-playbook -i inventory/hosts.ini playbooks_elastic/elastic_installrpms.yml
  ansible-playbook -i inventory/hosts.ini playbooks_elastic/elastic_config.yml
  ansible-playbook -i inventory/hosts.ini playbooks_elastic/elastic_service.yml
}

install_prereqs
clone_repo
run_playbooks
touch /var/tmp/elastic_cloudinit_complete

