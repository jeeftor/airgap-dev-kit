#!/usr/bin/env bash
# Build a complete Linux amd64 kit through Docker without bind-mounting files.
set -euo pipefail

repo_root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
output=.
flavor=full
image="${AIRGAP_LOCAL_BUILD_IMAGE:-golang:1.26-trixie}"
platform="${AIRGAP_LOCAL_BUILD_PLATFORM:-linux/amd64}"

usage() {
  echo "Usage: $0 [--output DIR] [--flavor full|cli]" >&2
  exit 2
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --output) output=$2; shift 2 ;;
    --flavor) flavor=$2; shift 2 ;;
    *) usage ;;
  esac
done

case "$flavor" in full|cli) ;; *) usage ;; esac
command -v docker >/dev/null 2>&1 || { echo "Docker is required for a local Linux build" >&2; exit 1; }

staging=$(mktemp -d "${TMPDIR:-/tmp}/airgap-local-source.XXXXXX")
container="airgap-local-release-$$"
cleanup() {
  docker rm -f "$container" >/dev/null 2>&1 || true
  rm -rf "$staging"
}
trap cleanup EXIT HUP INT TERM

# docker cp deliberately avoids a bind mount, which works with restricted
# Docker Desktop file-sharing policies. Exclude downloaded host artifacts so
# the Linux container produces every payload itself.
rsync -a \
  --exclude=.git --exclude=.DS_Store --exclude=offline-packages --exclude=fonts --exclude=dist \
  "$repo_root/" "$staging/"

if ! docker image inspect "$image" >/dev/null 2>&1; then
  docker pull --platform "$platform" "$image"
fi
docker create --platform "$platform" --name "$container" "$image" sleep infinity >/dev/null
docker cp "$staging/." "$container:/workspace"
docker start "$container" >/dev/null

kit_version=$(git -C "$repo_root" describe --tags --always --dirty 2>/dev/null || printf '%s' local)
kit_commit=$(git -C "$repo_root" rev-parse --short HEAD 2>/dev/null || printf '%s' local)
build_log=/tmp/airgap-local-build.log
mkdir -p "$output"

if ! docker exec -e "AIRGAP_LOCAL_BUILD_CURL_INSECURE=${AIRGAP_LOCAL_BUILD_CURL_INSECURE:-0}" "$container" bash -lc '
  set -euo pipefail
  exec > /tmp/airgap-local-build.log 2>&1
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ca-certificates curl file git make nodejs npm tar gzip unzip xz-utils
  if [ "${AIRGAP_LOCAL_BUILD_CURL_INSECURE:-0}" = "1" ]; then
    # Corporate TLS interception is scoped to this disposable Linux builder.
    mkdir -p /opt/airgap-local-bin
    cat > /opt/airgap-local-bin/curl <<'"'"'EOF'"'"'
#!/bin/sh
exec /usr/bin/curl -k "$@"
EOF
    chmod 0755 /opt/airgap-local-bin/curl
    export PATH="/opt/airgap-local-bin:$PATH"
    export GIT_SSL_NO_VERIFY=1
    export NPM_CONFIG_STRICT_SSL=false
    export NODE_TLS_REJECT_UNAUTHORIZED=0
  fi
  npm install --global tree-sitter-cli
  cd /workspace
  make update
  make build-editor-payloads
  make release KIT_VERSION="$1" KIT_COMMIT="$2" FLAVOR="$3" OUTPUT=/output
' -- "$kit_version" "$kit_commit" "$flavor"
then
  log_file="$output/local-linux-build.log"
  docker cp "$container:$build_log" "$log_file" >/dev/null 2>&1 || true
  [ ! -f "$log_file" ] || cat "$log_file" >&2
  exit 1
fi

docker cp "$container:/output/." "$output"
printf 'Created local Linux amd64 kit: %s/airgap-dev-kit-linux-x86_64.tar.gz\n' "$output"
