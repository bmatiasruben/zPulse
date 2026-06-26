#!/bin/bash
set -e

# ── zPulse installer ─────────────────────────────────────────────────────────
# Usage: curl -sSL https://raw.githubusercontent.com/bmatiasruben/zPulse/main/install.sh | sudo bash
# Run as root on a fresh Pynq/Ubuntu 20.04 board

REPO="https://github.com/bmatiasruben/zPulse"
PYNQ_VENV="/usr/local/share/pynq-venv"

# ── Target directories ────────────────────────────────────────────────────────
CLONE_DIR="/home/ubuntu/zPulse_src"
WEBSERVER_DIR="/home/ubuntu/Webserver"
JUPYTER_ROOT="/home/root/jupyter_notebooks"
JUPYTER_ZPULSE="$JUPYTER_ROOT/zPulse"

echo "══════════════════════════════════════"
echo "  zPulse Installer"
echo "══════════════════════════════════════"

# ── 1. Dependencies ───────────────────────────────────────────────────────────
echo "[1/7] Installing dependencies..."
apt-get update -qq
apt-get install -y -qq git build-essential i2c-tools curl jq

# ── 2. Clone repo ─────────────────────────────────────────────────────────────
echo "[2/7] Cloning repository..."
if [ -d "$CLONE_DIR" ]; then
    echo "  Directory exists, pulling latest..."
    cd "$CLONE_DIR" && git pull
else
    git clone --recurse-submodules "$REPO" "$CLONE_DIR"
fi

# ── 3. Download latest bitstream release assets ───────────────────────────────
echo "[3/7] Downloading latest bitstream release..."
mkdir -p "$WEBSERVER_DIR/zPulse/Bitstream"
mkdir -p "$JUPYTER_ZPULSE/Bitstream"

LATEST_TAG=$(curl -s "https://api.github.com/repos/bmatiasruben/zPulse/releases/latest" | jq -r '.tag_name')
echo "  Latest release: $LATEST_TAG"

ASSETS=$(curl -s "https://api.github.com/repos/bmatiasruben/zPulse/releases/latest" \
    | jq -r '.assets[] | select(.name | test("\\.(bit|hwh)$")) | .browser_download_url')

if [ -z "$ASSETS" ]; then
    echo "  WARNING: No .bit/.hwh files found in latest release."
else
    for URL in $ASSETS; do
        FILENAME=$(basename "$URL")
        echo "  Downloading $FILENAME..."
        curl -L --progress-bar "$URL" -o "/tmp/$FILENAME"
        cp "/tmp/$FILENAME" "$WEBSERVER_DIR/zPulse/Bitstream/$FILENAME"
        cp "/tmp/$FILENAME" "$JUPYTER_ZPULSE/Bitstream/$FILENAME"
    done
fi

# ── 4. Deploy web server ──────────────────────────────────────────────────────
echo "[4/7] Deploying web server to $WEBSERVER_DIR..."
cp -r "$CLONE_DIR/Webserver/." "$WEBSERVER_DIR/"

# Copy the authoritative overlay into the webserver's zPulse package
mkdir -p "$WEBSERVER_DIR/zPulse"
cp "$CLONE_DIR/Pynq/zPulse_overlay.py" "$WEBSERVER_DIR/zPulse/zPulse_overlay.py"

# ── 5. Deploy Jupyter files ───────────────────────────────────────────────────
echo "[5/7] Deploying Jupyter files to $JUPYTER_ROOT..."
mkdir -p "$JUPYTER_ZPULSE/Clocking"

cp "$CLONE_DIR/Pynq/zPulse_overlay.py" "$JUPYTER_ZPULSE/zPulse_overlay.py"
cp "$CLONE_DIR/Pynq/zPulse_GUI.ipynb"  "$JUPYTER_ROOT/zPulse_GUI.ipynb"
cp "$CLONE_DIR/Pynq/si570_usr_mgt_100mhz.c" "$JUPYTER_ZPULSE/Clocking/si570_usr_mgt_100mhz.c"

echo "  Compiling Si570 clock utility..."
gcc -Wall -O2 \
    -o "$JUPYTER_ZPULSE/Clocking/si570_usr_mgt_100mhz" \
    "$JUPYTER_ZPULSE/Clocking/si570_usr_mgt_100mhz.c"

# ── 6. Find I2C bus and set up Si570 service ──────────────────────────────────
echo "[6/7] Setting up Si570 clock service..."
BUS_MGT=$(i2cdetect -l 2>/dev/null | grep "i2c-1-mux (chan_id 3)" | awk '{print $1}' | sed 's/i2c-//')

if [ -z "$BUS_MGT" ]; then
    echo "  WARNING: Could not auto-detect I2C bus for Si570."
    echo "  After install, run: i2cdetect -l"
    echo "  Find 'i2c-1-mux (chan_id 3)' and update BUS_MGT in:"
    echo "  /etc/systemd/system/si570-mgt-100mhz.service"
    echo "  Then: systemctl daemon-reload && systemctl restart si570-mgt-100mhz"
    BUS_MGT="CHANGE_ME"
fi

SI570_BIN="$JUPYTER_ZPULSE/Clocking/si570_usr_mgt_100mhz"

cat > /etc/systemd/system/si570-mgt-100mhz.service << EOF
[Unit]
Description=Set USER MGT Si570 (U56) to 100 MHz after boot
After=multi-user.target

[Service]
Type=oneshot
ExecStart=$SI570_BIN $BUS_MGT

[Install]
WantedBy=multi-user.target
EOF

# ── 7. Install Flask and set up web server service ────────────────────────────
echo "[7/7] Installing Flask and setting up web server..."
"$PYNQ_VENV/bin/pip" install flask --quiet

cat > /home/ubuntu/start_zpulse.sh << EOF
#!/bin/bash
export PATH=$PYNQ_VENV/bin:\$PATH
source /etc/environment 2>/dev/null || true
cd $WEBSERVER_DIR
exec $PYNQ_VENV/bin/python3 app.py
EOF

chmod +x /home/ubuntu/start_zpulse.sh

cat > /etc/systemd/system/zpulse.service << EOF
[Unit]
Description=zPulse Web Server
After=network-online.target si570-mgt-100mhz.service
Wants=network-online.target

[Service]
Type=simple
User=root
ExecStart=/home/ubuntu/start_zpulse.sh
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable si570-mgt-100mhz.service
systemctl enable zpulse.service
systemctl start si570-mgt-100mhz.service
systemctl start zpulse.service

# ── Done ──────────────────────────────────────────────────────────────────────
IP=$(hostname -I | awk '{print $1}')
echo ""
echo "══════════════════════════════════════"
echo "  Installation complete!"
echo ""
echo "  Web UI:    http://$IP:5000"
echo "  Jupyter:   http://$IP:9090"
echo ""
echo "  Web server: $WEBSERVER_DIR"
echo "  Jupyter:    $JUPYTER_ROOT"
if [ "$BUS_MGT" = "CHANGE_ME" ]; then
echo ""
echo "  ⚠  ACTION REQUIRED: Si570 bus not detected."
echo "  Run: i2cdetect -l"
echo "  Find the line with 'i2c-1-mux (chan_id 3)'"
echo "  Edit /etc/systemd/system/si570-mgt-100mhz.service"
echo "  Then: systemctl daemon-reload && systemctl restart si570-mgt-100mhz"
fi
echo "══════════════════════════════════════"