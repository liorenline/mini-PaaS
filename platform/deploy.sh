#!/usr/bin/env bash
set -Eeuo pipefail
# shellcheck source=platform/config.sh
source "$(dirname "$0")/config.sh"

setup_colors() {
  if [[ -t 2 ]] && [[ -z "${NO_COLOR-}" ]] && [[ "${TERM-}" != "dumb" ]]; then
    NOFORMAT='\033[0m' RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[1;33m'
  else
    NOFORMAT='' RED='' GREEN=''
  fi
}

msg() {
  echo >&2 -e "${1-}"
}

fail() {
  msg "${RED}DEPLOY FAILED: ${1-}${NOFORMAT}"
  exit 1
}

docker() {
  sudo /usr/bin/docker "$@"
}

setup_colors

APP_NAME="${1-}"
SRC_DIR="${2-}"
PORT="${3-}"
VERSION="${4-}"

if [ -z "$APP_NAME" ] || [ -z "$SRC_DIR" ] || [ -z "$PORT" ] || [ -z "$VERSION" ]; then
  msg "${RED}usage: deploy.sh <app-name> <source-dir> <port> <version>${NOFORMAT}"
  exit 1
fi

IMAGE="paas-$APP_NAME"
CONTAINER="$APP_NAME"
NETWORK="paas-$APP_NAME"
KEEP_IMAGES="${KEEP_IMAGES:-3}"

[ -d "$SRC_DIR" ] || fail "source directory $SRC_DIR not found"
[ -f "$SRC_DIR/Dockerfile" ] || fail "no Dockerfile in the app root"

msg "Deploying ${GREEN}$APP_NAME${NOFORMAT} version ${GREEN}$VERSION${NOFORMAT} on port ${GREEN}$PORT${NOFORMAT}"

msg "${GREEN}Building image $IMAGE:$VERSION${NOFORMAT}"
docker build -t "$IMAGE:$VERSION" "$SRC_DIR" || fail "image build failed"

IMAGE_USER="$(docker image inspect -f '{{.Config.User}}' "$IMAGE:$VERSION")"
IMAGE_USER="${IMAGE_USER%%:*}"
if [ -z "$IMAGE_USER" ] || [ "$IMAGE_USER" = "root" ] || [ "$IMAGE_USER" = "0" ]; then
  fail "image runs as root. Add a non-root USER to the Dockerfile"
fi

if ! docker network inspect "$NETWORK" >/dev/null 2>&1; then
  msg "${GREEN}Creating network $NETWORK${NOFORMAT}"
  docker network create "$NETWORK" >/dev/null
fi

if docker container inspect "$CONTAINER" >/dev/null 2>&1; then
  msg "${GREEN}Stopping previous version${NOFORMAT}"
  docker rm -f "$CONTAINER" >/dev/null
fi

msg "${GREEN}Starting container${NOFORMAT}"
docker run -d \
  --name "$CONTAINER" \
  --network "$NETWORK" \
  --restart unless-stopped \
  -p "127.0.0.1:$PORT:$PORT" \
  -e PORT="$PORT" \
  -e NODE_ENV=production \
  --memory "$MEMORY" \
  --cpus "$CPU" \
  --read-only \
  --tmpfs /tmp \
  --cap-drop ALL \
  --security-opt no-new-privileges \
  --label "paas.app=$APP_NAME" \
  --label "paas.version=$VERSION" \
  "$IMAGE:$VERSION" >/dev/null || fail "container failed to start"

#Health check
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
  msg "${YELLOW}Last container logs:${NOFORMAT}"
  docker logs --tail 20 "$CONTAINER" >&2 || true
  fail "app not responding on port $PORT"
fi

docker image ls "$IMAGE" --format '{{.Tag}}' \
  | tail -n "+$((KEEP_IMAGES + 1))" \
  | while read -r old_tag; do
      docker image rm "$IMAGE:$old_tag" >/dev/null 2>&1 || true
    done

msg "${GREEN}Deployed $APP_NAME ($VERSION) on port $PORT${NOFORMAT}"