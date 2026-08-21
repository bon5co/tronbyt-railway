#!/bin/sh
# Claim the instance for the deployer before the public port is ever served, then hand over
# to the upstream binary.
#
# Tronbyt cannot create a user from the CLI (`reset-password` only updates one that already
# exists), so the account is created through the app's own registration handler while the
# server is bound to loopback on a throwaway port. Nothing outside the container can reach
# it during that window, and the first request the public URL ever serves is against an
# instance that already has an owner.
set -eu

: "${TRONBYT_ADMIN_USERNAME:=}"
: "${TRONBYT_ADMIN_SECRET:=}"
SEED_PORT="${TRONBYT_SEED_PORT:-8099}"

if [ -z "$TRONBYT_ADMIN_SECRET" ] || [ -z "$TRONBYT_ADMIN_USERNAME" ]; then
  echo "[entrypoint] TRONBYT_ADMIN_USERNAME and TRONBYT_ADMIN_SECRET are required." >&2
  echo "[entrypoint] Refusing to boot: an unclaimed Tronbyt server on a public URL belongs" >&2
  echo "[entrypoint] to whoever registers first." >&2
  exit 1
fi

mkdir -p "/app/${DATA_DIR:-data}"

echo "[entrypoint] claiming instance on loopback port $SEED_PORT"
TRONBYT_HOST=127.0.0.1 TRONBYT_PORT="$SEED_PORT" /app/tronbyt-server &
SEED_PID=$!

# First boot clones the system apps repo (~200 MB), so allow a generous window.
i=0
until curl -sf "http://127.0.0.1:${SEED_PORT}/health" >/dev/null 2>&1; do
  i=$((i + 1))
  if [ "$i" -ge 180 ] || ! kill -0 "$SEED_PID" 2>/dev/null; then
    echo "[entrypoint] loopback server never became healthy" >&2
    kill "$SEED_PID" 2>/dev/null || true
    exit 1
  fi
  sleep 1
done

# 303 = the account was created and logged in. 401 = registration is closed because an
# account already exists, which is the normal path on every boot after the first.
CODE=$(curl -s -o /dev/null -w '%{http_code}' -X POST \
  --data-urlencode "username=${TRONBYT_ADMIN_USERNAME}" \
  --data-urlencode "password=${TRONBYT_ADMIN_SECRET}" \
  --data-urlencode "email=${TRONBYT_ADMIN_EMAIL:-admin@example.com}" \
  "http://127.0.0.1:${SEED_PORT}/auth/register" || echo 000)
echo "[entrypoint] register -> $CODE"

kill "$SEED_PID" 2>/dev/null || true
wait "$SEED_PID" 2>/dev/null || true

# Re-apply the credential from the environment on every boot. Upstream exposes no reset flow
# in the UI, so without this a deployer who loses it has no way back into their own instance
# short of deleting the volume.
/app/tronbyt-server reset-password "$TRONBYT_ADMIN_USERNAME" "$TRONBYT_ADMIN_SECRET" \
  || echo "[entrypoint] credential re-apply skipped (user not present)"

echo "[entrypoint] starting server on ${TRONBYT_PORT:-8000}"
exec /app/tronbyt-server
