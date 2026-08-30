<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# ocpt_sync_relay

A self-hostable, single-tenant server for Open Cine Prod Tools' offline-first sync
(`docs/adr/0009-offline-first-sync-through-a-domain-blind-relay.md`).

One binary, one port, one SQLite file. It exposes five routes over one bearer token per project —
append a changeset, read changesets since a sequence number, upload a snapshot, fetch the latest
snapshot, and a WebSocket announcing new work — and it never parses a changeset or learns a table
name: the domain model on top of it can change without ever redeploying this server. If you are
looking for what it does internally rather than how to run it, start at `lib/ocpt_sync_relay.dart`
and `docs/plans/collaboration-and-sync.md` instead; this file is only the self-hoster's guide.

This is not a multi-tenant hosted service. One instance is for one person or one production
(§5.1 below): hosting a second person means running a second instance, not adding an account to
this one.

## The two secrets

There are exactly two secrets, and **neither is ever typed by a human into the server** — see
`docs/plans/collaboration-and-sync.md` §5.2 for the full table this summarises.

| | Enrolment secret | Project token |
| --- | --- | --- |
| Scope | one relay instance | one project |
| Set by | the operator, as an environment variable, once | the client app, when pairing |
| Handed to | the one person that instance is for, once, out of band | each crew member, by QR code |
| Opens | creating *new* projects on that instance | reading and writing that project, entirely |
| If it leaks | someone fills the disk with projects, reads none of the existing ones | that project is fully exposed |

So the operator picks the enrolment secret and sets it as `OCPT_RELAY_ENROLMENT_SECRET` before the
relay ever starts; it is never entered into any prompt or UI the relay itself presents, because it
has none. A project's token is minted by the client app at pairing time and stored in the app's own
secure storage, never on this server beyond a fast hash of it (the token is full-entropy machine
output, not a human password, so there is nothing to defend against a dictionary attack). Rotating
a project token means re-pairing the crew; rotating the enrolment secret costs nothing, since it is
only ever read when a project is created.

## Environment variables

| Variable | Required | Default | Meaning |
| --- | --- | --- | --- |
| `OCPT_RELAY_ENROLMENT_SECRET` | yes | — | The instance enrolment secret above. The relay refuses to start without it. |
| `OCPT_RELAY_PORT` | no | `8080` | The TCP port the relay listens on. |
| `OCPT_RELAY_ADDRESS` | no | `0.0.0.0` | The address the relay binds to. `0.0.0.0` is what makes it reachable from outside its own container; change it only if you know you need to. |
| `OCPT_RELAY_DB_PATH` | no | `relay.sqlite` | The SQLite file the relay's changesets and snapshots are stored in. The Docker image sets this to `/data/relay.sqlite`, matching the named volume the compose file mounts there. |

Generate an enrolment secret with any source of high-entropy randomness, for example:

```sh
openssl rand -hex 32
```

## Running it

The package root's `Dockerfile` and `docker-compose.yml` are the supported way to run this in
production. From this directory:

```sh
OCPT_RELAY_ENROLMENT_SECRET=<the secret you generated> docker compose up -d
```

This builds the image, starts one relay instance, persists its SQLite file in a named Docker
volume (`relay-data`), and binds the relay to `127.0.0.1:8080` only — nothing but the host itself
can reach it directly. See the `docker-compose.yml` file itself for how a second person on the same
host is a second service, not a second tenant of this one.

Building the image directly (without compose) has to be done from the **repository root**, not
from this directory, because this package depends on the sibling package `ocpt_sync_protocol`
through a relative `path:` dependency, and both packages have to be inside the build context for
`dart pub get` to resolve it:

```sh
docker build -f packages/ocpt_sync_relay/Dockerfile -t ocpt_sync_relay .
```

The `docker-compose.yml` file already points its own `context`/`dockerfile` there, so `docker
compose up` from this directory needs no extra flag.

Running the compiled binary directly, with no container at all, works the same way once the two
sibling packages are on disk together — set the environment variables above and run
`dart run bin/ocpt_sync_relay.dart` from this package's own directory, or run the binary
`dart compile exe` produces. `SIGINT`/`SIGTERM` shut it down cleanly (closing the listening socket
and the SQLite database); `SIGTERM` is not delivered on Windows, so only `SIGINT` (Ctrl+C) applies
there.

## TLS and the reverse proxy

This server speaks plain HTTP and WebSocket, with no TLS of its own — it is meant to sit behind a
TLS-terminating reverse proxy (Caddy, nginx, Traefik, or similar), which is deliberately not
bundled here: a self-hoster who already runs one for other services should not be made to run a
second. Whatever fronts this relay is what keeps a bearer token off the wire; point it at the
address/port above and it takes care of the rest.

## License

Licensed under the Apache-2.0 license, like the rest of Open Cine Prod Tools. See the repository's
[LICENSES](../../LICENSES/) directory for the full license text.
