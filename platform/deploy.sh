#!/usr/bin/env bash
set -Eeuo pipefail

setup_colors() {
  if [[ -t 2 ]] && [[ -z "${NO_COLOR-}" ]] && [[ "${TERM-}" != "dumb" ]]; then
    NOFORMAT='\033[0m' RED='\033[0;31m' GREEN='\033[0;32m' ORANGE='\033[0;33m'
    BLUE='\033[0;34m' PURPLE='\033[0;35m' CYAN='\033[0;36m' YELLOW='\033[1;33m'
  else
    NOFORMAT='' RED='' GREEN='' ORANGE='' BLUE='' PURPLE='' CYAN='' YELLOW=''
  fi
}

msg() {
  echo >&2 -e "${1-}"
}

setup_colors

APP_NAME="${1-}"
SRC_DIR="${2-}"
PORT="${3-}"
APP_DIR="/var/www/$APP_NAME"
START_COMMAND="/usr/bin/npm start"
RUN_AS_USER="vagrant"

if [ -z "$APP_NAME" ] || [ -z "$SRC_DIR" ] || [ -z "$PORT" ]; then
  msg "${RED}usage: deploy.sh <app-name> <source-dir> <port>${NOFORMAT}"
  exit 1
fi

msg "Starting ${GREEN}$APP_NAME${NOFORMAT} on port ${GREEN}$PORT${NOFORMAT}"
msg "Copying code to ${GREEN}$APP_DIR${NOFORMAT}"

sudo rm -rf "$APP_DIR"
sudo mkdir -p "$APP_DIR"
sudo cp -r "$SRC_DIR"/. "$APP_DIR"
sudo chown -R "$RUN_AS_USER:$RUN_AS_USER" "$APP_DIR"

cd "$APP_DIR"
sudo -u "$RUN_AS_USER" npm install --omit=dev

msg "${GREEN}Making systemd service${NOFORMAT}"

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

msg "${GREEN}Restarting${NOFORMAT}"
sudo systemctl daemon-reload
sudo systemctl enable "$APP_NAME"
sudo systemctl restart "$APP_NAME"

msg "${GREEN}Checking health${NOFORMAT}"
success="false"
for i in {1..5}; do
  if curl -fs -o /dev/null "localhost:$PORT"; then
    success="true"
    break
  else
    msg "${YELLOW}App not responding yet, attempt $i/5${NOFORMAT}"
    sleep 1
  fi
done

if [ "$success" != "true" ]; then
  msg "${RED}DEPLOY FAILED: app not responding on port $PORT${NOFORMAT}"
  msg "Check logs: journalctl -u $APP_NAME -n 50"
  exit 1
fi

msg "${GREEN}Deployed $APP_NAME on port $PORT${NOFORMAT}"