#!/bin/bash

set -e

APP_NAME="my-awesome-app"
APP_DIR="/var/www/$APP_NAME"
SRC_DIR="/vagrant" # git clone
START_COMMAND="/usr/bin/npm start"   
RUN_AS_USER="vagrant"              

echo "starting $APP_NAME..."
sudo apt-get update -y
sudo apt-get install -y nodejs npm

echo "copying code $APP_DIR..."
sudo mkdir -p "$APP_DIR"
sudo cp -r "$SRC_DIR"/. "$APP_DIR"

sudo chown -R $RUN_AS_USER:$RUN_AS_USER "$APP_DIR"

cd "$APP_DIR"
sudo -u $RUN_AS_USER npm install --production

echo "making systemd service..."
SERVICE_FILE="/etc/systemd/system/$APP_NAME.service"

sudo bash -c "cat > $SERVICE_FILE" <<EOF
[Unit]
Description=Systemd service for $APP_NAME
After=network.target

[Service]
Type=simple
User=$RUN_AS_USER
WorkingDirectory=$APP_DIR
ExecStart=$START_COMMAND
Restart=on-failure
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF

echo "Restarting"
sudo systemctl daemon-reload
sudo systemctl enable "$APP_NAME"
sudo systemctl restart "$APP_NAME"

echo "started"
echo "status"
sudo systemctl status "$APP_NAME" --no-pager
