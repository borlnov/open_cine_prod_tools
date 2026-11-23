# Joining a project

<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: CC-BY-4.0
-->

Joining is how a shared project reaches a device that does not have it yet — a new tablet on set,
a producer's laptop, anyone the invite from [Sharing a project](sharing-a-project.md) was sent to.

## Opening the joining screen

From the home screen's toolbar, choose **Join a shared project…** (on a phone, it is in the
toolbar's **⋮** menu). Unlike opening a project, joining does not need one already on your device
— that is the point of it — so it is reachable at all times from the home screen, not from inside
a project you would need to have first.

The screen that opens is titled "Join a shared project", with a "No local copy yet" badge and two
tabs: **Scan (tablet)** and **Enter manually**.

![The Join a shared project screen](/img/screenshots/collab-join.png)

## Scanning or pasting the invite

You need the invite someone shared with you, in whichever form it reached you:

- **On a tablet or phone**, the screen opens on the **Scan (tablet)** tab, which offers a camera
  scan: point the camera at the QR code shown on the sharing screen of the device that invited
  you.
- **On desktop**, the screen opens on **Enter manually**: paste the **Invite link** you were sent
  into that field, then choose **Join**. A computer has no camera scan here — its Scan tab only
  says "Camera unavailable".

Either way resolves to the same invite; there is nothing else to configure. A banner on the
screen reminds you what joining does: it creates a full local copy of the project by downloading
the relay's snapshot, then keeps syncing, and a new card appears on the home screen once it is
done. If the code or link is not a valid invite, a message at the bottom of the screen says the
project could not be joined and asks you to check the invite link.

## What joining actually does

Confirming the invite:

1. Asks where the project lands: on a computer, a folder picker lets you choose — it suggests the
   folder you last saved a project in, and its confirm button reads **Join here** — and the
   project creates its own folder inside whichever one you pick; on a tablet or phone, where
   there is no such dialog, it is placed alongside your other projects automatically. Cancelling
   the picker cancels the join.
2. Shows a progress panel — "Connecting to the relay…", "Downloading the project…", "Opening…" —
   while it downloads the project's current content from the relay named in the invite, into a
   fresh project file there, and records the project's pairing, so your device is now syncing
   against the same relay as everyone else who joined it. A **Cancel** button stops it.
3. Ends on "Project retrieved", with an **Open** button that takes you into the project.

From here your device behaves like any other one holding the project: it has a full copy, works
offline, and syncs its edits the moment it can reach the relay again — see
[How collaboration works](how-collaboration-works.md) for what that means day to day.

## If you cannot reach the relay

Joining needs a working connection to the relay at the moment you join, since it has to download
the project. If the relay is unreachable — no network on set, an address that changed — the join
stops with the same "Could not join this project" message. Wait until you have a connection, or
ask whoever is hosting to hand you a fresh invite if the relay itself has moved (see
[The on-set server](on-set-server.md)).
