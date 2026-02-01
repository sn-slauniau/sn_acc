#!/bin/bash
# Configuration
BASE_IMG="alma10-base.qcow2"
CONNECT="qemu:///session"
VDI_USER="${VDI_USER:-alma}"
VDI_PWD="${VDI_PWD:-ReplaceThis1}"

for i in {1..3}; do
    NAME="vdi-client-$i"
    OVERLAY="$NAME.qcow2"
    SEED="$NAME-seed.iso"

    # 1. Wipe old data and create a fresh overlay
    # Force-remove any existing VM with this name before starting
    virsh --connect "$CONNECT" destroy "$NAME" >/dev/null 2>&1
    virsh --connect "$CONNECT" undefine "$NAME" >/dev/null 2>&1

    rm -f "$OVERLAY" "$SEED"

    qemu-img create -f qcow2 -F qcow2 -b "$BASE_IMG" "$OVERLAY"

    # 2. Create unique Cloud-Init config for this instance
    cat <<EOF > user-data
#cloud-config
hostname: $NAME
user: $VDI_USER
password: $VDI_PWD
chpasswd: { expire: False }
ssh_pwauth: True

# Set this to false so Cloud-init doesn't overwrite your appends
manage_etc_hosts: false

## If you need to add an entry for your MID, uncomment these lines
# write_files:
#  - path: /etc/hosts
#    append: true
#    content: |
#      172.16.0.100 mid.internal mid
EOF

    # 3. Create meta-data (CRITICAL for Hostname)
    cat <<EOF > meta-data
local-hostname: $NAME
instance-id: $NAME
EOF

    # 4. Generate the seed ISO
    genisoimage -output "$SEED" -volid CIDATA -joliet -rock -input-charset utf-8 user-data meta-data

    # 5. Launch the VM as a TRANSIENT instance
    # Changes made during the session stay in $OVERLAY. 
    # To "Power Cycle and Delete", simply stop the VM and delete the $OVERLAY file.

# --network type=user,model=virtio
# --network network=default,model=virtio
# --disk path="$SEED",device=cdrom \

    virt-install --connect "$CONNECT" \
        --name "$NAME" \
        --memory 2048 \
        --vcpus 2 \
        --disk path="$OVERLAY",format=qcow2 \
	--disk path="$SEED",device=cdrom,readonly=on \
        --import \
        --network type=user,model=virtio \
        --os-variant almalinux9 \
        --graphics none \
        --noautoconsole \
        --transient

    echo "Launched $NAME - Log in via: virsh --connect $CONNECT console $NAME"
done

