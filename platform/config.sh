#!/bin/bash

set -e

PLATFORM_DIR="${PLATFORM_DIR:-/vagrant/platform}"
RUN_AS_USER="${RUN_AS_USER:-vagrant}"
APPS_DIR="${APPS_DIR:-/var/www}"
REPOS_DIR="${REPOS_DIR:-$HOME}"
BUILD_DIR="${BUILD_DIR:-/tmp}"
DEPLOY_BRANCH="${DEPLOY_BRANCH:-main}"