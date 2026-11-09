#!/usr/bin/env bash
# Prepare the kernel for the Nextcloud Snap, then clone the running MicroSD
# system onto the NVMe drive with rpi-clone.
#
# Usage: bash scripts/01-nvme-clone.sh
set -euo pipefail

CONFIG=/boot/firmware/config.txt
TARGET=nvme0n1

if [[ ! -b "/dev/$TARGET" ]]; then
    echo "Error: /dev/$TARGET not found. Check the NVMe HAT and ribbon cable, then reboot." >&2
    exit 1
fi

echo "=== [1/3] Configuring kernel=kernel8.img for Nextcloud Snap compatibility ==="
if ! grep -q "^kernel=kernel8.img" "$CONFIG"; then
    echo "kernel=kernel8.img" | sudo tee -a "$CONFIG"
    echo "Added kernel=kernel8.img to $CONFIG"
else
    echo "kernel=kernel8.img is already set."
fi

echo "=== [2/3] Installing rpi-clone ==="
curl -fsSL https://raw.githubusercontent.com/geerlingguy/rpi-clone/master/install | sudo bash

echo "=== [3/3] Cloning MicroSD to NVMe ($TARGET) ==="
echo "This ERASES everything on /dev/$TARGET."
sudo rpi-clone "$TARGET"

echo ""
echo "Clone complete! Next steps:"
echo "1. Run: sudo raspi-config"
echo "2. Go to: 6 Advanced Options -> A4 Boot Order -> B2 NVMe/USB Boot"
echo "3. Select Finish, do NOT reboot, unplug power, remove the MicroSD card, and power back on."
