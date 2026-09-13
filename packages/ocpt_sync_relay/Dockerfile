# SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
#
# SPDX-License-Identifier: Apache-2.0

# The relay: one binary, one port, one SQLite file (see this package's own README.md).
#
# Build context: the REPOSITORY ROOT, not this directory, because ocpt_sync_relay depends on the
# sibling package ocpt_sync_protocol through a relative `path: ../ocpt_sync_protocol` dependency,
# so both packages have to be present in the build context for `dart pub get` to resolve it. Build
# it from the repository root with:
#
#   docker build -f packages/ocpt_sync_relay/Dockerfile -t ocpt_sync_relay .
#
# ../../docker-compose.yml (this package's own) already points its `context`/`dockerfile` there.

FROM dart:3.12.2 AS build

WORKDIR /build

# Copy both packages before `dart pub get` runs, so the relative path dependency resolves.
COPY packages/ocpt_sync_protocol packages/ocpt_sync_protocol
COPY packages/ocpt_sync_relay packages/ocpt_sync_relay

WORKDIR /build/packages/ocpt_sync_relay
RUN dart pub get
RUN dart compile exe bin/ocpt_sync_relay.dart -o bin/server

FROM debian:trixie-slim AS runtime

# libsqlite3-0 is the only thing the compiled exe needs at runtime: `package:sqlite3` dlopens it
# rather than linking it statically. No compiler, no Dart SDK, no -dev headers.
RUN apt-get update \
    && apt-get install -y --no-install-recommends libsqlite3-0 \
    && rm -rf /var/lib/apt/lists/*

# A dedicated, unprivileged user; no login shell, since nothing ever needs to shell into it.
RUN useradd --system --create-home --home-dir /home/relay --shell /usr/sbin/nologin relay \
    && mkdir -p /data \
    && chown relay:relay /data

COPY --from=build /build/packages/ocpt_sync_relay/bin/server /usr/local/bin/ocpt_sync_relay

USER relay
WORKDIR /home/relay

# /data is where the compose file's named volume mounts, and this is only a default: an operator
# overriding OCPT_RELAY_DB_PATH is still writing under a path owned by the `relay` user, unless
# they also change where the volume is mounted.
ENV OCPT_RELAY_DB_PATH=/data/relay.sqlite

EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/ocpt_sync_relay"]
