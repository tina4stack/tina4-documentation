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
#   sudo ./tina4-lab.sh clients      # install the LANGUAGE clients the suites need
#                                    # (PHP pdo_dblib, Ruby mysql2/tiny_tds/redis).
#                                    # Services alone are not enough: a missing
#                                    # client makes live tests SKIP, not fail.
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
# MQTT IS now provisioned (mosquitto 1883 anon / 1884 auth / 8883 TLS, EMQX 1885).
# It needs a generated CA + server cert + password file, which `docker run` alone
# cannot express, so `infra up` delegates to the in-repo tests/mqtt-infra.sh -- the
# same script CI uses. Verified 2026-07-28: 258 MQTT tests pass across all four
# frameworks against these brokers (py 53, php 50, ruby 78, node 77), zero skips.
#
# WHAT IT DOES NOT COVER, stated so a skip is never mistaken for a pass:
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
#   name^image^port-mapping...^env...^readycmd^container-command
#
# Field 6 (container-command) is optional and is passed to `docker run` AFTER the
# image, so it replaces the image's default CMD. redis-auth is why it exists: the
# cache tests expect `requirepass s3cret` and the readiness probe below already
# assumed it, but the container ran a bare `redis-server` with NO password, so the
# probe's own `-a s3cret` was silently ignored and every auth test skipped. Setting
# it live with `redis-cli CONFIG SET requirepass` worked and then vanished on the
# next container restart. A runtime patch is not provisioning.
SERVICES=(
  "redis^redis:7-alpine^6379:6379^^redis-cli ping"
  "redis-auth^redis:7-alpine^6381:6379^^redis-cli -a s3cret ping^redis-server --requirepass s3cret"
  "valkey^valkey/valkey:8-alpine^6380:6379^^valkey-cli ping"
  "memcached^memcached:alpine^11211:11211^^"
  "mongo^mongo:7^27017:27017^^mongosh --quiet --eval 'db.runCommand({ping:1}).ok'"
  "postgres^postgres:16^55432:5432^POSTGRES_USER=tina4,POSTGRES_PASSWORD=tina4,POSTGRES_DB=tina4_py^pg_isready -U tina4 -d tina4_py"
  "rabbitmq^rabbitmq:3-management^5672:5672,15672:15672^^rabbitmq-diagnostics -q ping"
  "mysql^mysql:8^3306:3306^MYSQL_DATABASE=tina4_test,MYSQL_USER=tina4,MYSQL_PASSWORD=tina4,MYSQL_ROOT_PASSWORD=tina4^mysqladmin ping -h 127.0.0.1 -ptina4"
  "mssql^mcr.microsoft.com/mssql/server:2022-latest^1433:1433^ACCEPT_EULA=Y,SA_PASSWORD=TinaSQL123!Secure,MSSQL_PID=Developer^/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'TinaSQL123!Secure' -C -Q 'SELECT 1' || /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P 'TinaSQL123!Secure' -Q 'SELECT 1'"
  "kafka^apache/kafka:latest^9092:9092^KAFKA_NODE_ID=1,KAFKA_PROCESS_ROLES=broker+controller,KAFKA_LISTENERS=PLAINTEXT://:9092+CONTROLLER://:9093,KAFKA_ADVERTISED_LISTENERS=PLAINTEXT://localhost:9092,KAFKA_CONTROLLER_LISTENER_NAMES=CONTROLLER,KAFKA_LISTENER_SECURITY_PROTOCOL_MAP=CONTROLLER:PLAINTEXT+PLAINTEXT:PLAINTEXT,KAFKA_CONTROLLER_QUORUM_VOTERS=1@localhost:9093,KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR=1,KAFKA_GROUP_INITIAL_REBALANCE_DELAY_MS=0^/opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --list"
  # GreenMail: the ONLY real SMTP+IMAP the Messenger tests can round-trip
  # against. Ruby had 16 IMAP examples pending and Python a matching set,
  # every one reporting "GreenMail not reachable" -- a green skip, which is
  # indistinguishable from "passing" in a suite summary and is exactly how
  # dead coverage stays invisible. auth.disabled is REQUIRED, not laziness:
  # both suites use a unique random recipient per example so each mailbox is
  # created on first access, which cannot work if GreenMail demands a
  # pre-registered user. Ports are GreenMail's plain (non-TLS) 3025/3143,
  # matching the TINA4_MAIL_PORT / TINA4_MAIL_IMAP_PORT defaults in both
  # suites. No readiness probe: the standalone image is a bare JRE with no
  # nc/curl, and a probe that cannot run looks identical to a broken service
  # (see the mongo cautionary note above), so this is deliberately PORT ONLY
  # and the suites' own reachability gate is the real check.
  "greenmail^greenmail/standalone:2.1.3^3025:3025,3143:3143^GREENMAIL_OPTS=-Dgreenmail.setup.test.all -Dgreenmail.hostname=0.0.0.0 -Dgreenmail.auth.disabled^"
)

PREFIX="tina4-lab"

# MQTT deliberately lives OUTSIDE the SERVICES table: it needs a generated CA, a
# server cert and a password file, which is more than `docker run` can express.
# tests/mqtt-infra.sh -- shipped in all four repos, idempotent, self-contained --
# already builds exactly that, so `infra up` calls it instead of reimplementing it
# (reuse ladder: port the proven thing). That script names its containers
# tina4-mosquitto / tina4-emqx, NOT $PREFIX-*, so `infra down` and `infra status`
# have to name them explicitly rather than deriving them from the prefix.
MQTT_HOME="${TINA4_LAB_MQTT_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/mqtt-infra}"
MQTT_CONTAINERS=(tina4-mosquitto tina4-emqx)

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
  # Anchored to THIS SCRIPT's directory, deliberately not to $PWD. A $PWD default
  # makes the repo root depend on where you happened to cd first: the same box
  # ended up with two 98 MB clones at DIFFERENT commits (/root/tina4-repos from a
  # run with TINA4_REPOS set, /root/tina4-lab/tina4-repos from one without), and
  # `images build` would then build whichever was stale. The script's own location
  # is stable; the working directory is not.
  ROOT="${TINA4_LAB_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/tina4-repos}"
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
# --- env contract gate ------------------------------------------------------
#
# WHY THIS EXISTS. The credential env vars have TWO ends: this script EXPORTS
# them (cmd_infra_env) and the four suites READ them. Nothing checked that the
# two agreed, so they drifted: infra env exported TINA4_TEST_MYSQL_USER/_PASS
# while all four suites read TINA4_TEST_MYSQL_USERNAME/_PASSWORD. Every mysql and
# mssql test silently fell through to its own default (root, empty password).
#
# It survived for months because a long-lived container happened to allow
# passwordless root - so the suites were GREEN for the wrong reason - and only
# surfaced when the containers were recreated. It was then diagnosed, written
# down, and STILL not fixed, so it cost a second debugging session.
#
# A note is not a fix. This is the fix: the contract is now machine-checked, so
# the next drift fails here instead of six weeks later as "Access denied".
check_env_contract() {
  local repos="$1" fail=0
  [ -d "$repos" ] || { c_warn "env contract: no repos at $repos -- run 'repos sync' to enable this check"; return 0; }

  local exported
  exported="$(cmd_infra_env 2>/dev/null)"

  # Only CREDENTIAL/CONNECTION vars for services this script provisions. A var a
  # suite reads for its own purposes (TINA4_TEST_MODE, TINA4_TEST_WRITE_PATH...)
  # is not part of the infra contract and must not be flagged.
  local svc='MYSQL|MSSQL|PG|POSTGRES|MONGO|REDIS|VALKEY|MEMCACHED|RABBITMQ|KAFKA|SMTP|IMAP'
  # NOTE: _URL is deliberately NOT here. A *_URL var is an OVERRIDE whose UNSET
  # state is meaningful - the suites compose a credentialed URL from the parts
  # when it is absent. Demanding it be exported made me export a credential-less
  # URL that broke 13 PHP tests which had been passing. The contract this gate
  # guards is the CREDENTIALS and COORDINATES, not the overrides.
  local suffix='USERNAME|PASSWORD|USER|PASS|HOST|PORT|DB'

  local read_vars
  read_vars="$(grep -rhoE "TINA4_TEST_($svc)_($suffix)\b" \
                 "$repos"/tina4-python/tests \
                 "$repos"/tina4-php/tests \
                 "$repos"/tina4-ruby/spec \
                 "$repos"/tina4-nodejs/test 2>/dev/null | sort -u)"

  [ -n "$read_vars" ] || { c_warn "env contract: found no TINA4_TEST_* reads -- check the repo paths"; return 0; }

  local missing=""
  local v
  for v in $read_vars; do
    printf '%s\n' "$exported" | grep -q "\b$v=" || missing="$missing $v"
  done

  if [ -z "$missing" ]; then
    c_ok "env contract: every credential var the suites read is exported ($(printf '%s\n' "$read_vars" | wc -l | tr -d ' ') checked)"
  else
    c_bad "env contract: READ by the suites but NOT exported by 'infra env':"
    for v in $missing; do echo "       $v"; done
    echo "       -> those tests will fall through to their own defaults and fail"
    echo "          misleadingly (e.g. 'Access denied ... using password: NO')."
    fail=1
  fi
  return $fail
}

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

  # CHECK THE DRIVER, not the platform list. The default builder uses the
  # `docker` driver, which lists every qemu-emulable platform and then refuses
  # the actual job: "Multi-platform build is not supported for the docker
  # driver." An earlier version of this check grepped the platform list, passed
  # happily, and the publish still died at push time. A capability check has to
  # test the capability.
  local driver; driver="$(docker buildx inspect 2>/dev/null | awk '/^Driver:/{print $2}')"
  if [ "$driver" = "docker-container" ]; then
    c_ok "buildx driver is docker-container (multi-platform push works)"
  else
    c_bad "buildx driver is '${driver:-unknown}' -- multi-platform push WILL fail at the end of a long build"
    c_info "fix: docker buildx create --name tina4 --driver docker-container --use --bootstrap"
    fail=1
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

  # The credential env vars have two ends and they have drifted before; check
  # that what we export is what the suites actually read.
  check_env_contract "$ROOT" || fail=1

  # A missing language client is as fatal to coverage as a missing service.
  clients_report

  return $fail
}

# --- infra -------------------------------------------------------------------
svc_field() { echo "$1" | cut -d'^' -f"$2"; }

infra_up_one() {
  local entry="$1"
  local name image ports envs ready cmdline
  name="$(svc_field "$entry" 1)"; image="$(svc_field "$entry" 2)"
  ports="$(svc_field "$entry" 3)"; envs="$(svc_field "$entry" 4)"
  ready="$(svc_field "$entry" 5)"; cmdline="$(svc_field "$entry" 6)"
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
  # BIND ADDRESS -- the reason this is not a bare "-p host:container".
  #
  # `docker run -p 27017:27017` publishes on 0.0.0.0, ALL interfaces. That is
  # docker's default and it is invisible in the port string. These mappings were
  # lifted from the CI workflows, where 0.0.0.0 is harmless (ephemeral runner, no
  # inbound route). On a long-lived box it is a door: on 2026-08-01 the mongo here
  # was found by a mass scanner (45.156.87.252), its databases dropped and a
  # READ_ME_TO_RECOVER_YOUR_DATA ransom note written. 86 distinct public IPs had
  # reached it. Every service in this table is unauthenticated BY DESIGN, which is
  # correct for tests and fatal when routable.
  #
  # A host firewall does NOT cover this: docker's DNAT sits in nat/PREROUTING,
  # before ufw filters, so published ports bypass ufw entirely. The only chain
  # governing container traffic is DOCKER-USER (see tina4-lab-firewall.service).
  # Binding here is defence in depth, not the whole control.
  #
  # TINA4_LAB_BIND: comma-separated addresses to publish on. Default 127.0.0.1
  # (loopback only -- reach it over an SSH tunnel). Add a LAN address to share the
  # box. Set "0.0.0.0" only if you have explicitly decided to be reachable by
  # anything that can route to this host.
  local bind_addrs="${TINA4_LAB_BIND:-127.0.0.1}"
  IFS=','
  for p in $ports; do
    for b in $bind_addrs; do args+=(-p "${b}:${p}"); done
  done
  for e in $envs; do
    # '+' stands in for ',' inside a single env value (Kafka listener lists are
    # comma-separated, and ',' is already the field separator here).
    args+=(-e "${e//+/,}")
  done
  IFS="$IFS_SAVE"

  # Field 6 is a flag list, not one argv element, so split it on whitespace.
  local -a cmdargs=()
  [ -n "$cmdline" ] && read -r -a cmdargs <<< "$cmdline"

  printf '  .. %-11s pulling/starting %s\n' "$name" "$image"
  if ! docker run "${args[@]}" "$image" "${cmdargs[@]}" >/dev/null 2>&1; then
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

  # The postgres image creates only POSTGRES_DB (tina4_py), but the suites want
  # more than one database, for two different reasons:
  #
  #   tina4_analytics  the two-database routing tests (Ruby bind_database_spec,
  #                    Node bind-database.test). Without it they bind both handles
  #                    to tina4_py and quietly prove nothing -- Node said exactly
  #                    that: "default=tina4_py, named=tina4_py".
  #   tina4_php        PHP's Postgres tests do NOT read TINA4_TEST_PG_DB; each test
  #   tina4            class names its own database. Four use tina4_php, one uses
  #   tina4_rb         tina4, and OrmBindDatabaseTest uses tina4_rb -- RUBY's
  #                    default name, inside a PHP test. With them absent, 43 PHP
  #                    tests ERROR as "Failed to connect to PostgreSQL", which
  #                    reads like a driver bug and is a missing database.
  #
  #                    tina4_rb was MISSED on the first pass: that file does not
  #                    use the PG_DB constant the others do, so grepping for the
  #                    constant came back short. What caught it was the improved
  #                    PostgresAdapter error, which now names the database it
  #                    wanted -- the old bare "Failed to connect to PostgreSQL"
  #                    would have sent the next reader digging again. If a NEW
  #                    database name ever turns up here, read the error, do not
  #                    re-grep for the constant.
  if [ "$(docker inspect -f '{{.State.Running}}' "$PREFIX-postgres" 2>/dev/null)" = "true" ]; then
    for db in tina4_analytics tina4_php tina4 tina4_rb; do
      if docker exec "$PREFIX-postgres" psql -U tina4 -d tina4_py -tAc \
           "SELECT 1 FROM pg_database WHERE datname='$db'" 2>/dev/null | grep -q 1; then
        c_ok "postgres $db already present"
      else
        printf '  .. %-11s creating %s\n' "postgres" "$db"
        if docker exec "$PREFIX-postgres" createdb -U tina4 "$db" >/dev/null 2>&1; then
          c_ok "postgres $db created"
        else
          c_bad "postgres $db could not be created"
          failed+=("postgres-$db")
        fi
      fi
    done
  fi

  # MQTT: four brokers, generated CA + server cert, and a password file. Delegated
  # to the in-repo script so the lab and CI provision it the same way.
  echo
  local mqtt_script="$ROOT/tina4-python/tests/mqtt-infra.sh"
  if [ ! -f "$mqtt_script" ]; then
    c_warn "MQTT not provisioned -- $mqtt_script not found (run 'repos sync' first)."
    c_info "The MQTT tests will FAIL under TINA4_REQUIRE_SERVICES=1, as they should."
    failed+=("mqtt")
  else
    printf '  .. %-11s provisioning via tests/mqtt-infra.sh\n' "mqtt"
    if bash "$mqtt_script" "$MQTT_HOME" >/dev/null 2>&1; then
      local mqtt_ok=1
      for p in 1883 1884 1885 8883; do
        (exec 3<>/dev/tcp/127.0.0.1/"$p") 2>/dev/null || { c_bad "mqtt port $p not listening"; mqtt_ok=0; }
      done
      [ -s "$MQTT_HOME/certs/ca.crt" ] || { c_bad "mqtt CA missing at $MQTT_HOME/certs/ca.crt"; mqtt_ok=0; }
      if [ "$mqtt_ok" = "1" ]; then
        c_ok "mqtt healthy -- 1883 anon, 1884 auth, 8883 TLS, 1885 EMQX"
      else
        failed+=("mqtt")
      fi
    else
      c_bad "mqtt provisioning script failed"
      failed+=("mqtt")
    fi
  fi
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
  # The MQTT brokers are not $PREFIX-named (tests/mqtt-infra.sh names them), so
  # they have to be removed by name or `infra down` silently leaks four listeners.
  for cname in "${MQTT_CONTAINERS[@]}"; do
    if docker rm -f "$cname" >/dev/null 2>&1; then c_ok "removed $cname"; n=$((n+1)); fi
  done
  echo "  removed $n container(s)"
  c_info "MQTT certs/config left in $MQTT_HOME (re-used on the next 'infra up')"
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
  # Report what the MQTT brokers are ACTUALLY doing. This line used to be a
  # hardcoded "NOT PROVISIONED", which stayed wrong after they were provisioned --
  # a status command that cannot be wrong is not a status command.
  local mstate mports mimage
  for cname in "${MQTT_CONTAINERS[@]}"; do
    mstate="$(docker inspect -f '{{.State.Status}}' "$cname" 2>/dev/null || echo '-')"
    mimage="$(docker inspect -f '{{.Config.Image}}' "$cname" 2>/dev/null || echo 'NOT PROVISIONED')"
    case "$cname" in
      tina4-mosquitto) mports="1883,1884,8883" ;;
      tina4-emqx)      mports="1885" ;;
      *)               mports="-" ;;
    esac
    printf '  %-12s %-9s %-16s %s\n' "${cname#tina4-}" "$mstate" "$mports" "$mimage"
  done
  printf '  %-12s %-9s %-16s %s\n' "firebird" "-" "3050" "excluded by design"
}

# The suites read these. TINA4_REQUIRE_SERVICES=1 is the important one: without
# it a missing service SKIPS instead of failing, and a suite full of skips reads
# like a green run. Exporting it turns "not tested" back into "failed".
cmd_infra_env() {
  # The heredoc stays QUOTED so nothing in it expands by accident; the one value
  # that must vary by machine is substituted afterwards.
  cat <<'ENVBLOCK' | sed "s|MQTT_CA_PLACEHOLDER|$MQTT_HOME/certs/ca.crt|"
export TINA4_REQUIRE_SERVICES=1
export TINA4_TEST_PG_HOST=localhost TINA4_TEST_PG_PORT=55432
export TINA4_TEST_PG_USER=tina4 TINA4_TEST_PG_PASS=tina4 TINA4_TEST_PG_DB=tina4_py
export TINA4_TEST_POSTGRES_URL=postgres://tina4:tina4@localhost:55432/tina4_py
export TINA4_TEST_MONGO_URL=mongodb://localhost:27017
export TINA4_TEST_REDIS_URL=redis://localhost:6379
export TINA4_TEST_VALKEY_URL=redis://localhost:6380
# redis-auth: password is set by the container command in SERVICES, db index 3 is
# what the cache-backend tests use. Without this export the auth tests skipped.
export TINA4_TEST_REDIS_AUTH_URL=redis://:s3cret@localhost:6381/3
export TINA4_TEST_RABBITMQ_URL=amqp://guest:guest@localhost:5672
export TINA4_TEST_KAFKA_URL=localhost:9092
export TINA4_KAFKA_BROKERS=localhost:9092
# The Kafka tests default to a container named `tina4-kafka`; this lab prefixes
# every container with `tina4-lab-`, so without the override they cannot find it.
export TINA4_TEST_KAFKA_CONTAINER=tina4-lab-kafka
# Second Postgres database, for the two-database routing tests. Creating the
# database is NOT enough -- the specs read this env var, and with it unset they
# fall back to a default database name that does not exist here (Ruby defaults to
# "tina4_rb2"). The name is TINA4_TEST_PG_DB_2 with an UNDERSCORE before the 2;
# Ruby's bind_database_spec.rb and Node's bind-database.test.ts both agree on it,
# and an earlier draft of this block wrote TINA4_TEST_PG_DB2, which silently
# satisfied nothing. Python and PHP have no two-database test, so this pair is
# the whole consumer set.
export TINA4_TEST_PG_DB_2=tina4_analytics
export TINA4_TEST_POSTGRES_URL_2=postgres://tina4:tina4@localhost:55432/tina4_analytics
# MQTT: mosquitto on 1883 (anon) / 1884 (auth) / 8883 (TLS), EMQX on 1885.
# Provisioned by `infra up` via the in-repo tests/mqtt-infra.sh.
export TINA4_TEST_MQTT_URL=mqtt://127.0.0.1:1883
export TINA4_TEST_MQTT_AUTH_URL=mqtt://127.0.0.1:1884
export TINA4_TEST_MQTT_TLS_URL=mqtts://127.0.0.1:8883
export TINA4_TEST_MQTT_EMQX_URL=mqtt://127.0.0.1:1885
export TINA4_TEST_MQTT_CA_FILE=MQTT_CA_PLACEHOLDER
export TINA4_TEST_MYSQL_HOST=localhost TINA4_TEST_MYSQL_PORT=3306
# --- vars the suites READ that this block never exported ------------------
# Found by check_env_contract on 2026-08-01. Each was falling through to the
# test's own default. Most of those defaults happen to be localhost + the right
# port, so they passed BY LUCK - the same mechanism that hid the mysql
# credential bug for months and, before that, TINA4_TEST_PG_DB2 (see above).
# Passing by luck is not passing; export them so the lab is the source of truth.
export TINA4_TEST_PG_USERNAME=tina4 TINA4_TEST_PG_PASSWORD=tina4
export TINA4_TEST_MONGO_HOST=localhost TINA4_TEST_MONGO_PORT=27017
export TINA4_TEST_REDIS_HOST=localhost TINA4_TEST_REDIS_PORT=6379
export TINA4_TEST_MEMCACHED_HOST=localhost TINA4_TEST_MEMCACHED_PORT=11211
# GreenMail is the ONLY real SMTP+IMAP the Messenger tests can round-trip.
export TINA4_TEST_SMTP_HOST=localhost TINA4_TEST_SMTP_PORT=3025
export TINA4_TEST_IMAP_HOST=localhost TINA4_TEST_IMAP_PORT=3143
# NOT exported: TINA4_TEST_{MYSQL,MSSQL,PG}_URL. UNSET is LOAD-BEARING for these -
# the suites treat an absent URL as "compose one from the parts above", and they
# compose it WITH credentials. Exporting a credential-less URL displaced that and
# produced 'Access denied for user ...' on 13 PHP tests. A *_URL var is an
# OVERRIDE, not part of the credential contract; see check_env_contract.
# The suites read _USERNAME/_PASSWORD (41 usages across the four); the short
# _USER/_PASS form is read by NOTHING. Exporting only the short form made every
# mysql/mssql test fall through to its own default (root, empty password) and fail
# with 'Access denied ... using password: NO'. It survived for months only because
# a long-lived container happened to allow passwordless root; recreating the
# containers exposed it. Both spellings are emitted so neither side can drift.
export TINA4_TEST_MYSQL_USERNAME=root TINA4_TEST_MYSQL_PASSWORD=tina4
export TINA4_TEST_MYSQL_USER=tina4 TINA4_TEST_MYSQL_PASS=tina4 TINA4_TEST_MYSQL_DB=tina4_test
export TINA4_TEST_MSSQL_HOST=localhost TINA4_TEST_MSSQL_PORT=1433
export TINA4_TEST_MSSQL_USERNAME=sa TINA4_TEST_MSSQL_PASSWORD='TinaSQL123!Secure'
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
  # Hand our resolved root down rather than letting the child re-derive it. It
  # used to guess from its own path, and from /root/tina4-lab that landed on "/"
  # -- all four frameworks reported "no Dockerfile" while sitting right there.
  export TINA4_REPOS="$ROOT"
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

# --- language client libraries -----------------------------------------------
#
# Standing up the SERVICES is only half of it: a suite still skips its live
# tests if the LANGUAGE CLIENT is missing, and a skip is invisible unless
# TINA4_REQUIRE_SERVICES is set. On 2026-07-29 that cost us a genuinely
# incomplete run -- 9 PHP MSSQL tests and 35 Ruby MySQL/MSSQL/Valkey specs had
# never executed on this host, because:
#   * PHP had no pdo_dblib / sqlsrv extension, and
#   * Ruby's :databases bundle group is `optional: true`, so a plain
#     `bundle install` silently skips mysql2 / tiny_tds / redis.
# CI installs these; the lab did not. Provisioning them here is what keeps the
# two honest.

# name^probe^fix
CLIENT_CHECKS=(
  "php pdo_dblib (MSSQL)^php -m 2>/dev/null | grep -qx pdo_dblib^apt-get install -y php8.3-sybase"
  "ruby mysql2^cd '$ROOT/tina4-ruby' 2>/dev/null && bundle exec ruby -e \"require 'mysql2'\" >/dev/null 2>&1^tina4-lab.sh clients"
  "ruby tiny_tds^cd '$ROOT/tina4-ruby' 2>/dev/null && bundle exec ruby -e \"require 'tiny_tds'\" >/dev/null 2>&1^tina4-lab.sh clients"
  "ruby redis^cd '$ROOT/tina4-ruby' 2>/dev/null && bundle exec ruby -e \"require 'redis'\" >/dev/null 2>&1^tina4-lab.sh clients"
)

cmd_clients() {
  [ "$(id -u)" = "0" ] || die "clients: needs root (apt + native gem builds). Re-run with sudo."
  export DEBIAN_FRONTEND=noninteractive

  echo "=== language clients ==="
  c_info "apt: pdo_dblib (PHP MSSQL) + headers mysql2/tiny_tds compile against"
  apt-get update -qq >/dev/null 2>&1
  # default-libmysqlclient-dev -> mysql2; freetds-dev -> tiny_tds;
  # php8.3-sybase -> pdo_dblib.
  if apt-get install -y -qq default-libmysqlclient-dev freetds-dev php8.3-sybase >/dev/null 2>&1; then
    c_ok "apt packages installed"
  else
    c_bad "apt install failed -- see: apt-get install default-libmysqlclient-dev freetds-dev php8.3-sybase"
  fi

  # The :databases group is optional:true, so it must be enabled EXPLICITLY --
  # a bare `bundle install` will keep skipping it however many times you run it.
  if [ -d "$ROOT/tina4-ruby" ]; then
    c_info "ruby: enabling the optional :databases bundle group"
    ( cd "$ROOT/tina4-ruby" \
        && bundle config set --local with databases >/dev/null 2>&1 \
        && bundle install >/dev/null 2>&1 ) \
      && c_ok "bundle install (with databases) done" \
      || c_bad "bundle install failed -- run it by hand in $ROOT/tina4-ruby"
  else
    c_warn "no $ROOT/tina4-ruby -- run 'tina4-lab.sh repos sync' first"
  fi

  clients_report
}

# Report each client's presence. Used by `clients` and by `doctor`, so a missing
# client is visible WITHOUT having to notice a skip count in a suite summary.
clients_report() {
  local missing=0 entry name probe fix
  echo "=== language client status ==="
  for entry in "${CLIENT_CHECKS[@]}"; do
    name="$(echo "$entry" | cut -d'^' -f1)"
    probe="$(echo "$entry" | cut -d'^' -f2)"
    fix="$(echo "$entry" | cut -d'^' -f3)"
    if eval "$probe"; then
      c_ok "$name"
    else
      c_bad "$name MISSING -- live tests using it will SKIP"
      c_info "fix: $fix"
      missing=$((missing + 1))
    fi
  done
  [ "$missing" -eq 0 ] && c_ok "all language clients present" \
    || c_warn "$missing client(s) missing: run 'sudo tina4-lab.sh clients'"
  return 0
}

# --- dispatch ----------------------------------------------------------------
case "${1:-help}" in
  doctor) shift; cmd_doctor "$@" ;;
  clients) shift; cmd_clients "$@" ;;
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
  *) die "unknown command '${1}'. Try: doctor | infra | clients | images | derive | help" ;;
esac
