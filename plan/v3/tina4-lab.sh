#!/usr/bin/env bash
#
# tina4-lab.sh -- stand up a Tina4 build-and-verify box, in two layers.
#
#   ./tina4-lab.sh doctor            # is this machine ready? says exactly what to fix
#   ./tina4-lab.sh repos sync        # clone/fast-forward the four framework repos (v3)
#   ./tina4-lab.sh infra up          # start the 10 service containers the suites need
#   ./tina4-lab.sh infra status      # what is up, on which port, healthy or not
#   ./tina4-lab.sh infra env         # print the export block to run the suites against them
#   ./tina4-lab.sh infra down        # remove them all
#   ./tina4-lab.sh images build      # build + boot-gate the four base images
#   ./tina4-lab.sh images publish    # the same, then push to Docker Hub
#   ./tina4-lab.sh derive            # prove `FROM <base>` + add-your-own-driver works
#
# RUN THIS ON THE BUILD BOX, NOT OVER A REMOTE DOCKER CONTEXT.
#
# That is a deliberate constraint, not laziness. With DOCKER_HOST=ssh://box the
# containers publish their ports on the BOX while the script's curl probes run on
# your laptop, so every health check would test the wrong host -- and silently, by
# timing out rather than erroring. Running here means 127.0.0.1 is the truth for
# both, no firewall holes are needed, and the build context is already local so
# nothing is streamed over SSH.
#
#   ssh you@box
#   sudo -i                          # docker + the Hub login live under root here
#   git clone https://github.com/tina4stack/tina4-documentation
#   ./tina4-documentation/plan/v3/tina4-lab.sh doctor
#
# WHAT IT DOES NOT COVER, stated so a skip is never mistaken for a pass:
#   * MQTT (mosquitto 1883/1884/8883 + EMQX 1885). Those need generated TLS certs
#     and per-broker auth files; the MQTT tests will still SKIP. `infra status`
#     labels them "not provisioned" rather than leaving you to guess.
#   * Firebird. Its live tests are gated separately and excluded by design.
#
set -uo pipefail

# --- service table -----------------------------------------------------------
#
# Ports and credentials are LIFTED FROM THE CI WORKFLOWS, not invented, so a
# suite that passes here passes there. Two are deliberately non-default and worth
# reading twice before you debug a connection refused:
#
#   postgres -> 55432 (not 5432)
#   valkey   -> 6380  (not 6379; redis already owns 6379)
#
# The source of truth is tina4-python/.github/workflows/test.yml. If you change a
# port here and not there, you have created drift, which is the whole class of bug
# this file exists to avoid.
#
# Fields are ^-separated, NOT |-separated. The MSSQL readiness probe contains a
# shell `||` fallback (the sqlcmd binary moved between image versions), and using
# | as the field separator silently truncated that probe mid-command.
#
# The readiness command is passed to `sh -c` verbatim, so anything the shell
# would otherwise interpret MUST be quoted here. Mongo's probe is the cautionary
# case: written unquoted as --eval db.runCommand({ping:1}).ok, sh choked on the
# braces and parens, the probe never succeeded, and `infra up` reported mongo as
# FAILED for 120s while its own log said "mongod startup complete". A broken
# probe looks exactly like a broken service. Quote the argument.
#
#   name^image^port-mapping...^env...^readycmd
SERVICES=(
  "redis^redis:7-alpine^6379:6379^^redis-cli ping"
  "redis-auth^redis:7-alpine^6381:6379^^redis-cli -a s3cret ping"
  "valkey^valkey/valkey:8-alpine^6380:6379^^valkey-cli ping"
  "memcached^memcached:alpine^11211:11211^^"
  "mongo^mongo:7^27017:27017^^mongosh --quiet --eval 'db.runCommand({ping:1}).ok'"
  "postgres^postgres:16^55432:5432^POSTGRES_USER=tina4,POSTGRES_PASSWORD=tina4,POSTGRES_DB=tina4_py^pg_isready -U tina4 -d tina4_py"
  "rabbitmq^rabbitmq:3-management^5672:5672,15672:15672^^rabbitmq-diagnostics -q ping"
  "mysql^mysql:8^3306:3306^MYSQL_DATABASE=tina4_test,MYSQL_USER=tina4,MYSQL_PASSWORD=tina4,MYSQL_ROOT_PASSWORD=tina4^mysqladmin ping -h 127.0.0.1 -ptina4"
  "mssql^mcr.microsoft.com/mssql/server:2022-latest^1433:1433^ACCEPT_EULA=Y,SA_PASSWORD=TinaSQL123!Secure,MSSQL_PID=Developer^/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'TinaSQL123!Secure' -C -Q 'SELECT 1' || /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P 'TinaSQL123!Secure' -Q 'SELECT 1'"
  "kafka^apache/kafka:latest^9092:9092^KAFKA_NODE_ID=1,KAFKA_PROCESS_ROLES=broker+controller,KAFKA_LISTENERS=PLAINTEXT://:9092+CONTROLLER://:9093,KAFKA_ADVERTISED_LISTENERS=PLAINTEXT://localhost:9092,KAFKA_CONTROLLER_LISTENER_NAMES=CONTROLLER,KAFKA_LISTENER_SECURITY_PROTOCOL_MAP=CONTROLLER:PLAINTEXT+PLAINTEXT:PLAINTEXT,KAFKA_CONTROLLER_QUORUM_VOTERS=1@localhost:9093,KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR=1,KAFKA_GROUP_INITIAL_REBALANCE_DELAY_MS=0^/opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --list"
)

PREFIX="tina4-lab"

# Where the four framework repos live.
#
# Do NOT infer this from the script's own path alone. This file gets copied --
# that is the point of handing it to someone -- and the original guess
# ("../../.." from plan/v3/) resolved to "/" once the script sat in /root,
# so every repo check reported a bogus "//tina4-python missing". Resolve in
# order of how explicit the signal is, and print the answer in `doctor` so it
# is never a mystery.
if [ -n "${TINA4_REPOS:-}" ]; then
  ROOT="$TINA4_REPOS"                                            # explicit wins
elif [ -d "$(dirname "${BASH_SOURCE[0]}")/../../../tina4-python" ]; then
  ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"   # in a docs checkout
elif [ -d "$PWD/tina4-python" ]; then
  ROOT="$PWD"                                                    # run from the parent dir
else
  ROOT="${TINA4_LAB_HOME:-$PWD/tina4-repos}"                     # where `repos sync` puts them
fi

c_ok()   { printf '  \033[32m%s\033[0m %s\n' "OK" "$*"; }
c_bad()  { printf '  \033[31m%s\033[0m %s\n' "!!" "$*"; }
c_warn() { printf '  \033[33m%s\033[0m %s\n' "--" "$*"; }
c_info() { printf '     %s\n' "$*"; }

die() { c_bad "$*"; exit 1; }

# --- doctor ------------------------------------------------------------------
#
# Every check names the fix. A preflight that only says "failed" makes the person
# you handed this to come back and ask you.
cmd_doctor() {
  local fail=0
  echo "=== tina4-lab doctor ==="

  if command -v docker >/dev/null 2>&1; then
    c_ok "docker present ($(docker --version | awk '{print $3}' | tr -d ,))"
  else
    c_bad "docker missing"
    c_info "fix: curl -fsSL https://get.docker.com | sh"
    fail=1
  fi

  if docker info >/dev/null 2>&1; then
    c_ok "docker daemon reachable as $(whoami)"
  else
    c_bad "cannot talk to the docker daemon as $(whoami)"
    c_info "fix: sudo usermod -aG docker \$USER  (then log out and back in), or run as root"
    fail=1
  fi

  if docker buildx version >/dev/null 2>&1; then
    c_ok "buildx present ($(docker buildx version | awk '{print $2}'))"
  else
    c_bad "buildx missing -- multi-arch publish will not work"
    c_info "fix: apt-get install docker-buildx-plugin  (or reinstall via get.docker.com)"
    fail=1
  fi

  # binfmt only matters for the arch you are NOT native on.
  local arch; arch="$(uname -m)"
  local other="linux/arm64"; [ "$arch" = "aarch64" ] && other="linux/amd64"
  if docker buildx inspect --bootstrap 2>/dev/null | grep -q "$other"; then
    c_ok "qemu can emulate $other (native is $arch)"
  else
    c_warn "buildx does not list $other -- the cross-arch half of a publish will fail"
    c_info "fix: docker run --privileged --rm tonistiigi/binfmt --install all"
  fi

  # The publish credential lives in THIS user's docker config, which is why a
  # sudo-vs-user mismatch is such a common surprise: `docker login` as andre does
  # not authenticate a build running as root.
  if [ -f "$HOME/.docker/config.json" ] && grep -q '"auths"' "$HOME/.docker/config.json" 2>/dev/null; then
    c_ok "Docker Hub credentials present for $(whoami) ($HOME/.docker/config.json)"
  else
    c_bad "no Docker Hub credentials for $(whoami) -- publish will fail at login"
    c_info "fix: docker login -u tina4stack   (use a Hub ACCESS TOKEN, not the password)"
    c_info "note: credentials are per-user. Logging in as another user does not help this one."
    fail=1
  fi

  local free_g; free_g="$(df -Pk . | awk 'NR==2{print int($4/1048576)}')"
  if [ "${free_g:-0}" -ge 30 ]; then
    c_ok "disk free: ${free_g} GB"
  else
    c_warn "disk free: ${free_g} GB -- budget 30 GB for images + buildx cache"
  fi

  local mem_g; mem_g="$(awk '/MemTotal/{print int($2/1048576)}' /proc/meminfo 2>/dev/null || echo 0)"
  if [ "${mem_g:-0}" -ge 8 ]; then
    c_ok "memory: ${mem_g} GB"
  else
    c_warn "memory: ${mem_g} GB -- MSSQL alone wants ~2 GB; infra up may OOM under 8 GB"
  fi

  c_info "repos root: $ROOT   (override with TINA4_REPOS=/path)"
  local missing=0
  for d in tina4-python tina4-php tina4-ruby tina4-nodejs; do
    if [ -f "$ROOT/$d/Dockerfile" ]; then
      c_ok "repo present: $d ($(git -C "$ROOT/$d" rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'not a git checkout'))"
    else
      c_warn "repo missing: $ROOT/$d"
      missing=1
    fi
  done
  [ "$missing" = "1" ] && c_info "fix: ./tina4-lab.sh repos sync"

  echo
  if [ "$fail" = "0" ]; then
    echo "  ready. next: ./tina4-lab.sh infra up"
  else
    echo "  NOT ready -- fix the !! lines above, then re-run doctor"
    return 1
  fi
}

# --- infra -------------------------------------------------------------------
svc_field() { echo "$1" | cut -d'^' -f"$2"; }

infra_up_one() {
  local entry="$1"
  local name image ports envs ready
  name="$(svc_field "$entry" 1)"; image="$(svc_field "$entry" 2)"
  ports="$(svc_field "$entry" 3)"; envs="$(svc_field "$entry" 4)"
  ready="$(svc_field "$entry" 5)"
  local cname="$PREFIX-$name"

  # Idempotent: an already-running container is left alone, so re-running `infra
  # up` after adding one service does not tear down the other nine.
  if [ "$(docker inspect -f '{{.State.Running}}' "$cname" 2>/dev/null)" = "true" ]; then
    c_ok "$name already running"
    return 0
  fi
  docker rm -f "$cname" >/dev/null 2>&1

  local args=(-d --name "$cname" --restart unless-stopped)
  local IFS_SAVE="$IFS"
  IFS=','; for p in $ports; do args+=(-p "$p"); done
  for e in $envs; do
    # '+' stands in for ',' inside a single env value (Kafka listener lists are
    # comma-separated, and ',' is already the field separator here).
    args+=(-e "${e//+/,}")
  done
  IFS="$IFS_SAVE"

  printf '  .. %-11s pulling/starting %s\n' "$name" "$image"
  if ! docker run "${args[@]}" "$image" >/dev/null 2>&1; then
    c_bad "$name failed to start"
    docker logs "$cname" 2>&1 | tail -5 | sed 's/^/        /'
    return 1
  fi

  [ -z "$ready" ] && { c_warn "$name started -- PORT ONLY, no readiness probe for this image"; return 0; }

  local waited=0
  while [ "$waited" -lt 120 ]; do
    if docker exec "$cname" sh -c "$ready" >/dev/null 2>&1; then
      c_ok "$name healthy after ${waited}s"
      return 0
    fi
    if [ "$(docker inspect -f '{{.State.Running}}' "$cname" 2>/dev/null)" != "true" ]; then
      c_bad "$name exited while starting"
      docker logs "$cname" 2>&1 | tail -8 | sed 's/^/        /'
      return 1
    fi
    sleep 2; waited=$((waited + 2))
    [ $((waited % 20)) -eq 0 ] && c_info "$name still starting (${waited}s)"
  done
  c_bad "$name never became healthy in 120s"
  docker logs "$cname" 2>&1 | tail -8 | sed 's/^/        /'
  return 1
}

cmd_infra_up() {
  echo "=== infra up ==="
  local failed=()
  for entry in "${SERVICES[@]}"; do
    infra_up_one "$entry" || failed+=("$(svc_field "$entry" 1)")
  done

  # MSSQL ships with no user database, so the suites' tina4_test has to be
  # created once it is accepting connections. CI does the same thing.
  if [ "$(docker inspect -f '{{.State.Running}}' "$PREFIX-mssql" 2>/dev/null)" = "true" ]; then
    printf '  .. %-11s creating tina4_test\n' "mssql"
    local ok=0
    for _ in $(seq 1 30); do
      if docker exec "$PREFIX-mssql" sh -c \
        '/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "TinaSQL123!Secure" -C -Q "IF DB_ID('"'"'tina4_test'"'"') IS NULL CREATE DATABASE tina4_test" \
         || /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P "TinaSQL123!Secure" -Q "IF DB_ID('"'"'tina4_test'"'"') IS NULL CREATE DATABASE tina4_test"' \
        >/dev/null 2>&1; then ok=1; break; fi
      sleep 3
    done
    [ "$ok" = "1" ] && c_ok "mssql tina4_test ready" || c_bad "mssql tina4_test could not be created"
  fi

  echo
  c_warn "MQTT is not provisioned (needs generated TLS certs + per-broker auth)."
  c_info "The MQTT tests will SKIP. That is a known gap, not a pass."
  echo
  if [ ${#failed[@]} -gt 0 ]; then
    c_bad "failed: ${failed[*]}"
    echo "  the rest are up; re-run 'infra up' to retry just the failures"
    return 1
  fi
  echo "  all services up. next: eval \"\$(./tina4-lab.sh infra env)\" then run a suite"
}

cmd_infra_down() {
  echo "=== infra down ==="
  local n=0
  for entry in "${SERVICES[@]}"; do
    local cname="$PREFIX-$(svc_field "$entry" 1)"
    if docker rm -f "$cname" >/dev/null 2>&1; then c_ok "removed $cname"; n=$((n+1)); fi
  done
  echo "  removed $n container(s)"
}

cmd_infra_status() {
  echo "=== infra status ==="
  printf '  %-12s %-9s %-16s %s\n' SERVICE STATE PORTS IMAGE
  for entry in "${SERVICES[@]}"; do
    local name cname state ports image
    name="$(svc_field "$entry" 1)"; cname="$PREFIX-$name"
    state="$(docker inspect -f '{{.State.Status}}' "$cname" 2>/dev/null || echo '-')"
    image="$(docker inspect -f '{{.Config.Image}}' "$cname" 2>/dev/null || echo '-')"
    ports="$(svc_field "$entry" 3)"
    printf '  %-12s %-9s %-16s %s\n' "$name" "$state" "$ports" "$image"
  done
  echo
  printf '  %-12s %-9s %-16s %s\n' "mqtt" "-" "1883/8883" "NOT PROVISIONED (tests skip)"
  printf '  %-12s %-9s %-16s %s\n' "firebird" "-" "3050" "excluded by design"
}

# The suites read these. TINA4_REQUIRE_SERVICES=1 is the important one: without
# it a missing service SKIPS instead of failing, and a suite full of skips reads
# like a green run. Exporting it turns "not tested" back into "failed".
cmd_infra_env() {
  cat <<'ENVBLOCK'
export TINA4_REQUIRE_SERVICES=1
export TINA4_TEST_PG_HOST=localhost TINA4_TEST_PG_PORT=55432
export TINA4_TEST_PG_USER=tina4 TINA4_TEST_PG_PASS=tina4 TINA4_TEST_PG_DB=tina4_py
export TINA4_TEST_POSTGRES_URL=postgres://tina4:tina4@localhost:55432/tina4_py
export TINA4_TEST_MONGO_URL=mongodb://localhost:27017
export TINA4_TEST_REDIS_URL=redis://localhost:6379
export TINA4_TEST_VALKEY_URL=redis://localhost:6380
export TINA4_TEST_RABBITMQ_URL=amqp://guest:guest@localhost:5672
export TINA4_TEST_KAFKA_URL=localhost:9092
export TINA4_KAFKA_BROKERS=localhost:9092
export TINA4_TEST_MYSQL_HOST=localhost TINA4_TEST_MYSQL_PORT=3306
export TINA4_TEST_MYSQL_USER=tina4 TINA4_TEST_MYSQL_PASS=tina4 TINA4_TEST_MYSQL_DB=tina4_test
export TINA4_TEST_MSSQL_HOST=localhost TINA4_TEST_MSSQL_PORT=1433
export TINA4_TEST_MSSQL_USER=sa TINA4_TEST_MSSQL_PASS='TinaSQL123!Secure' TINA4_TEST_MSSQL_DB=tina4_test
ENVBLOCK
}

# --- repos -------------------------------------------------------------------
#
# Clone or fast-forward the four framework repos into $ROOT. Tracks v3, the
# staging branch the images are built from -- NOT main, and not a tag: the point
# of a lab box is to verify what is about to ship.
cmd_repos_sync() {
  echo "=== repos sync -> $ROOT (branch v3) ==="
  mkdir -p "$ROOT" || die "cannot create $ROOT"
  local failed=()
  for d in tina4-python tina4-php tina4-ruby tina4-nodejs; do
    if [ -d "$ROOT/$d/.git" ]; then
      printf '  .. %-14s fetching\n' "$d"
      if git -C "$ROOT/$d" fetch -q origin v3 2>/dev/null &&
         git -C "$ROOT/$d" checkout -q v3 2>/dev/null &&
         git -C "$ROOT/$d" merge -q --ff-only origin/v3 2>/dev/null; then
        c_ok "$d at $(git -C "$ROOT/$d" rev-parse --short HEAD)"
      else
        # Never clobber. A colleague may have local work here, and a silent
        # reset would eat it.
        c_warn "$d could not fast-forward (local changes or diverged) -- left untouched"
        failed+=("$d")
      fi
    else
      printf '  .. %-14s cloning\n' "$d"
      if git clone -q -b v3 "https://github.com/tina4stack/$d" "$ROOT/$d" 2>/dev/null; then
        c_ok "$d cloned at $(git -C "$ROOT/$d" rev-parse --short HEAD)"
      else
        c_bad "$d clone failed (private repo? need credentials?)"
        failed+=("$d")
      fi
    fi
  done
  echo
  [ ${#failed[@]} -gt 0 ] && { c_bad "needs attention: ${failed[*]}"; return 1; }
  echo "  all four at origin/v3. next: ./tina4-lab.sh images build"
}

# --- images ------------------------------------------------------------------
#
# Delegated to publish-base-images.sh on purpose. That script already owns the
# boot gate and the version gate; a second copy here would be a second thing to
# keep correct, and the two would drift.
cmd_images() {
  local action="${1:-build}"; shift || true
  local pub="$(dirname "${BASH_SOURCE[0]}")/publish-base-images.sh"
  [ -f "$pub" ] || die "publish-base-images.sh not found beside this script"
  case "$action" in
    build)   bash "$pub" "$@" ;;
    publish) bash "$pub" --push "$@" ;;
    *)       die "images: expected 'build' or 'publish', got '$action'" ;;
  esac
}

# --- derive ------------------------------------------------------------------
#
# The base images exist so a colleague can write:
#
#   FROM docker.io/tina4stack/tina4-nodejs:3.13.92
#   RUN npm install pg
#   COPY src/ /app/src/
#
# This proves that actually works per framework instead of assuming it. It is a
# real check, and it is expected to find that the four are NOT equally
# extensible: the PHP and Ruby runtime stages delete their build tooling
# (install-php-extensions, build-base) to save size, so adding a native driver
# there needs more than one RUN line. Better to learn that here than in a
# colleague's Dockerfile.
cmd_derive() {
  echo "=== derive check: FROM <base> + add a driver ==="
  local tmp; tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  # This table keeps | as its separator (three fields, none containing a pipe).
  #        name|added driver line|load probe
  local CASES=(
    "tina4-nodejs|npm install pg --no-audit --no-fund|node -e \"require('pg');import('@tina4/core').then(()=>console.log('ok'))\""
    "tina4-python|pip install --no-cache-dir redis|python -c \"import redis,tina4_python;print('ok')\""
    "tina4-php|install-php-extensions pdo_pgsql|php -m"
    "tina4-ruby|gem install pg --no-document|ruby -e \"require 'pg'; puts 'ok'\""
  )
  for c in "${CASES[@]}"; do
    local name add probe
    name="$(echo "$c" | cut -d'|' -f1)"
    add="$(echo "$c" | cut -d'|' -f2)"
    probe="$(echo "$c" | cut -d'|' -f3)"
    local base="local/$name:probe"
    docker image inspect "$base" >/dev/null 2>&1 || base="gate/$name:probe"
    if ! docker image inspect "$base" >/dev/null 2>&1; then
      c_warn "$name: no local base image -- run 'images build' first"
      continue
    fi
    printf 'FROM %s\nRUN %s\n' "$base" "$add" > "$tmp/Dockerfile"
    if docker build -t "derive/$name:check" "$tmp" >"$tmp/$name.log" 2>&1; then
      local size out
      size="$(docker run --rm --entrypoint sh "derive/$name:check" -c 'du -sx / 2>/dev/null|cut -f1' \
              | awk '{printf "%.0f MB", $1*1024/1000000}')"
      out="$(docker run --rm --entrypoint sh "derive/$name:check" -c "$probe" 2>&1 | tail -1)"
      c_ok "$name: '$add' built ($size) -- probe: $out"
    else
      c_bad "$name: '$add' FAILED to build"
      tail -4 "$tmp/$name.log" | sed 's/^/        /'
      c_info "the runtime stage likely strips the build tooling this driver needs"
    fi
    docker rmi -f "derive/$name:check" >/dev/null 2>&1
  done
}

# --- dispatch ----------------------------------------------------------------
case "${1:-help}" in
  doctor) shift; cmd_doctor "$@" ;;
  infra)
    shift
    case "${1:-status}" in
      up)     cmd_infra_up ;;
      down)   cmd_infra_down ;;
      status) cmd_infra_status ;;
      env)    cmd_infra_env ;;
      *)      die "infra: expected up|down|status|env" ;;
    esac ;;
  repos)
    shift
    case "${1:-sync}" in
      sync) cmd_repos_sync ;;
      *)    die "repos: expected 'sync'" ;;
    esac ;;
  images) shift; cmd_images "$@" ;;
  derive) shift; cmd_derive "$@" ;;
  help|-h|--help)
    sed -n '2,40p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//' ;;
  *) die "unknown command '${1}'. Try: doctor | infra | images | derive | help" ;;
esac
