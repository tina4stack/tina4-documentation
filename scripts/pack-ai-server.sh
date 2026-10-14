#!/usr/bin/env bash
# Pack examples/ai-server into docs/public/ai-server.tar.gz - the artifact that
# https://tina4.com/ai-server.sh downloads and runs. Re-run this whenever the
# bundle under examples/ai-server changes, and commit the refreshed tarball.
#
#   scripts/pack-ai-server.sh
set -euo pipefail
cd "$(dirname "$0")/.."          # docs repo root

OUT="docs/public/ai-server.tar.gz"
cd examples
tar -czf "../$OUT" \
  --exclude='ai-server/.venv' \
  --exclude='ai-server/models' \
  --exclude='ai-server/logs' \
  --exclude='ai-server/data' \
  --exclude='ai-server/secrets' \
  --exclude='ai-server/.env.local' \
  --exclude='*/__pycache__' \
  --exclude='*.pyc' \
  ai-server
cd ..
echo "wrote $OUT"
echo "--- contents ---"
tar -tzf "$OUT"
