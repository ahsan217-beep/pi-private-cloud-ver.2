# Raspberry Pi 5 Private Cloud, ver.2 (Nextcloud + Tailscale on NVMe)

A reproducible setup guide and automation scripts to build a self-hosted private cloud on a Raspberry Pi 5 booting from an M.2 NVMe SSD, using **Nextcloud** (via Snap) and **Tailscale** for encrypted remote access from anywhere, without port forwarding or subscriptions.

Based on the setup from Enrique Neyra's video [Access Your Files ANYWHERE You Go — The Ultimate Pi 5 Setup](https://www.youtube.com/watch?v=jOYG10CvZZA). The cloning step uses Jeff Geerling's [rpi-clone](https://github.com/geerlingguy/rpi-clone).

---

## How ver.2 differs from ver.1

[ver.1 (pi-private-cloud)](https://github.com/ahsan217-beep/pi-private-cloud) builds the same idea, a private Nextcloud reachable over Tailscale, as a Docker Compose stack. ver.2 trades that flexibility for a simpler install on Raspberry Pi 5 hardware.

| | ver.1: pi-private-cloud | ver.2: this repo |
|---|---|---|
| Hardware | Raspberry Pi 4 or 5 + USB 3 SSD | Raspberry Pi 5 + M.2 NVMe HAT and SSD |
| Where the OS runs | MicroSD card (data, database and Nextcloud files on the SSD) | NVMe SSD (the whole system is cloned off the MicroSD card) |
| How Nextcloud is installed | Docker Compose: Nextcloud, PostgreSQL, Redis, cron and Tailscale as separate containers | Nextcloud Snap: one package that bundles the web server, PHP, database and cache |
| Tailscale | Runs in a container, joins with an auth key from `.env` | Installed on the Pi itself, joins with an interactive `tailscale up` login |
| Configuration | Config files and a `.env` file, no prompts | Two interactive scripts that follow the guide step by step |
| Updates | Nextcloud image pinned to one major version, upgraded by hand | The Snap updates itself automatically |
| Backups | `backup.sh` (maintenance mode, database dump, rsync) | Not scripted yet |
| Extra system change | None | Switches the Pi 5 to the 4K page-size kernel (`kernel=kernel8.img`) for the Snap |
| Best for | Seeing and controlling every part of the stack | Getting a working cloud on a Pi 5 with the fewest steps |

---

## Hardware Requirements

* **Raspberry Pi 5** (4 GB RAM minimum recommended)
* **Pi 5 Active Cooler** and bumper case (or an all-in-one NVMe case like the Argon NEO 5)
* **Pi 5 M.2 NVMe HAT** + PCIe ribbon cable
* **M.2 NVMe SSD**
* **MicroSD card** (used only for initial flashing and cloning)
* **27 W USB-C power supply**

---

## Step 1: Flash the MicroSD Card

1. Download and open **Raspberry Pi Imager** on your computer.
2. Select **Raspberry Pi 5** as the device and **Raspberry Pi OS (64-bit)** as the OS.
3. Choose your MicroSD card as the storage target.
4. Configure OS customisation:
   * **Hostname:** `picloud` (or your preferred hostname)
   * **Localisation:** set your capital city, timezone and keyboard layout
   * **User:** set a username (e.g. `pi`) and a strong password
   * **Wi-Fi:** enter your local Wi-Fi SSID and password
   * **Remote access:** enable **SSH** (password authentication)
   * **Raspberry Pi Connect:** leave off
5. Write the image to the MicroSD card, insert it into the Pi 5, and plug in the USB-C power supply.

---

## Step 2: Clone the OS from MicroSD to NVMe

Wait 2–3 minutes for the Pi to boot, then connect via SSH from your computer:

```bash
ssh pi@picloud.local
```

Copy this repository onto the Pi (for example with `git clone`), then run:

```bash
bash scripts/01-nvme-clone.sh
```

Or run the commands by hand:

```bash
# 1. Switch to the 4K page-size kernel (needed by the Nextcloud Snap on Pi 5)
echo "kernel=kernel8.img" | sudo tee -a /boot/firmware/config.txt

# 2. Install Jeff Geerling's rpi-clone
curl -fsSL https://raw.githubusercontent.com/geerlingguy/rpi-clone/master/install | sudo bash

# 3. Clone the MicroSD card to the NVMe drive
sudo rpi-clone nvme0n1
```

Type `yes` when prompted to confirm cloning, and press `Enter` when prompted to unmount partitions.

### Change the boot order to NVMe

1. Run `sudo raspi-config`.
2. Go to **6 Advanced Options → A4 Boot Order → B2 NVMe/USB Boot**.
3. Select **OK → Finish**, and select **No** when asked to reboot.
4. Unplug the power cable, remove the MicroSD card, and plug the power cable back in.

---

## Step 3: Install Nextcloud and Tailscale

Once the Pi boots from the NVMe drive, SSH back in (`ssh pi@picloud.local`) and run:

```bash
bash scripts/02-nextcloud-tailscale.sh
```

The script pauses twice: once for you to create the Nextcloud admin account in your browser, and once for you to enter your Pi's Tailscale DNS name. The manual equivalent is below.

### 3.1 Install Nextcloud via Snap

```bash
sudo apt update && sudo apt install snapd -y
sudo snap install nextcloud
sudo snap services
```

### 3.2 Create the Nextcloud admin account locally

1. Find your Pi's local IP address:

   ```bash
   hostname -I
   ```

2. Open `http://<YOUR-PI-LOCAL-IP>` in your browser.
3. Create your Nextcloud administrator username and password and click **Install**.

### 3.3 Install and authenticate Tailscale

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
```

* Open the authentication URL printed in the terminal, sign in, and authorise the Pi.
* In the Tailscale admin console (**Machines** tab), expand your Pi's entry and copy its full Tailscale DNS name (e.g. `picloud.tailxxxx.ts.net`).
* Make sure **MagicDNS** and **HTTPS Certificates** are enabled under **DNS** in the admin console, or `tailscale serve` cannot issue a certificate.

### 3.4 Connect Nextcloud and Tailscale (trusted domain and HTTPS proxy)

Replace `<YOUR-TAILSCALE-DNS-NAME>` with your `.ts.net` address and run:

```bash
# Trust the local Tailscale proxy
sudo snap run nextcloud.occ config:system:set trusted_proxies 0 --value=127.0.0.1
sudo snap run nextcloud.occ config:system:set overwriteprotocol --value=https

# Add the Tailscale MagicDNS name as a trusted domain
sudo snap run nextcloud.occ config:system:set trusted_domains 2 --value="<YOUR-TAILSCALE-DNS-NAME>"

# Serve Nextcloud over HTTPS on your tailnet, in the background
sudo tailscale serve --bg --https=443 http://localhost:80
```

---

## Step 4: Connect Client Devices (Mac, Windows, iOS, Android)

1. Install Tailscale on your computer or phone and sign in to the same Tailscale account.
2. Install the Nextcloud Desktop app (use the Virtual Files version on macOS) or the Nextcloud mobile app.
3. When prompted for the server address, enter `https://<YOUR-TAILSCALE-DNS-NAME>` and grant access.

---

## Notes

* Both install steps pipe a script from the internet into `sudo bash` (rpi-clone and Tailscale). Read them first if you prefer: [rpi-clone installer](https://github.com/geerlingguy/rpi-clone/blob/master/install), [Tailscale installer](https://tailscale.com/install.sh).
* The Snap version of Nextcloud also listens on plain HTTP on your local network. Remote access goes only through Tailscale.
* `rpi-clone` overwrites everything on the target drive. Double-check that `nvme0n1` is the drive you mean to erase.
