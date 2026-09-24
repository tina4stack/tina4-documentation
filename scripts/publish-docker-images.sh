#!/usr/bin/env bash
#
# Publish the four tina4stack framework images for a released version.
#
# Publishing is MANUAL and runs from the build host, on purpose (owner decision,
# 2026-07-30). The Docker Hub credential lives only on that host and is never
# stored in a GitHub repo: a push token for the tina4stack namespace can
# OVERWRITE `latest` on every published image, so it is a supply-chain write
# primitive, not just a publish credential. Four repos would mean four copies of
# it, readable by every third-party action in each workflow, with four places to
# rotate. The repo workflows therefore keep only the credential-free boot gate
# and an arm64 cross-build.
#
# This script replicates that boot gate before it pushes ANYTHING, because a tag
# is a claim about what is inside the image:
#   1. build the native arch and report the on-disk size
#   2. run the container and require HTTP 200 on /health through the PUBLISHED
#      port -- which also proves the server bound 0.0.0.0, not 127.0.0.1
#   3. require the container to be STILL ALIVE afterwards (serving once then
#      dying is not passing)
#   4. require /health to report a version MATCHING the tag, and refuse to
#      publish on a mismatch. This is not hypothetical: the Node image was once
#      about to publish as 3.13.92 while serving "0.0.0"
#   5. only then buildx --push amd64 + arm64 as <version>, with SBOM/provenance
#   6. pull the arm64 image back from the PUBLISHED manifest and boot it under
#      emulation, turning "compiled" into "executed"; promote v3/latest only on success
#
# Usage (on the build host, as a user who can read the Docker credential):
#     ./publish-docker-images.sh 3.13.94 [/path/to/repos]
#
# Verify afterwards against the Hub API, not this script's own log -- a
# half-failed push can still print "pushed":
#     curl -s https://hub.docker.com/v2/repositories/tina4stack/tina4-python/tags/3.13.94
set -uo pipefail

# SPDX SBOM and provenance are release artefacts (ADR-0073).

VERSION="${1:?usage: publish-docker-images.sh <version> [repo-root]}"
REPO_ROOT="${2:-/root/tina4-lab/tina4-repos}"
WORK="/root/dockerpub-${VERSION}"
GATE="tina4-release-gate-$$"
ARM="tina4-release-arm-$$"
PORT=18099          # deliberately far from the lab's service ports
mkdir -p "$WORK"
BUILDER="tina4"     # docker-container driver, multi-platform capable

declare -A APP_PORT=([tina4-python]=7146 [tina4-php]=7145 [tina4-ruby]=7147 [tina4-nodejs]=7148)
ORDER=(tina4-python tina4-php tina4-ruby tina4-nodejs)
declare -A RESULT
overall=0

log()  { printf '\n=== %s ===\n' "$*"; }
fail() { printf '!! FAIL: %s\n' "$*"; }
cleanup_container() { docker rm -f "$GATE" "$ARM" >/dev/null 2>&1 || true; }
trap cleanup_container EXIT

for repo in "${ORDER[@]}"; do
  log "$repo $VERSION"
  IMAGE="docker.io/tina4stack/${repo}"
  # An exact release tag is immutable, including after a partial prior run.
  if docker buildx imagetools inspect "$IMAGE:$VERSION" >/dev/null 2>&1; then
    fail "$repo: $VERSION already exists; refusing to overwrite it"
    RESULT[$repo]="version-already-published"; overall=1; continue
  fi
  ap="${APP_PORT[$repo]}"
  src="$WORK/$repo"

  # CHECKOUT, never `git archive`. `git archive` HONOURS .gitattributes
  # export-ignore, and tina4-php marks /example export-ignore -- so an archive
  # is a SILENTLY THINNED tree and its Dockerfile's `COPY /build/example` fails.
  # GitHub Actions never hits this because actions/checkout is a real checkout.
  rm -rf "$src"
  if ! git clone --quiet --no-checkout "$REPO_ROOT/$repo" "$src" \
     || ! git -C "$src" checkout --quiet --detach "$VERSION"; then
    fail "$repo: cannot check out $VERSION"; RESULT[$repo]="checkout-failed"; overall=1; continue
  fi

  # COMPLETENESS GUARD: a thinned tree that still BUILDS is the dangerous case --
  # the image ships missing files and every other gate passes it.
  want=$(git -C "$REPO_ROOT/$repo" ls-tree -r --name-only "$VERSION" | wc -l | tr -d ' ')
  have=$(git -C "$src" ls-files | wc -l | tr -d ' ')
  if [ "$want" != "$have" ]; then
    fail "$repo: extracted tree INCOMPLETE ($have of $want)"; RESULT[$repo]="incomplete-tree"; overall=1; continue
  fi
  echo "checked out $(git -C "$src" rev-parse --short HEAD); $have/$want files"

  if ! docker build -t "$IMAGE:gate" "$src" >"$WORK/$repo.build.log" 2>&1; then
    fail "$repo: build failed"; tail -30 "$WORK/$repo.build.log"
    RESULT[$repo]="build-failed"; overall=1; continue
  fi
  kb=$(docker run --rm --entrypoint sh "$IMAGE:gate" -c 'du -sx / 2>/dev/null | cut -f1' 2>/dev/null || echo 0)
  echo "on-disk size: $(( kb / 1024 )) MB"

  cleanup_container
  docker run -d --name "$GATE" -p "$PORT:$ap" "$IMAGE:gate" >/dev/null
  served=0
  for i in $(seq 1 45); do
    if curl -fsS -m 2 -o /dev/null "http://127.0.0.1:$PORT/health"; then
      echo "served /health after ${i}s"; served=1; break
    fi
    if [ "$(docker inspect -f '{{.State.Running}}' "$GATE" 2>/dev/null)" != "true" ]; then
      fail "$repo: container exited before serving"; docker logs "$GATE" 2>&1 | tail -30; break
    fi
    sleep 1
  done
  if [ "$served" != "1" ]; then
    fail "$repo: no 200 on /health in 45s (failed to boot, or bound 127.0.0.1)"
    RESULT[$repo]="boot-gate-failed"; overall=1; cleanup_container; continue
  fi
  if [ "$(docker inspect -f '{{.State.Running}}' "$GATE")" != "true" ]; then
    fail "$repo: died after serving (OOMKilled=$(docker inspect -f '{{.State.OOMKilled}}' "$GATE"))"
    RESULT[$repo]="died-after-serving"; overall=1; cleanup_container; continue
  fi

  reported=$(curl -fsS -m 5 "http://127.0.0.1:$PORT/health" \
    | python3 -c 'import json,sys; print(json.load(sys.stdin).get("version",""))' 2>/dev/null)
  echo "reported version: '$reported'"
  if [ -z "$reported" ] || [ "$reported" = "0.0.0" ]; then
    fail "$repo: /health reports '$reported' -- unverifiable, refusing to publish"
    RESULT[$repo]="no-version"; overall=1; cleanup_container; continue
  fi
  if [ "$reported" != "$VERSION" ]; then
    fail "$repo: tag says $VERSION, container serves $reported -- refusing to publish a lying tag"
    RESULT[$repo]="version-mismatch:$reported"; overall=1; cleanup_container; continue
  fi
  echo "GATE PASSED: boots, binds 0.0.0.0, alive, serves $reported"
  cleanup_container

  if ! docker buildx build --builder "$BUILDER" \
        --platform linux/amd64,linux/arm64 --provenance=mode=max --sbom=true \
        --metadata-file "$WORK/$repo.metadata.json" --push \
        -t "$IMAGE:$VERSION" \
        "$src" >"$WORK/$repo.push.log" 2>&1; then
    fail "$repo: buildx push failed"; tail -30 "$WORK/$repo.push.log"
    RESULT[$repo]="push-failed"; overall=1; continue
  fi
  digest=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["containerimage.digest"])' "$WORK/$repo.metadata.json")
  if [ -z "$digest" ] \
     || ! docker buildx imagetools inspect "$IMAGE@$digest" --raw >"$WORK/$repo.manifest.json" \
     || ! docker buildx imagetools inspect "$IMAGE@$digest" --format '{{json .SBOM}}' >"$WORK/$repo.sbom.json" \
     || ! docker buildx imagetools inspect "$IMAGE@$digest" --format '{{json .Provenance}}' >"$WORK/$repo.provenance.json"; then
    fail "$repo: cannot retrieve published integrity evidence"
    RESULT[$repo]="integrity-evidence-failed"; overall=1; continue
  fi
  if ! python3 - "$WORK/$repo" <<'PYVERIFY'
import json, pathlib, sys
prefix = sys.argv[1]
for kind in ("sbom", "provenance"):
    evidence = json.loads(pathlib.Path(prefix + "." + kind + ".json").read_text())
    for platform in ("linux/amd64", "linux/arm64"):
        if not evidence or not evidence.get(platform):
            raise SystemExit(f"Missing {kind} for {platform}")
        document = evidence[platform].get("SPDX" if kind == "sbom" else "SLSA", {})
        if kind == "sbom":
            if not document.get("spdxVersion", "").startswith("SPDX-2.") or not document.get("packages"):
                raise SystemExit(f"Invalid SPDX inventory for {platform}")
        elif not (document.get("buildDefinition") or document.get("buildType")):
            raise SystemExit(f"Invalid build provenance for {platform}")
PYVERIFY
  then
    fail "$repo: published attestations incomplete"
    RESULT[$repo]="incomplete-attestations"; overall=1; continue
  fi
  printf '%s  %s:%s\n' "$digest" "$IMAGE" "$VERSION" >"$WORK/$repo.digest.txt"
  echo "pushed $IMAGE:$VERSION (amd64 + arm64), digest $digest"

  # buildx cannot --load a multi-platform result, so arm64 was only COMPILED
  # before the push. Pulling it back per-arch turns that into "executed".
  # Emulation proves the image is not arch-broken; it says nothing about speed.
  docker rm -f "$ARM" >/dev/null 2>&1 || true
  armok=0
  if docker run -d --name "$ARM" --platform linux/arm64 -p "$PORT:$ap" "$IMAGE@$digest" >/dev/null 2>&1; then
    for i in $(seq 1 90); do
      if curl -fsS -m 2 -o /dev/null "http://127.0.0.1:$PORT/health"; then
        reported=$(curl -fsS -m 5 "http://127.0.0.1:$PORT/health" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("version",""))')
        if [ "$reported" = "$VERSION" ] && [ "$(docker inspect -f '{{.State.Running}}' "$ARM")" = "true" ]; then
          echo "arm64 (emulated) served version $reported after ${i}s"; armok=1
        fi
        break
      fi
      [ "$(docker inspect -f '{{.State.Running}}' "$ARM" 2>/dev/null)" = "true" ] || break
      sleep 1
    done
  fi
  if [ "$armok" = "1" ]; then
    # Promote the already tested, attested index without rebuilding it.
    if docker buildx imagetools create -t "$IMAGE:v3" -t "$IMAGE:latest" "$IMAGE@$digest"; then
      RESULT[$repo]="PUBLISHED (amd64 gated + arm64 emulated OK)"
    else RESULT[$repo]="version published; alias promotion failed"; overall=1; fi
  else RESULT[$repo]="PUBLISHED but arm64 gate FAILED"; overall=1; fi
  cleanup_container
  docker rmi "$IMAGE:gate" >/dev/null 2>&1 || true
done

log "SUMMARY $VERSION"
for repo in "${ORDER[@]}"; do printf '%-16s %s\n' "$repo" "${RESULT[$repo]:-not-reached}"; done
echo "overall exit: $overall"
exit $overall
