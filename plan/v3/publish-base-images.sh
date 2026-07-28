#!/bin/bash
# Build, boot-gate, and publish the four Tina4 framework base images to GHCR.
#
#   ./publish-base-images.sh            # dry run: build + boot-gate, push nothing
#   ./publish-base-images.sh --push     # the same, then push amd64+arm64
#
# Prerequisites for --push:
#   gh auth refresh -h github.com -s write:packages     # interactive, needs your 2FA
#   gh auth token | docker login ghcr.io -u <you> --password-stdin
#
# WHY THIS SCRIPT EXISTS, rather than four docker push commands:
#
# 1. MULTI-ARCH IS NOT OPTIONAL. A plain `docker build` on Apple Silicon produces
#    an arm64-only image. Published as :latest that gives every amd64 consumer a
#    manifest their machine cannot run -- worse than not publishing. The CLI image
#    has always been built amd64+arm64; these must match.
#
# 2. THE BOOT GATE IS THE POINT. Three of these four images had never served a
#    single request, for months, because nothing ever ran them. An image that
#    does not answer 200 through a PUBLISHED port must never be pushed -- every
#    downstream app build would inherit it.
#
# 3. THE TWO BUILDS ARE SEPARATE ON PURPOSE. buildx cannot --load a
#    multi-platform result into the local image store, so it cannot be booted
#    locally. So: build native and gate it, then build both arches and push.
#    The arm64 layer in the pushed manifest is byte-identical to the gated one;
#    the amd64 layer is NOT independently booted here (see LIMITATION below).
#
# LIMITATION, stated plainly: the amd64 image is emulated at build time and is
# never executed by this script. It is compiled, not verified. Only CI on a real
# amd64 runner can gate it. Until that job exists, treat amd64 as built-and-
# published but UNPROVEN, and say so.
#
# Probe path is /health, never "/". A stock Python/Ruby/Node scaffold has an empty
# src/routes and answers 404 at "/", and `curl -fsS` scores a 404 as a failure --
# which is exactly how an earlier run recorded three healthy containers as dead.

set -uo pipefail

PUSH=0
[[ "${1:-}" == "--push" ]] && PUSH=1

REGISTRY="ghcr.io/tina4stack"
PLATFORMS="linux/amd64,linux/arm64"
HOST_PORT=18200

# Each framework carries its OWN version. They are deliberately not unified: the
# repos are at different releases, and tagging an image with a version its code
# is not would be a lie in the registry.
#   name | repo dir | container port | version
FRAMEWORKS=(
  "tina4-python|tina4-python|7146|3.13.92"
  "tina4-php|tina4-php|7145|3.13.93"
  "tina4-ruby|tina4-ruby|7147|3.13.93"
  "tina4-nodejs|tina4-nodejs|7148|3.13.92"
)

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
FAILED=()
GATED=()

cleanup() { docker rm -f gate >/dev/null 2>&1 || true; }
trap cleanup EXIT INT TERM

for entry in "${FRAMEWORKS[@]}"; do
  IFS='|' read -r name dir port version <<< "$entry"
  ctx="$ROOT/$dir"
  echo
  echo "=============================================================="
  echo "  $name  ($version)  context: $ctx"
  echo "=============================================================="

  if [[ ! -f "$ctx/Dockerfile" ]]; then
    echo "  SKIP: no Dockerfile at $ctx"
    FAILED+=("$name (no Dockerfile)")
    continue
  fi

  # --- 1. native build, so it can actually be run -------------------------
  echo "  [1/3] building native arch..."
  if ! docker build -t "gate/$name:probe" "$ctx" >/dev/null 2>&1; then
    echo "  FAIL: native build failed"
    FAILED+=("$name (build)")
    continue
  fi

  # --- 2. boot gate: 200 through a PUBLISHED port ------------------------
  # A 200 through -p proves two things at once: the process booted, AND it bound
  # 0.0.0.0. A server on 127.0.0.1 inside a container cannot answer through -p,
  # so this is the bind check as well as the liveness check.
  echo "  [2/3] boot gate on /health..."
  cleanup
  docker run -d --name gate -p "$HOST_PORT:$port" "gate/$name:probe" >/dev/null 2>&1
  served=0
  for i in $(seq 1 45); do
    if curl -fsS -m 2 "http://127.0.0.1:$HOST_PORT/health" >/dev/null 2>&1; then
      served=1; break
    fi
    if [[ "$(docker inspect -f '{{.State.Running}}' gate 2>/dev/null)" != "true" ]]; then
      break
    fi
    sleep 1
  done

  if [[ "$served" != "1" ]]; then
    echo "  FAIL: never served 200 on /health"
    docker logs gate 2>&1 | tail -15 | sed 's/^/        /'
    FAILED+=("$name (boot gate)")
    cleanup
    continue
  fi

  # Booting is not passing. A container that answers once and then dies under the
  # smallest load is broken, so require sustained successes and a live process.
  for i in 1 2 3 4 5; do
    curl -fsS -m 2 "http://127.0.0.1:$HOST_PORT/health" >/dev/null 2>&1 || served=0
  done
  [[ "$(docker inspect -f '{{.State.Running}}' gate 2>/dev/null)" == "true" ]] || served=0
  if [[ "$served" != "1" ]]; then
    echo "  FAIL: served once then stopped"
    FAILED+=("$name (unstable)")
    cleanup
    continue
  fi

  size=$(docker run --rm --entrypoint sh "gate/$name:probe" -c 'du -sx / 2>/dev/null | cut -f1' 2>/dev/null \
          | awk '{printf "%.0f", $1*1024/1000000}')
  echo "  PASS: 200 on /health, ${size} MB on disk"
  GATED+=("$name")
  cleanup

  # --- 3. multi-arch build + push ---------------------------------------
  if [[ "$PUSH" != "1" ]]; then
    echo "  [3/3] dry run -- not pushing (re-run with --push)"
    continue
  fi

  echo "  [3/3] building $PLATFORMS and pushing..."
  if docker buildx build \
        --platform "$PLATFORMS" \
        -t "$REGISTRY/$name:$version" \
        -t "$REGISTRY/$name:v3" \
        -t "$REGISTRY/$name:latest" \
        --provenance=true \
        --push "$ctx"; then
    echo "  PUSHED $REGISTRY/$name:$version (+ v3, latest)"
  else
    echo "  FAIL: push failed"
    FAILED+=("$name (push)")
  fi
done

echo
echo "=============================================================="
printf '  gated OK : %s\n' "${GATED[*]:-none}"
if (( ${#FAILED[@]} )); then
  printf '  FAILED   : %s\n' "${FAILED[*]}"
  echo "=============================================================="
  exit 1
fi
echo "  all four passed the boot gate"
[[ "$PUSH" == "1" ]] && echo "  amd64 layers are BUILT BUT NOT BOOTED -- see LIMITATION at the top"
echo "=============================================================="
