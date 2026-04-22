#!/bin/bash
# Amirani Gateway — One-command setup for Raspberry Pi
# Run: curl -sSL https://amirani.esme.ge/gateway/install.sh | bash
# Or:  bash install.sh

set -e

echo "======================================"
echo "  Amirani Gateway Installer"
echo "======================================"

# Enable SPI for MFRC522
if ! grep -q "dtparam=spi=on" /boot/config.txt; then
    echo "dtparam=spi=on" | sudo tee -a /boot/config.txt
    echo "[✓] SPI enabled (reboot required)"
fi

# Enable I2C for OLED
if ! grep -q "dtparam=i2c_arm=on" /boot/config.txt; then
    echo "dtparam=i2c_arm=on" | sudo tee -a /boot/config.txt
fi

# Install system dependencies
sudo apt-get update -qq
sudo apt-get install -y python3-pip python3-dev python3-smbus i2c-tools git

# Install Python packages
cd "$(dirname "$0")"
pip3 install -r requirements.txt

# Copy config if not exists
if [ ! -f config.json ]; then
    cp config.example.json config.json
    echo ""
    echo "======================================"
    echo "  ACTION REQUIRED:"
    echo "  Edit config.json and paste your API key"
    echo "  from the Amirani admin dashboard."
    echo "  nano config.json"
    echo "======================================"
fi

# Install as systemd service
SERVICE_FILE="/etc/systemd/system/amirani-gateway.service"
SCRIPT_DIR="$(pwd)"

sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=Amirani Gateway
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=pi
WorkingDirectory=$SCRIPT_DIR
ExecStart=/usr/bin/python3 $SCRIPT_DIR/amirani_gateway.py
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable amirani-gateway
echo "[✓] Gateway service installed (starts on boot)"

echo ""
echo "======================================"
echo "  Setup complete!"
echo ""
echo "  Next steps:"
echo "  1. Edit config.json with your API key"
echo "  2. sudo systemctl start amirani-gateway"
echo "  3. sudo journalctl -fu amirani-gateway   (view logs)"
echo "======================================"
