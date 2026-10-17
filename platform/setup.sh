#!/bin/bash
set -euo pipefail
# shellcheck source=platform/config.sh
source "$(dirname "$0")/config.sh"

sudo apt-get update -y
sudo apt-get install -y docker.io

