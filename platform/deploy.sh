#!/bin/bash
set -e
APP_NAME="$1"
APP_DIR="/var/www/$APP_NAME"
SRC_DIR="$2" 
START_COMMAND="/usr/bin/npm start"   
RUN_AS_USER="vagrant"  
PORT="$3"

if [ -z "$APP_NAME" ] || [ -z "$SRC_DIR" ] || [ -z "$PORT" ]; then
  echo "usage: deploy.sh <app-name> <source-dir> <port>"
  exit 1
fi

echo "starting $APP_NAME..."


echo "copying code $APP_DIR..."
sudo rm -rf "$APP_DIR"
sudo mkdir -p "$APP_DIR"
sudo cp -r "$SRC_DIR"/. "$APP_DIR"

sudo chown -R $RUN_AS_USER:$RUN_AS_USER "$APP_DIR"

cd "$APP_DIR"
sudo -u $RUN_AS_USER npm install --omit=dev

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
Environment=PORT=$PORT

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

sleep 1
success="false"
for i in {1..5}; do
    if curl -f localhost:"$PORT"; then
      success="true"
        break
    else
        success="false"
        echo "Problem, trying again"
        sleep 1
    fi
done
if [ "$success" != true ]; then
    echo "deploy failed: app not responding on port "$PORT""
    exit 1 
fi