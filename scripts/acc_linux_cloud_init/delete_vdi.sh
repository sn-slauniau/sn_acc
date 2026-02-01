#!/bin/bash
# Configuration
CONNECT="qemu:///session"

for i in {1..3}; do
    NAME="vdi-client-$i"
    OVERLAY="$NAME.qcow2"
    SEED="$NAME-seed.iso"

    # 1. Wipe old data and create a fresh overlay
    # Changes to this file are deleted manually or by re-running this script
    
    # Force-remove any existing VM with this name before starting
    virsh --connect "$CONNECT" destroy "$NAME" >/dev/null 2>&1
    virsh --connect "$CONNECT" undefine "$NAME" >/dev/null 2>&1

    rm -f "$OVERLAY" "$SEED"
done

