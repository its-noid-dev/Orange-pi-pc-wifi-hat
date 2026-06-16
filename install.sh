#!/bin/bash

# Orange Pi PC v1.3 WiFi & TFT Display Auto-Installer
# Developed by Noid.DEV

if [ "$EUID" -ne 0 ]; then
  echo "[-] Please run this script as root: sudo bash install.sh"
  exit 1
fi

echo "[+] Starting installation for Orange Pi PC WiFi & TFT Monitor..."
echo "[+] Updating system packages and installing prerequisites..."
apt-get update && apt-get install -y armbian-config git build-essential conky fbi

# 1. Activate USB Host 2 for the WiFi Chip
echo "[+] Activating USB Host 2 hardware overlay..."
if [ -f /boot/armbianEnv.txt ]; then
    if ! grep -q "usbhost2" /boot/armbianEnv.txt; then
        if grep -q "overlays=" /boot/armbianEnv.txt; then
            sed -i '/overlays=/ s/$/ usbhost2/' /boot/armbianEnv.txt
        else
            echo "overlays=usbhost2" >> /boot/armbianEnv.txt
        fi
        echo "[+] WiFi USB port activated successfully."
    else
        echo "[*] WiFi USB port was already activated."
    fi
fi

# 2. Activate SPI0 for the TFT Screen
echo "[+] Activating SPI0 hardware overlay for the display..."
if [ -f /boot/armbianEnv.txt ]; then
    if ! grep -q "spi0" /boot/armbianEnv.txt; then
        sed -i '/overlays=/ s/$/ spi0/' /boot/armbianEnv.txt
        echo "[+] SPI0 bus activated successfully."
    else
        echo "[*] SPI0 bus was already activated."
    fi
fi

# 3. Configure the fbtft display driver
echo "[+] Configuring display drivers (fbtft)..."
cat <<EOF > /etc/modprobe.d/fbtft.conf
options fbtft_device name=sainsmart18 gpios=reset:7,dc:8 speed=16000000 fps=30 rotate=90
EOF

cat <<EOF > /etc/modules-load.d/fbtft.conf
fbtft_device
EOF

# 4. Generate system monitor (Conky) layout
echo "[+] Setting up system monitor layout..."
mkdir -p /etc/conky
cat <<EOF > /etc/conky/conky_tft.conf
conky.config = {
    alignment = 'top_left',
    background = false,
    border_width = 1,
    cpu_avg_samples = 2,
    default_color = 'white',
    default_outline_color = 'white',
    font = 'DejaVu Sans Mono:size=8',
    gap_x = 5,
    gap_y = 5,
    update_interval = 1.0,
    use_xft = true,
    own_window = true,
    own_window_type = 'desktop',
}

conky.text = [[
\${color yellow}  NOID.DEV MONITOR \${color}
\${hr}
CPU Temp : \${execi 5 cat /sys/class/thermal/thermal_zone0/temp | awk '{print \$1/1000}'}°C
CPU Usage: \${cpu cpu0}%
RAM Usage: \$mem/\$memmax
\${hr}
WiFi IP  : \${addr wlan0}
WiFi Sign: \${wireless_link_qual_perc wlan0}%
]]
EOF

# 5. Create an automatic startup service for the monitor
echo "[+] Creating background service for automatic startup..."
cat <<EOF > /etc/systemd/system/tft-monitor.service
[Unit]
Description=TFT Display System Monitor
After=network.target

[Service]
Type=simple
Environment=FRAMEBUFFER=/dev/fb1
ExecStartPre=/bin/sleep 5
ExecStart=/usr/bin/conky -c /etc/conky/conky_tft.conf -d
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable tft-monitor.service

echo ""
echo "[==================================================================]"
echo "[+] INSTALLATION SUCCESSFUL!"
echo "[+] PLEASE REBOOT THE ORANGE PI TO ACTIVATE EVERYTHING:"
echo "    sudo reboot"
echo "[==================================================================]"
