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
#     TINA4_MAIL_INFRA_DIR  TLS mail servers' CA + certs     (default ~/tina4-lab-mail-infra)
#
# The suites need root (the session/permission tests drop CAP_DAC_OVERRIDE), so
# run this whole script with sudo.

set -uo pipefail

# The invoking user's home under sudo, else $HOME. (The old two-step fallback never
# fired without SUDO_USER: "${SUDO_USER:+...}/file" is already non-empty "/file".)
LAB_HOME="${SUDO_USER:+/home/$SUDO_USER}"
LAB_HOME="${LAB_HOME:-$HOME}"
LAB_ENV="${TINA4_LAB_ENV:-$LAB_HOME/tina4-test-env-126.sh}"
# Live graph-database coordinates (Neo4j, Memgraph, ArangoDB, Ultipa) live in their own
# file on the lab. Sourcing it arms the graph specs; without it they skip with a tag.
GRAPH_ENV="${TINA4_GRAPH_ENV:-$LAB_HOME/graph-test-env.sh}"
REL_DIR="${TINA4_REL_DIR:-$LAB_HOME/rel-3.13.132}"
FB_CONTAINER="${TINA4_FB_CONTAINER:-tina4-lab-firebird}"
FB_DATA="/var/lib/firebird/data"
PY_VENV="$REL_DIR/tina4-python/.venv/bin/python"
MAIL_DIR="${TINA4_MAIL_INFRA_DIR:-$LAB_HOME/tina4-lab-mail-infra}"
MAIL_PREFIX="tina4-lab-mail"

fw="${1:-all}"

log() { printf '\n\033[1;36m== %s ==\033[0m\n' "$*"; }

# ---------------------------------------------------------------------------
# Service provisioning — idempotent. Fixes the environment drift that cost us
# an afternoon.
# ---------------------------------------------------------------------------
provision_services() {
  log "provisioning lab services (idempotent)"

  # 1. FIREBIRD WireCrypt = Enabled.
  #    With WireCrypt = Disabled every node-firebird attach fails "Unavailable
  #    database"; with Enabled all four clients (node-firebird and the native
  #    py/php/ruby clients) connect. This step used to force Disabled, but the lab
  #    container's env (FIREBIRD_CONF_WireCrypt=Enabled) re-applies Enabled on
  #    every start, so the restart below silently undid it and masked the bug.
  #    Set it (and restart) only when the value differs.
  local wc
  wc="$(docker exec "$FB_CONTAINER" grep -iE '^WireCrypt *=' /opt/firebird/firebird.conf 2>/dev/null | head -1)"
  if ! printf '%s' "$wc" | grep -qiE '= *Enabled *$'; then
    echo "  Firebird: WireCrypt -> Enabled (+ restart)"
    docker exec "$FB_CONTAINER" sh -c \
      "grep -qiE '^WireCrypt *=' /opt/firebird/firebird.conf \
        && sed -i 's/^WireCrypt *=.*/WireCrypt = Enabled/I' /opt/firebird/firebird.conf \
        || echo 'WireCrypt = Enabled' >> /opt/firebird/firebird.conf"
    docker restart "$FB_CONTAINER" >/dev/null
    sleep 8
  else
    echo "  Firebird: WireCrypt already Enabled"
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

  # 4. TLS + AUTH MAIL SERVERS for the Messenger transport specs.
  provision_mail_tls

  log "services ready"
}

# The TLS + AUTH mail servers the Messenger transport specs drive, ported from
# tina4-ruby spec/support/mail-infra.sh (same images, ports, account, certs).
# The specs fix the ports and the account; only the host and the CA travel
# through TINA4_TEST_MAIL_TLS_HOST / TINA4_TEST_MAIL_TLS_CA_FILE (load_env).
#
#   4025 GreenMail SMTP + AUTH     4465 GreenMail SMTPS      4143 GreenMail IMAP + LOGIN
#   4993 GreenMail IMAPS           4587 Mailpit SMTP STARTTLS + AUTH   4825 Mailpit API
#   4144 Dovecot IMAP STARTTLS     (all on 127.0.0.1; clear of GreenMail 3025/3143, 3925/3943)
#
# Unlike mail-infra.sh, which recreates its containers every run, this leaves
# running containers alone: other workers may be mid-suite. A container is
# (re)created only when it is missing, stopped, or was started with a different
# CA (label tina4.mail.ca). The certs live in a persistent dir (not /tmp, which
# would pull them from under the bind mounts) and are regenerated only when
# missing or within 30 days of expiry. A lock serialises concurrent provisioners.
provision_mail_tls() {
  mkdir -p "$MAIL_DIR/certs" || { echo "  Mail TLS: WARNING - cannot create $MAIL_DIR"; return 0; }
  (
    flock -w 300 9 || { echo "  Mail TLS: WARNING - lock busy, skipped"; exit 0; }
    cd "$MAIL_DIR" || exit 0
    local user="tina4" pass="mail-secret" ca_sum name port tries greeting failed=0
    if ! { [ -f certs/ca.crt ] && [ -f certs/greenmail.p12 ] && [ -f certs/mailpit-auth ] \
           && openssl x509 -checkend 2592000 -noout -in certs/server.crt >/dev/null 2>&1; }; then
      # The CA needs basicConstraints AND keyUsage or modern OpenSSL will not treat
      # it as a CA; the server cert covers localhost AND 127.0.0.1.
      printf '%s\n' '[req]' 'distinguished_name=dn' 'x509_extensions=v3_ca' 'prompt=no' \
        '[dn]' 'CN=tina4-mail-test-ca' '[v3_ca]' 'basicConstraints=critical,CA:TRUE' \
        'keyUsage=critical,keyCertSign,cRLSign' 'subjectKeyIdentifier=hash' > certs/ca.cnf
      printf '%s\n' 'basicConstraints=CA:FALSE' 'keyUsage=critical,digitalSignature,keyEncipherment' \
        'extendedKeyUsage=serverAuth' 'subjectAltName=DNS:localhost,IP:127.0.0.1' > certs/srv.ext
      openssl req -x509 -newkey rsa:2048 -nodes -keyout certs/ca.key -out certs/ca.crt \
        -days 365 -config certs/ca.cnf >/dev/null 2>&1 &&
      openssl req -newkey rsa:2048 -nodes -keyout certs/server.key -out certs/server.csr \
        -subj "/CN=localhost" >/dev/null 2>&1 &&
      openssl x509 -req -in certs/server.csr -CA certs/ca.crt -CAkey certs/ca.key -CAcreateserial \
        -out certs/server.crt -days 365 -extfile certs/srv.ext >/dev/null 2>&1 &&
      openssl pkcs12 -export -in certs/server.crt -inkey certs/server.key -name greenmail \
        -out certs/greenmail.p12 -passout pass:changeit >/dev/null 2>&1 ||
        { echo "  Mail TLS: WARNING - cert generation failed"; exit 0; }
      printf '%s:%s\n' "$user" "$pass" > certs/mailpit-auth
      chmod 644 certs/*
      echo "  Mail TLS: certs generated in $MAIL_DIR/certs"
    fi
    ca_sum="$(sha256sum certs/ca.crt | cut -c1-16)"

    # ensure <suffix> <docker run args...>
    ensure() {
      name="$MAIL_PREFIX-$1"; shift
      if [ "$(docker inspect -f '{{.State.Running}} {{index .Config.Labels "tina4.mail.ca"}}' "$name" 2>/dev/null)" \
           = "true $ca_sum" ]; then
        echo "  Mail TLS: $name already running"; return 0
      fi
      echo "  Mail TLS: (re)creating $name"
      docker rm -f "$name" >/dev/null 2>&1
      docker run -d --name "$name" --restart unless-stopped --label "tina4.mail.ca=$ca_sum" "$@" >/dev/null \
        || echo "  Mail TLS: WARNING - could not start $name (port already taken?)"
    }
    # GreenMail: auth NOT disabled, one pre-registered account, PKCS#12 keystore.
    ensure greenmail \
      -p 127.0.0.1:4025:3025 -p 127.0.0.1:4465:3465 -p 127.0.0.1:4143:3143 -p 127.0.0.1:4993:3993 \
      -v "$MAIL_DIR/certs:/certs:ro" \
      -e GREENMAIL_OPTS="-Dgreenmail.setup.test.all -Dgreenmail.hostname=0.0.0.0 -Dgreenmail.users=$user:$pass@tina4.test -Dgreenmail.tls.keystore.file=/certs/greenmail.p12 -Dgreenmail.tls.keystore.password=changeit" \
      greenmail/standalone:2.1.3
    # Mailpit: MAIL before STARTTLS is refused, so a client that skipped the upgrade cannot pass.
    ensure mailpit -p 127.0.0.1:4587:1025 -p 127.0.0.1:4825:8025 -v "$MAIL_DIR/certs:/certs:ro" \
      axllent/mailpit:v1.27 --smtp-tls-cert /certs/server.crt --smtp-tls-key /certs/server.key \
      --smtp-require-starttls --smtp-auth-file /certs/mailpit-auth
    # Dovecot: the image's own config (static passdb, ssl=yes); only the key pair is ours.
    ensure dovecot --platform linux/amd64 -p 127.0.0.1:4144:143 \
      -v "$MAIL_DIR/certs/server.crt:/etc/dovecot/cert.pem:ro" \
      -v "$MAIL_DIR/certs/server.key:/etc/dovecot/key.pem:ro" dovecot/dovecot:2.3.21

    # Wait for a GREETING, not just an open port: docker-proxy accepts first.
    for port in 4025 4143 4587 4144; do
      for tries in $(seq 1 90); do
        greeting=$( (exec 3<>"/dev/tcp/127.0.0.1/$port" && head -c 3 <&3) 2>/dev/null ) &&
          { [ "$greeting" = "220" ] || [ "$greeting" = "* O" ]; } && break
        sleep 1
      done
    done
    for port in 4025 4143 4587 4144 4465 4993 4825; do
      (exec 3<>"/dev/tcp/127.0.0.1/$port") 2>/dev/null || { echo "  Mail TLS: WARNING - :$port DOWN"; failed=1; }
    done
    [ "$failed" -eq 0 ] && echo "  Mail TLS: 4025 4143 4587 4144 4465 4993 4825 up (CA $MAIL_DIR/certs/ca.crt)"
  ) 9>"$MAIL_DIR/.lock"
}

# ---------------------------------------------------------------------------
# Per-framework environment.
# ---------------------------------------------------------------------------
load_env() {
  set -a
  # shellcheck disable=SC1090
  [ -f "$LAB_ENV" ] && source "$LAB_ENV" || echo "  WARNING: $LAB_ENV not found (service vars missing)"
  # shellcheck disable=SC1090
  [ -f "$GRAPH_ENV" ] && source "$GRAPH_ENV" || echo "  WARNING: $GRAPH_ENV not found (graph specs will skip)"
  export TINA4_TEST_S3_ENDPOINT="http://localhost:9100"   # MinIO is on 9100, not the env file's 9000
  export TINA4_TEST_S3_URL="http://localhost:9100"
  # mysql2/libmysqlclient uses a UNIX socket for host "localhost"; the lab MySQL is
  # a TCP-only container. 127.0.0.1 forces TCP (Ruby's driver + spec also handle it).
  export TINA4_TEST_MYSQL_HOST="127.0.0.1"
  # The TLS mail servers from provision_mail_tls (ports + account are fixed by the specs).
  export TINA4_TEST_MAIL_TLS_HOST="127.0.0.1"
  export TINA4_TEST_MAIL_TLS_CA_FILE="$MAIL_DIR/certs/ca.crt"
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
  # Ultipa needs ext-grpc, which is off here; its cases run in the graph pass below.
  env -u TINA4_TEST_ULTIPA_URL PHP_INI_SCAN_DIR=/tmp/confd_clean ./vendor/bin/phpunit tests
  local main=$?
  log "PHP openswoole suite (openswoole ON, grpc OFF)"
  PHP_INI_SCAN_DIR=/tmp/confd_nogrpc ./vendor/bin/phpunit tests/AppInvokeSwooleTest.php
  local sw=$?
  # The graph drivers are composer "suggest" entries, not dependencies (ultipa needs
  # ext-grpc, which would break a plain `composer install` elsewhere). Install them
  # into vendor/ for the lab only, then restore composer.json/lock so the tree the
  # suite ran against is the committed one plus the suggested drivers.
  log "PHP graph drivers (lab-only) + graph suite (grpc ON, openswoole OFF)"
  COMPOSER_ALLOW_SUPERUSER=1 composer require --dev --no-interaction --no-scripts --quiet \
    laudis/neo4j-php-client triagens/arangodb tina4stack/ultipa || return 1
  git checkout -- composer.json composer.lock 2>/dev/null
  PHP_INI_SCAN_DIR=/tmp/confd_nogrpc ./vendor/bin/phpunit tests/GraphTest.php
  local graph=$?
  return $(( main != 0 || sw != 0 || graph != 0 ))
}

run_ruby() {
  log "RUBY"
  cd "$REL_DIR/tina4-ruby" || return 1
  # fb (Firebird) and ruby-odbc live in OPTIONAL bundler groups. A local
  # .bundle/config `with` beats the BUNDLE_WITH env var, and BUNDLE_WITH must be
  # COLON-separated. Set the groups in the config (survives git reset --hard --
  # .bundle/config is untracked) so `bundle exec` actually loads them.
  # :graph brings tina4-ultipa (native grpc) for the live Ultipa specs.
  bundle config set --local with "databases:firebird:odbc:graph" >/dev/null
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
