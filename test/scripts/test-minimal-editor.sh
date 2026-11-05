#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/../.." && pwd)
archive=${1:?Pass the packaged Linux kit archive}
base_image=${AIRGAP_MINIMAL_IMAGE:-debian:12-slim}
results=${AIRGAP_HEALTH_RESULTS:-/tmp/airgap-minimal-results}
run_id="$$-$(date +%s)"
image="airgap-minimal-editor:$run_id"
container="airgap-minimal-editor-$run_id"
mkdir -p "$results"

cleanup() {
  docker cp "$container:/work/results/." "$results/" >/dev/null 2>&1 || true
  docker rm -f "$container" >/dev/null 2>&1 || true
  docker image rm "$image" >/dev/null 2>&1 || true
}
trap cleanup EXIT

docker build --platform linux/amd64 --build-arg "BASE_IMAGE=$base_image" \
  -f "$repo_root/test/minimal-editor.Dockerfile" -t "$image" "$repo_root/test"
docker create --platform linux/amd64 --network none --name "$container" \
  -e AIRGAP_EDITOR_SUITE=minimal -e AIRGAP_HEALTH_RESULTS=/work/results \
  "$image" bash /work/test/scripts/test-minimal-editor-inner.sh >/dev/null
docker cp "$archive" "$container:/work/kit.tar.gz"
docker cp "$repo_root/test" "$container:/work/test"
docker cp "$repo_root/config" "$container:/work/config"
test "$(docker inspect --format '{{.HostConfig.NetworkMode}}' "$container")" = none
docker start --attach "$container"
test "$(docker inspect --format '{{.State.ExitCode}}' "$container")" = 0
