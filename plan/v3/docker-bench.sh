#!/bin/bash
# Production Docker benchmark harness: image size, minimum viable memory, survival at a
# shared ceiling, and throughput -- identical logic for every framework.
#
# Usage: docker-bench.sh <label> <image> <container-port> [extra docker run args...]
#
# Why each measurement exists is documented in docker-benchmark-harness.md. The short
# version: for anyone sizing a deployment, image size and the memory floor matter more
# than requests per second, and "who survives a shared tight ceiling" is a pass/fail
# table that is much harder to spin than a throughput chart.
#
# Everything here is deliberately serial. Two containers under load at once contend for
# CPU and both numbers are wrong.

set -uo pipefail

LABEL="${1:?usage: docker-bench.sh <label> <image> <port> [extra args]}"
IMAGE="${2:?missing image}"
PORT="${3:?missing container port}"
shift 3
EXTRA=("$@")

HOST_PORT=18080
CPUS=2
BASELINE_MEM=1g
# Stepped DOWN until the framework stops surviving. 64m is below any realistic runtime,
# so reaching it means "survives everything we tested".
MEM_LADDER=(1g 512m 256m 192m 128m 96m 64m)
PROBE_REQUESTS=30      # consecutive successes required to count as "serving"
BOOT_TIMEOUT=45        # seconds to wait for the first 200
# Path to probe. /health is the right default for a stock scaffold: it is a built-in
# route in all four frameworks returning the same JSON shape, so the probe is
# genuinely like-for-like. Do NOT default to "/" -- a stock Python/Ruby/Node scaffold
# has an EMPTY src/routes and answers 404 there, and `curl -fsS` scores a 404 as a
# failure. That is exactly how a first run of this harness recorded three healthy
# containers as "did not survive 1g" (oom_killed=false was the tell: nothing had
# actually been killed). Override with BENCH_PATH=/api/bench/json for a bench app.
BENCH_PATH="${BENCH_PATH:-/health}"

log() { printf '  %s\n' "$*"; }

cleanup() { docker rm -f "bench_$LABEL" >/dev/null 2>&1 || true; }
trap cleanup EXIT

# --- 1. Image size -------------------------------------------------------------------
# TWO numbers, because they differ by 3x and quoting only one of them misleads.
#
#   compressed   what you pull from a registry (bandwidth, deploy time)
#   on-disk      what the unpacked filesystem occupies on the node (storage, cost)
#
# Do NOT use `docker image inspect -f '{{.Size}}'`. Under Docker Desktop's containerd
# snapshotter it returns the COMPRESSED size while reading like a total: it reported
# 42.6 MB for a PHP image whose filesystem is 114 MB and one of whose layers is alone
# 76.7 MB. `docker save` is no better -- the OCI export carries compressed blobs too.
# `du -sx /` inside the image is the ground truth, and it agrees with the sum of
# `docker history` layer sizes (114.0 vs 115.0 MB on PHP) which is the independent
# cross-check. Sizes measured with inspect before 2026-07-27 are void.
if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
  echo "FATAL: image $IMAGE not found locally. Build it first." >&2
  exit 1
fi
compressed_mb=$(docker save "$IMAGE" 2>/dev/null | wc -c \
  | awk '{printf "%.1f", $1/1000000}')
disk_kb=$(docker run --rm --entrypoint sh "$IMAGE" -c 'du -sx / 2>/dev/null | cut -f1' 2>/dev/null)
size_mb=$(awk -v k="${disk_kb:-0}" 'BEGIN{printf "%.1f", k*1024/1000000}')

# --- helpers -------------------------------------------------------------------------
# Boot the container at a given memory limit and require PROBE_REQUESTS consecutive 200s.
# Returns 0 = survived, 1 = did not.
try_at_memory() {
  local mem="$1"
  cleanup
  docker run -d --name "bench_$LABEL" \
    --cpus="$CPUS" --memory="$mem" --memory-swap="$mem" \
    -p "$HOST_PORT:$PORT" ${EXTRA[@]+"${EXTRA[@]}"} "$IMAGE" >/dev/null 2>&1 || return 1

  # Wait for the first success.
  local waited=0 ok=0
  while (( waited < BOOT_TIMEOUT )); do
    if curl -fsS -m 2 "http://127.0.0.1:$HOST_PORT$BENCH_PATH" >/dev/null 2>&1; then
      ok=1; break
    fi
    # A container that has already exited is never coming up.
    if [[ "$(docker inspect -f '{{.State.Running}}' "bench_$LABEL" 2>/dev/null)" != "true" ]]; then
      return 1
    fi
    sleep 1; waited=$((waited+1))
  done
  (( ok == 1 )) || return 1

  # Booting is not passing: require sustained successes, so a container that starts and
  # then OOMs under the smallest load is correctly recorded as a failure.
  local i
  for (( i=0; i<PROBE_REQUESTS; i++ )); do
    curl -fsS -m 2 "http://127.0.0.1:$HOST_PORT$BENCH_PATH" >/dev/null 2>&1 || return 1
  done
  # And it must still be alive (not OOM-killed) at the end.
  [[ "$(docker inspect -f '{{.State.Running}}' "bench_$LABEL" 2>/dev/null)" == "true" ]] || return 1
  return 0
}

# --- 2. Minimum viable memory --------------------------------------------------------
min_mem="none"
declare -a survived_at=()
for mem in "${MEM_LADDER[@]}"; do
  if try_at_memory "$mem"; then
    survived_at+=("$mem")
    min_mem="$mem"
    log "memory $mem: SURVIVED"
  else
    oom=$(docker inspect -f '{{.State.OOMKilled}}' "bench_$LABEL" 2>/dev/null)
    log "memory $mem: FAILED (oom_killed=${oom:-unknown})"
    break
  fi
done

# --- 3. Survival at the shared ceilings ----------------------------------------------
surv_256=$([[ " ${survived_at[*]-} " == *" 256m "* ]] && echo PASS || echo FAIL)
surv_128=$([[ " ${survived_at[*]-} " == *" 128m "* ]] && echo PASS || echo FAIL)

# --- 4. Throughput at the shared baseline --------------------------------------------
json_rps="n/a"; list_rps="n/a"
if try_at_memory "$BASELINE_MEM"; then
  if command -v hey >/dev/null 2>&1; then
    hey -n 500 -c 10 "http://127.0.0.1:$HOST_PORT$BENCH_PATH" >/dev/null 2>&1  # warm
    json_rps=$(hey -n 5000 -c 50 "http://127.0.0.1:$HOST_PORT$BENCH_PATH" 2>/dev/null \
      | awk '/Requests\/sec/{printf "%.0f", $2}')
    hey -n 500 -c 10 "http://127.0.0.1:$HOST_PORT/api/bench/list" >/dev/null 2>&1
    list_rps=$(hey -n 5000 -c 50 "http://127.0.0.1:$HOST_PORT/api/bench/list" 2>/dev/null \
      | awk '/Requests\/sec/{printf "%.0f", $2}')
  fi
else
  log "WARNING: did not survive the $BASELINE_MEM baseline; throughput not measured"
fi
cleanup

# --- report ---------------------------------------------------------------------------
printf '\n  RESULT %s\n' "$LABEL"
printf '    image                 %s\n' "$IMAGE"
printf '    size compressed       %s MB   (registry pull)\n' "$compressed_mb"
printf '    size on disk          %s MB   (unpacked filesystem)\n' "$size_mb"
printf '    probe path            %s\n' "$BENCH_PATH"
printf '    min viable memory     %s\n' "$min_mem"
printf '    survives 256m         %s\n' "$surv_256"
printf '    survives 128m         %s\n' "$surv_128"
printf '    json req/s (2cpu/1g)  %s\n' "${json_rps:-n/a}"
printf '    list req/s (2cpu/1g)  %s\n' "${list_rps:-n/a}"

# Machine-readable line for collection into the report JSON.
printf 'JSONLINE {"label":"%s","image":"%s","size_compressed_mb":%s,"size_on_disk_mb":%s,"probe_path":"%s","min_viable_memory":"%s","survives_256m":"%s","survives_128m":"%s","json_rps":"%s","list_rps":"%s"}\n' \
  "$LABEL" "$IMAGE" "$compressed_mb" "$size_mb" "$BENCH_PATH" "$min_mem" "$surv_256" "$surv_128" "${json_rps:-n/a}" "${list_rps:-n/a}"
