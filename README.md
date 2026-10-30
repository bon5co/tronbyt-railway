# tronbyt-railway

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/tronbyt-server-or-just-updated-tidbyt-sm?referralCode=Z1xivh&utm_medium=integration&utm_source=template&utm_campaign=generic)

**Deploy on Railway:** [Tronbyt Server template](https://railway.com/deploy/tronbyt-server-or-just-updated-tidbyt-sm?referralCode=Z1xivh&utm_medium=integration&utm_source=template&utm_campaign=generic)

[Tronbyt Server](https://github.com/tronbyt/server) packaged for Railway.

Upstream's image is a `scratch` container holding one static Go binary — ideal for running,
useless for running anything *before* the server binds its port. This image adds a shell and
an entrypoint that does one thing: claim the instance for the deployer before the public URL
serves its first request.

## Why that is needed

`ENABLE_USER_REGISTRATION` defaults to `true` in Tronbyt's Go config, and even when it is set
to `false` the first account is always permitted (`internal/server/auth.go` allows
registration while the user count is zero). A stock deploy therefore goes healthy on a public
URL with an empty user table, and belongs to whoever registers first.

The entrypoint starts the server bound to `127.0.0.1` on a throwaway port, registers the
account named by `TRONBYT_ADMIN_USERNAME` / `TRONBYT_ADMIN_SECRET` through the app's own
handler, stops it, and only then starts the real server. Nothing outside the container can
reach the seeding window.

On every later boot the same credential is re-applied with `tronbyt-server reset-password`,
because upstream exposes no reset flow in the UI — without it, a lost credential means
deleting the volume.

## Variables

| name | required | meaning |
|---|---|---|
| `TRONBYT_ADMIN_USERNAME` | yes | account created on first boot; the image refuses to start without it |
| `TRONBYT_ADMIN_SECRET` | yes | that account's credential, re-applied every boot |
| `TRONBYT_ADMIN_EMAIL` | no | defaults to `admin@example.com` |
| `TRONBYT_SEED_PORT` | no | loopback port used during seeding, default `8099` |
| `ENABLE_USER_REGISTRATION` | no | defaults to `false` here, `true` upstream |

Everything else is upstream's, unchanged — see [tronbyt/server](https://github.com/tronbyt/server).

## Image

`ghcr.io/bon5co/tronbyt-railway:2.3.4`, built from upstream `ghcr.io/tronbyt/server:2.3.4`.
