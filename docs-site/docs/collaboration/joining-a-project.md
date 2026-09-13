# Joining a project

<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: CC-BY-4.0
-->

Joining is how a shared project reaches a device that does not have it yet — a new tablet on set,
a producer's laptop, anyone the invite from [Sharing a project](sharing-a-project.md) was sent to.

## Opening the joining screen

From the home screen's toolbar, choose **Rejoindre**. Unlike opening a project, joining does not
need one already on your device — that is the point of it — so it is reachable at all times from
the home screen, not from inside a project you would need to have first.

## Scanning or pasting the invite

You need the invite someone shared with you, in whichever form it reached you:

- **On a tablet or phone**, the screen offers a **camera scan**: point the camera at the QR code
  shown on the sharing screen of the device that invited you.
- **On desktop**, paste the **invite link** you were sent instead, into the field the screen
  offers.

Either way resolves to the same invite; there is nothing else to configure.

## What joining actually does

Confirming the invite:

1. Downloads the project's current content from the relay named in the invite, into a fresh
   project file on your device.
2. On desktop, you choose where to save that file, exactly as you would when creating a new
   project; on a tablet or phone, it is placed alongside your other projects automatically.
3. Records the project's pairing, so your device is now syncing against the same relay as
   everyone else who joined it.
4. Opens the project.

From here your device behaves like any other one holding the project: it has a full copy, works
offline, and syncs its edits the moment it can reach the relay again — see
[How collaboration works](how-collaboration-works.md) for what that means day to day.

## If you cannot reach the relay

Joining needs a working connection to the relay at the moment you join, since it has to download
the project. If the relay is unreachable — no network on set, an address that changed — wait until
you have a connection, or ask whoever is hosting to hand you a fresh invite if the relay itself
has moved (see [The on-set server](on-set-server.md)).
