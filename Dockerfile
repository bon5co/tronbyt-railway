# Tronbyt Server packaged for Railway.
#
# Upstream ships a `scratch` image: one static Go binary, no shell, and therefore no way to
# run anything before the server binds its port. That matters on Railway, because Tronbyt's
# account system is claimable — `ENABLE_USER_REGISTRATION` defaults to true in the Go
# config, and even with it off the *first* account is always allowed, so whoever reaches the
# public URL first owns the instance. Alpine is added purely for a shell and curl so the
# entrypoint can claim the instance for the deployer; the upstream binary is copied in
# unmodified and still does all the work.
FROM ghcr.io/tronbyt/server:2.3.4 AS upstream

FROM alpine:3.22

RUN apk add --no-cache ca-certificates curl tzdata

WORKDIR /app
COPY --from=upstream /app/tronbyt-server /app/tronbyt-server
COPY railway-entrypoint.sh /app/railway-entrypoint.sh
RUN chmod +x /app/railway-entrypoint.sh

# DATA_DIR and DB_DSN are relative to /app, which is where the Railway volume mounts.
ENV DATA_DIR=data \
    DB_DSN=data/tronbyt.db \
    PRODUCTION=true \
    ENABLE_USER_REGISTRATION=false \
    TRONBYT_PORT=8000

EXPOSE 8000
ENTRYPOINT ["/app/railway-entrypoint.sh"]
