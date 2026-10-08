#!/bin/bash
set -e
source "$(dirname "$0")/config.sh"

sudo apt-get update -y
sudo apt-get install -y nodejs npm