#!/bin/bash

set -e
source "$(dirname "$0")/config.sh"

if [ "$#" -ne 2 ]; then
    echo "usage: $0 <app-name> <port>"
    exit 1
fi

APP_NAME="$1"
PORT="$2"
REPO_PATH="$HOME/${APP_NAME}.git"
HOOK_SRC="/vagrant/platform/post-receive"
HOOK_DEST="$REPO_PATH/hooks/post-receive"

if ! [[ "$APP_NAME" =~ ^[a-z0-9-]+$ ]]; then
    echo "error: app name may contain only lowercase letters, digits and dashes"
    exit 1
fi

if ! [[ "$PORT" =~ ^[0-9]+$ ]]; then
    echo "error: port must be a number"
    exit 1
fi

if [ -e "$REPO_PATH" ]; then
    echo "error: app '$APP_NAME' already exists at $REPO_PATH"
    exit 1
fi

if [ ! -f "$HOOK_SRC" ]; then
    echo "error: hook template not found at $HOOK_SRC"
    exit 1
fi

git init --bare --quiet "$REPO_PATH"

cp "$HOOK_SRC" "$HOOK_DEST"
chmod +x "$HOOK_DEST"

git -C "$REPO_PATH" config paas.port "$PORT"

echo "app '$APP_NAME' created on port $PORT"
echo "add remote on your Mac:"
echo "  git remote add paas paas:${APP_NAME}.git"