#!/bin/bash

_err() {
    echo "$*" > /tmp/ErrorLog.out
    mail -s "Elastic VM Init Failure on host $HOSTNAME" \
        noreplyalert377@gmail.com < /tmp/ErrorLog.out
    exit 1
}

elastic_cloudinit_repo() {

    cdb_cloudinit_git_url="https://github.com/Raju849-ping/elastic-cloudinit-"
    cdb_cloudinit_loc="/opt/elastic/elastic-cloudinit-"

    mkdir -p /opt/elastic
    mkdir -p /opt/softwares/rpms/

    if [ -d "$cdb_cloudinit_loc/.git" ]; then
        echo "elastic-cloudinit repo already exists, pulling latest changes"
        cd "$cdb_cloudinit_loc" || _err "ERROR: cd failed"
        git pull || _err "ERROR: git pull failed ($?)"
    else
        git clone "$cdb_cloudinit_git_url" "$cdb_cloudinit_loc" \
            || _err "ERROR : elastic-cloudinit git clone failed ($?)"
    fi

    chmod -R 755 "$cdb_cloudinit_loc"
}

elastic_playbooks() {

    if [[ -f /etc/lsb-release ]]; then
        osversion='ubuntu'
    else
        osversion='unknown'
    fi

    elastic_ansible_loc="/opt/elastic/elastic-cloudinit-/playbooks_elastic"

    ansible-playbook "$elastic_ansible_loc/elastic_create_users.yml" \
        || _err "ERROR: install_users failed ($?)"

    ansible-playbook "$elastic_ansible_loc/elastic_setkernel.yml" \
        || _err "ERROR: set_kernel failed ($?)"

    ansible-playbook "$elastic_ansible_loc/elastic_setlimits.yml" \
        || _err "ERROR: set_limit failed ($?)"

    ansible-playbook "$elastic_ansible_loc/elastic_installrpms.yml" \
        || _err "ERROR: setup_ssh_keys failed ($?)"

    ansible-playbook "$elastic_ansible_loc/elastic_config.yml" \
        || _err "ERROR: elastic_configuration failed ($?)"
}

elastic_cleanup() {
    rm -rf /opt/elastic/elastic-cloudinit
}

install_git() {

    echo "Installing required packages..."

    dpkg -l | grep -qw git
    if [ $? != 0 ]; then
        apt-get update -y || _err "ERROR: apt update failed"
        apt-get install -y git ansible lvm2 mailutils \
            || _err "ERROR: apt-get install failed ($?)"
    fi
}

disk_config() {

    echo "Configuring LVM disks for Ubuntu practice VM (5GB)"

    # ---- Disk sizes (MB) ----
    elastic_size=1000
    product_size=2000
    log_size=2000
    audit_size=1000
    data_size=16000

    # Prevent accidental re-format
    if vgdisplay vgelastic >/dev/null 2>&1; then
        echo "LVM already exists, skipping disk configuration"
        return
    fi

    umount /mnt 2>/dev/null

    pvcreate /dev/sdb || _err "ERROR: pvcreate failed"
    vgcreate vgelastic /dev/sdb || _err "ERROR: vgcreate failed"

    lvcreate -L ${elastic_size}M -n elastic vgelastic || _err "lvcreate elastic failed"
    lvcreate -L ${product_size}M -n elastic_product vgelastic || _err "lvcreate product failed"
    lvcreate -L ${log_size}M -n elastic_log vgelastic || _err "lvcreate log failed"
    lvcreate -L ${audit_size}M -n elastic_auditlog vgelastic || _err "lvcreate audit failed"
    lvcreate -L ${data_size}M -n elastic_data vgelastic || _err "lvcreate data failed"

    mkfs.ext4 /dev/vgelastic/elastic
    mkfs.ext4 /dev/vgelastic/elastic_product
    mkfs.ext4 /dev/vgelastic/elastic_log
    mkfs.ext4 /dev/vgelastic/elastic_auditlog
    mkfs.ext4 /dev/vgelastic/elastic_data

    mkdir -p /elastic /elastic/product /elastic/data /elastic/log /elastic/auditlog

    mount /dev/vgelastic/elastic /elastic
    mount /dev/vgelastic/elastic_product /elastic/product
    mount /dev/vgelastic/elastic_data /elastic/data
    mount /dev/vgelastic/elastic_log /elastic/log
    mount /dev/vgelastic/elastic_auditlog /elastic/auditlog

    echo "/dev/vgelastic/elastic /elastic ext4 defaults 0 2" >> /etc/fstab
    echo "/dev/vgelastic/elastic_product /elastic/product ext4 defaults 0 2" >> /etc/fstab
    echo "/dev/vgelastic/elastic_data /elastic/data ext4 defaults 0 2" >> /etc/fstab
    echo "/dev/vgelastic/elastic_log /elastic/log ext4 defaults 0 2" >> /etc/fstab
    echo "/dev/vgelastic/elastic_auditlog /elastic/auditlog ext4 defaults 0 2" >> /etc/fstab
}

##### MAIN EXECUTION FLOW #####

install_git
elastic_cloudinit_repo
disk_config
elastic_playbooks
elastic_cleanup

mkdir -p /var/lib/elastic-init
touch /var/lib/elastic-init/node_ready
