#!/usr/bin/env bash
# Install Nextcloud (Snap) and Tailscale, then publish Nextcloud over HTTPS on
# your tailnet with `tailscale serve`.
#
# Usage: bash scripts/02-nextcloud-tailscale.sh
set -euo pipefail

echo "=== [1/4] Installing Snapd and Nextcloud ==="
sudo apt update
sudo apt install snapd -y
sudo snap install nextcloud

echo "=== Checking Nextcloud Snap services ==="
sudo snap services

LOCAL_IP=$(hostname -I | awk '{print $1}')
echo ""
echo "----------------------------------------------------------------"
echo "IMPORTANT: Before continuing, open http://${LOCAL_IP} in your"
echo "browser and create your Nextcloud admin account!"
echo "----------------------------------------------------------------"
read -r -p "Press [Enter] once you have initialized the Nextcloud web dashboard..."

echo "=== [2/4] Installing Tailscale ==="
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up

echo ""
read -r -p "Enter your Pi's Tailscale DNS name (e.g., picloud.tailxxxx.ts.net): " TS_DNS

if [[ -z "$TS_DNS" ]]; then
    echo "Error: Tailscale DNS name cannot be empty." >&2
    exit 1
fi

echo "=== [3/4] Configuring Nextcloud trusted proxies and domains ==="
sudo snap run nextcloud.occ config:system:set trusted_proxies 0 --value=127.0.0.1
sudo snap run nextcloud.occ config:system:set overwriteprotocol --value=https
sudo snap run nextcloud.occ config:system:set trusted_domains 2 --value="$TS_DNS"

echo "=== [4/4] Starting Tailscale HTTPS serve ==="
sudo tailscale serve --bg --https=443 http://localhost:80

echo ""
echo "Setup complete! You can now access Nextcloud from any device on your tailnet at:"
echo "https://${TS_DNS}"
