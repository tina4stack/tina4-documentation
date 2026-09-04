#!/usr/bin/env bash
#
# Tina4 lab test-suite verification — one recipe, four frameworks, green.
#
# Run the FULL test suite for one or all four Tina4 frameworks on the .99 lab,
# AS ROOT, encoding every provisioning gotcha we learned the hard way so a full
# verification takes minutes, not an afternoon. See scripts/LAB-VERIFY.md for the
# why behind each step.
#
# Usage (on the lab, as a user with passwordless sudo):
#     sudo ./lab-verify.sh all              # provision + run all four
#     sudo ./lab-verify.sh python|php|ruby|node
#     sudo ./lab-verify.sh provision        # just (re)provision the services
#
# Overridable via env:
#     TINA4_LAB_ENV   service creds + TINA4_TEST_* vars   (default ~/tina4-test-env-126.sh)
#     TINA4_REL_DIR   dir holding the four framework clones (default ~/rel-3.13.132)
#     TINA4_FB_CONTAINER  Firebird docker container name   (default tina4-lab-firebird)
#
# The suites need root (the session/permission tests drop CAP_DAC_OVERRIDE), so
# run this whole script with sudo.

set -uo pipefail

LAB_ENV="${TINA4_LAB_ENV:-${SUDO_USER:+/home/$SUDO_USER}/tina4-test-env-126.sh}"
LAB_ENV="${LAB_ENV:-$HOME/tina4-test-env-126.sh}"
REL_DIR="${TINA4_REL_DIR:-${SUDO_USER:+/home/$SUDO_USER}/rel-3.13.132}"
REL_DIR="${REL_DIR:-$HOME/rel-3.13.132}"
FB_CONTAINER="${TINA4_FB_CONTAINER:-tina4-lab-firebird}"
FB_DATA="/var/lib/firebird/data"
PY_VENV="$REL_DIR/tina4-python/.venv/bin/python"

fw="${1:-all}"

log() { printf '\n\033[1;36m== %s ==\033[0m\n' "$*"; }

# ---------------------------------------------------------------------------
# Service provisioning — idempotent. Fixes the environment drift that cost us
# an afternoon.
# ---------------------------------------------------------------------------
provision_services() {
  log "provisioning lab services (idempotent)"

  # 1. FIREBIRD WireCrypt.
  #    Firebird 5 defaults to a ChaCha wire-crypt negotiation that node-firebird
  #    2.x cannot complete -> its connect HANGS for the full timeout (looked like
  #    a dead Firebird). The native py/php/ruby clients negotiate it fine, which
  #    is why only Node broke. WireCrypt = Disabled makes every client connect in
  #    plaintext (fine on a localhost lab) and node-firebird connects in ~40ms.
  local wc
  wc="$(docker exec "$FB_CONTAINER" grep -iE '^WireCrypt *=' /opt/firebird/firebird.conf 2>/dev/null | head -1)"
  if ! printf '%s' "$wc" | grep -qi Disabled; then
    echo "  Firebird: WireCrypt -> Disabled (+ restart)"
    docker exec "$FB_CONTAINER" sh -c \
      "grep -qiE '^WireCrypt *=' /opt/firebird/firebird.conf \
        && sed -i 's/^WireCrypt *=.*/WireCrypt = Disabled/I' /opt/firebird/firebird.conf \
        || echo 'WireCrypt = Disabled' >> /opt/firebird/firebird.conf"
    docker restart "$FB_CONTAINER" >/dev/null
    sleep 8
  else
    echo "  Firebird: WireCrypt already Disabled"
  fi

  # 2. POSTGRES per-framework databases. The four frameworks do NOT all share one
  #    PG database: Python/PHP use tina4_py, Ruby tina4_rb, Node tina4_node, and
  #    the two-database routing tests use tina4_analytics. A missing one shows up
  #    as `database "tina4_node" does not exist`.
  local db
  for db in tina4_py tina4_rb tina4_node tina4_analytics; do
    "$PY_VENV" - "$db" <<'PY' 2>/dev/null
import sys, psycopg2
name = sys.argv[1]
conn = psycopg2.connect(host="localhost", port=55432, user="tina4", password="tina4", dbname="tina4_py")
conn.autocommit = True
try:
    conn.cursor().execute(f'CREATE DATABASE {name}')
    print(f"  PG: created {name}")
except Exception:
    pass  # already exists
PY
  done

  # 3. MinIO / S3 is published on host port 9100 (container 9000). The env file's
  #    TINA4_TEST_S3_ENDPOINT may say :9000 -- load_env() overrides it to :9100.
  if (exec 3<>/dev/tcp/127.0.0.1/9100) 2>/dev/null; then echo "  MinIO: reachable on :9100"; else
    echo "  MinIO: WARNING - not reachable on :9100 (S3 tests will fail)"; fi

  log "services ready"
}

# ---------------------------------------------------------------------------
# Per-framework environment.
# ---------------------------------------------------------------------------
load_env() {
  set -a
  # shellcheck disable=SC1090
  [ -f "$LAB_ENV" ] && source "$LAB_ENV" || echo "  WARNING: $LAB_ENV not found (service vars missing)"
  export TINA4_TEST_S3_ENDPOINT="http://localhost:9100"   # MinIO is on 9100, not the env file's 9000
  export TINA4_TEST_S3_URL="http://localhost:9100"
  # mysql2/libmysqlclient uses a UNIX socket for host "localhost"; the lab MySQL is
  # a TCP-only container. 127.0.0.1 forces TCP (Ruby's driver + spec also handle it).
  export TINA4_TEST_MYSQL_HOST="127.0.0.1"
  set +a
}

fb_url() { printf 'firebird://SYSDBA:masterkey@localhost:3050/%s/%s' "$FB_DATA" "$1"; }

# A fresh Mongo test db per run: the queue index is shared, so a leftover index
# from another framework/version used to collide (IndexKeySpecsConflict).
drop_mongo() { "$PY_VENV" -c "import pymongo; pymongo.MongoClient('mongodb://localhost:27017').drop_database('tina4')" 2>/dev/null; }

# ---------------------------------------------------------------------------
# Framework runners. Each is expected GREEN (env-gated skips for graph DBs /
# OIDC / an absent extension are the only skips; there must be 0 failures).
# ---------------------------------------------------------------------------
run_python() {
  log "PYTHON"
  cd "$REL_DIR/tina4-python" || return 1
  load_env; export TINA4_TEST_FIREBIRD_URL="$(fb_url tina4_py.fdb)"; drop_mongo
  .venv/bin/python -m pytest tests/ -p no:cacheprovider -q
}

run_php() {
  log "PHP"
  cd "$REL_DIR/tina4-php" || return 1
  # grpc + openswoole are FORK-HOSTILE and are NOT tina4-php dependencies (they
  # were added to the lab PHP for other work): grpc copies its background-thread
  # mutexes locked across pcntl_fork -> children deadlock on futex_wait; openswoole
  # (enable_coroutine=On) breaks the fork-based worker pool. Run the main suite
  # with both disabled via a filtered conf.d, then run the openswoole test alone
  # WITH openswoole (it skips cleanly without it).
  local base=/etc/php/8.3/cli/conf.d
  rm -rf /tmp/confd_clean /tmp/confd_nogrpc; mkdir -p /tmp/confd_clean /tmp/confd_nogrpc
  local f
  for f in "$base"/*.ini; do
    case "$f" in *grpc*|*swoole*) ;; *) ln -s "$f" /tmp/confd_clean/;; esac
    case "$f" in *grpc*) ;; *) ln -s "$f" /tmp/confd_nogrpc/;; esac
  done
  load_env; export TINA4_TEST_FIREBIRD_URL="$(fb_url tina4_php.fdb)"; drop_mongo
  log "PHP main suite (grpc + openswoole disabled)"
  PHP_INI_SCAN_DIR=/tmp/confd_clean ./vendor/bin/phpunit tests
  local main=$?
  log "PHP openswoole suite (openswoole ON, grpc OFF)"
  PHP_INI_SCAN_DIR=/tmp/confd_nogrpc ./vendor/bin/phpunit tests/AppInvokeSwooleTest.php
  local sw=$?
  return $(( main != 0 || sw != 0 ))
}

run_ruby() {
  log "RUBY"
  cd "$REL_DIR/tina4-ruby" || return 1
  # fb (Firebird) and ruby-odbc live in OPTIONAL bundler groups. A local
  # .bundle/config `with` beats the BUNDLE_WITH env var, and BUNDLE_WITH must be
  # COLON-separated. Set the groups in the config (survives git reset --hard --
  # .bundle/config is untracked) so `bundle exec` actually loads them.
  bundle config set --local with "databases:firebird:odbc" >/dev/null
  bundle install >/dev/null 2>&1
  load_env; export TINA4_TEST_FIREBIRD_URL="$(fb_url tina4_rb.fdb)"; drop_mongo
  bundle exec rspec
}

run_node() {
  log "NODE"
  cd "$REL_DIR/tina4-nodejs" || return 1
  load_env; export TINA4_TEST_FIREBIRD_URL="$(fb_url tina4_node.fdb)"; drop_mongo
  npm test && npm run typecheck
}

# ---------------------------------------------------------------------------
main() {
  if [ "$(id -u)" -ne 0 ]; then
    echo "Run me as root (the suites drop CAP_DAC_OVERRIDE): sudo $0 $fw" >&2
    exit 2
  fi
  local rc=0 name status
  declare -A results
  provision_services
  case "$fw" in
    provision) exit 0 ;;
    python) run_python; results[python]=$? ;;
    php)    run_php;    results[php]=$? ;;
    ruby)   run_ruby;   results[ruby]=$? ;;
    node)   run_node;   results[node]=$? ;;
    all)
      run_python; results[python]=$?
      run_php;    results[php]=$?
      run_ruby;   results[ruby]=$?
      run_node;   results[node]=$?
      ;;
    *) echo "usage: sudo $0 all|python|php|ruby|node|provision" >&2; exit 2 ;;
  esac
  log "SUMMARY"
  for name in python php ruby node; do
    status="${results[$name]:-}"
    [ -z "$status" ] && continue
    if [ "$status" -eq 0 ]; then printf '  \033[1;32mPASS\033[0m  %s\n' "$name"
    else printf '  \033[1;31mFAIL\033[0m  %s (exit %s)\n' "$name" "$status"; rc=1; fi
  done
  exit "$rc"
}

main
