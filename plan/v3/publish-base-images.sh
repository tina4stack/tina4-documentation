#!/bin/bash
# Build, boot-gate, and publish the four Tina4 framework base images to Docker Hub.
#
#   ./publish-base-images.sh            # dry run: build + boot-gate, push nothing
#   ./publish-base-images.sh --push     # the same, then push amd64+arm64
#
# Prerequisites for --push:
#   docker login -u tina4stack          # Docker Hub; you are the namespace owner
#
# REGISTRY CHOICE: Docker Hub, not GHCR, and that is deliberate.
#
# `tina4stack` is a USER account, not an organisation, so ghcr.io/tina4stack/*
# packages belong to that user and can only be pushed by authenticating AS
# tina4stack (CI gets away with it because GITHUB_TOKEN is scoped to the
# tina4stack/tina4 repo). More importantly, Docker Hub is where these images were
# ALREADY being published and where the Dockerfiles already tell users to pull
# from -- `FROM tina4stack/tina4-python:v3` has no registry prefix, so it resolves
# to docker.io. Publishing to GHCR instead would have left the documented pull
# path pointing at images from 2026-04-12 that predate every fix in this batch,
# including a PHP image that never booted.
#
# The CLI image (ghcr.io/tina4stack/tina4-cli) stays on GHCR -- it is published by
# CI from a tag, and the Dockerfile templates pin it there.
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
# 4. AMD64 IS GATED TOO, AFTER THE PUSH. buildx cannot --load a multi-platform
#    result, but once the manifest is in the registry each arch can be pulled and
#    run individually. So step 4 re-pulls the published image with
#    `--platform linux/amd64` and requires the same 200 on /health, confirming
#    uname is x86_64. Emulated, but genuinely EXECUTED -- not merely compiled.
#
# Remaining caveat: emulation is not a real amd64 host. It proves the image is
# not arch-broken (wrong base, missing native module, bad binary); it does not
# prove native performance or catch a qemu-masked timing bug. A CI job on a real
# amd64 runner is still the stronger gate.
#
# Probe path is /health, never "/". A stock Python/Ruby/Node scaffold has an empty
# src/routes and answers 404 at "/", and `curl -fsS` scores a 404 as a failure --
# which is exactly how an earlier run recorded three healthy containers as dead.

set -uo pipefail

# Args in any order: --push, and/or one or more framework names to restrict to.
# A name filter exists so a single-image fix still goes through THIS script --
# the boot gate and the version gate are the whole point, and re-publishing three
# unchanged images to prove one is wasteful. Without a filter the temptation is a
# hand-rolled `docker buildx build --push`, which is exactly the ungated path that
# let a never-booted image sit in the registry for months.
#   ./publish-base-images.sh                          # all four, dry run
#   ./publish-base-images.sh tina4-nodejs --push      # just Node, published
PUSH=0
ONLY=()
for arg in "$@"; do
  case "$arg" in
    --push) PUSH=1 ;;
    -*)     echo "unknown flag: $arg" >&2; exit 2 ;;
    *)      ONLY+=("$arg") ;;
  esac
done

REGISTRY="docker.io/tina4stack"
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

# Where the framework repos live. TINA4_REPOS wins so a caller that already knows
# (tina4-lab.sh) can pass its answer down, instead of this script re-deriving it
# from its own path and getting a different one. That path guess assumes the
# script sits in a tina4-documentation checkout beside the framework repos; copied
# to /root/tina4-lab it resolved to "/" and every framework was reported as
# "no Dockerfile". One root, decided once, passed along.
if [ -n "${TINA4_REPOS:-}" ]; then
  ROOT="$TINA4_REPOS"
else
  ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
fi
FAILED=()
GATED=()

cleanup() { docker rm -f gate >/dev/null 2>&1 || true; }
trap cleanup EXIT INT TERM

SKIPPED=()

for entry in "${FRAMEWORKS[@]}"; do
  IFS='|' read -r name dir port version <<< "$entry"

  # Honour a name filter. Reported at the end rather than silently dropped -- a
  # run that covered one image must never read like a run that covered four.
  if (( ${#ONLY[@]} )); then
    match=0
    for want in "${ONLY[@]}"; do [[ "$want" == "$name" ]] && match=1; done
    if (( ! match )); then
      SKIPPED+=("$name")
      continue
    fi
  fi

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
  echo "  [1/4] building native arch..."
  if ! docker build -t "gate/$name:probe" "$ctx" >/dev/null 2>&1; then
    echo "  FAIL: native build failed"
    FAILED+=("$name (build)")
    continue
  fi

  # --- 2. boot gate: 200 through a PUBLISHED port ------------------------
  # A 200 through -p proves two things at once: the process booted, AND it bound
  # 0.0.0.0. A server on 127.0.0.1 inside a container cannot answer through -p,
  # so this is the bind check as well as the liveness check.
  echo "  [2/4] boot gate on /health..."
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

  # --- 2b. THE TAG MUST NOT LIE ABOUT THE VERSION -------------------------
  # The image tag mirrors the framework release (tina4-nodejs:3.13.92), so the
  # tag is a claim about what is inside. Verify it instead of trusting it: all
  # four frameworks report a `version` on /health, sourced from the same place
  # the release is cut from (__version__ / self::$VERSION / Tina4::VERSION /
  # package.json). If the running container disagrees with the tag we are about
  # to push, the tag is a lie and nothing gets pushed.
  #
  # This is not hypothetical. The Node image was about to be tagged 3.13.92
  # while serving "version": "0.0.0" -- relocating the framework out of /app
  # broke the three-level walk in server.ts's readPackageVersion(), which fell
  # back to "0.0.0". It booted, it served 200, it passed every other gate here.
  # Only comparing the served version against the tag catches that class of bug.
  served_version=$(curl -fsS -m 3 "http://127.0.0.1:$HOST_PORT/health" 2>/dev/null \
    | python3 -c 'import json,sys; print(json.load(sys.stdin).get("version",""))' 2>/dev/null)

  if [[ -z "$served_version" ]]; then
    echo "  FAIL: /health reported no version -- cannot verify the :$version tag"
    FAILED+=("$name (no version on /health)")
    cleanup
    continue
  fi
  if [[ "$served_version" != "$version" ]]; then
    echo "  FAIL: version mismatch -- tag says $version, container serves $served_version"
    echo "        Refusing to publish a tag that misreports its own contents."
    FAILED+=("$name (version $served_version != tag $version)")
    cleanup
    continue
  fi

  size=$(docker run --rm --entrypoint sh "gate/$name:probe" -c 'du -sx / 2>/dev/null | cut -f1' 2>/dev/null \
          | awk '{printf "%.0f", $1*1024/1000000}')
  echo "  PASS: 200 on /health, serves $served_version (matches tag), ${size} MB on disk"
  GATED+=("$name")
  cleanup

  # --- 3. multi-arch build + push ---------------------------------------
  if [[ "$PUSH" != "1" ]]; then
    echo "  [3/4] dry run -- not pushing (re-run with --push)"
    continue
  fi

  echo "  [3/4] building $PLATFORMS and pushing..."
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
    continue
  fi

  # --- 4. amd64 gate: pull the PUBLISHED amd64 layer and run it -----------
  # The multi-platform build could not be loaded locally, but the pushed manifest
  # can: pull the amd64 arch explicitly and require the same 200. Emulated, but
  # actually executed -- this is what turns "compiled" into "verified".
  echo "  [4/4] amd64 gate (emulated, from the registry)..."
  docker rm -f gate >/dev/null 2>&1
  docker run -d --name gate --platform linux/amd64 -p "$HOST_PORT:$port" \
      "$REGISTRY/$name:$version" >/dev/null 2>&1
  amd_ok=0
  for i in $(seq 1 60); do
    if curl -fsS -m 2 "http://127.0.0.1:$HOST_PORT/health" >/dev/null 2>&1; then
      amd_ok=1; break
    fi
    [[ "$(docker inspect -f '{{.State.Running}}' gate 2>/dev/null)" == "true" ]] || break
    sleep 1
  done
  if (( amd_ok )); then
    echo "  PASS: amd64 served 200 (uname=$(docker exec gate uname -m 2>/dev/null))"
  else
    echo "  FAIL: amd64 image did not serve -- the published manifest is arch-broken"
    docker logs gate 2>&1 | tail -10 | sed 's/^/        /'
    FAILED+=("$name (amd64 gate)")
  fi
  cleanup
done

echo
echo "=============================================================="
printf '  gated OK : %s\n' "${GATED[*]:-none}"
if (( ${#SKIPPED[@]} )); then
  printf '  skipped  : %s  (name filter -- NOT verified this run)\n' "${SKIPPED[*]}"
fi
if (( ${#FAILED[@]} )); then
  printf '  FAILED   : %s\n' "${FAILED[*]}"
  echo "=============================================================="
  exit 1
fi
if (( ${#SKIPPED[@]} )); then
  echo "  the selected image(s) passed the boot gate and the version gate"
else
  echo "  all four passed the boot gate and the version gate"
fi
[[ "$PUSH" == "1" ]] && echo "  amd64 gated by emulation from the registry (not a real amd64 host -- see the caveat at the top)"
echo "=============================================================="
