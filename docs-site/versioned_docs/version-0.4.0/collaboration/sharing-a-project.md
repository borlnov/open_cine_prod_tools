# Sharing a project

<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: CC-BY-4.0
-->

Sharing turns a project that only lives on your device into one the rest of the crew can join.
Read [How collaboration works](how-collaboration-works.md) first if you have not — it explains
what "shared" actually means before you turn it on.

## Opening the sharing screen

There are two ways in. From the **home screen**, open a project's card **⋮** menu and choose
**Share / Sync…** (the same menu also has Export… and Remove from list). And once a project is
shared, the same screen is also one click away from inside the open project, through the sync
status indicator's panel — **Show the invite QR code** or **Re-pair…**, see
[How collaboration works](how-collaboration-works.md#the-sync-status-indicator). A project that
is not shared yet has no indicator, so its card menu is where sharing starts.

![The project card's ⋮ menu open on Share / Sync…](/img/screenshots/collab-share-menu.png)

The screen that opens is titled `Share "<project name>"`, with a "① Configure" step and a "Not
paired" badge at the top right. On a computer, a segmented toggle splits it into two ways of
sharing: **Remote relay** (the default, covered next) and **Host on this machine** (covered
below). Sharing needs a place for every device to meet either way — a **relay** already running
somewhere (a self-hosted server, or one a colleague set up), or your own machine acting as one.

## Pairing to a relay

If you already know a relay's address — the one your production runs, or one you host yourself —
keep the **Remote relay** option and enter:

- the **Relay address** (an address such as `https://relay.example.org`);
- the **Enrolment secret** that relay's operator gave you, which stays hidden unless you click
  the eye at the end of the field.

![The Configure step of the remote-relay sharing screen](/img/screenshots/collab-share.png)

A note under these fields explains that a project token is generated automatically and kept in
secure storage — it is never written to the project file. Confirming with **Pair and create on
the relay** **pairs** the project to that relay: it sends your project's current content so the
next person who joins can download it, and starts syncing. If the address or the secret is wrong,
a message at the bottom of the screen says the pairing failed and asks you to check them. From
this point on, the project is shared.

## The invite

Once paired, the screen moves to its second step — the badges now read "② Invite" and "In sync"
— and shows an **Invite your team** card: the project's QR code, with **Save the QR code…** and
**Copy the invite link** underneath. Anyone who scans the QR or opens the link can join the
project — see [Joining a project](joining-a-project.md) for what that looks like on their side.

Share the QR by pointing a colleague's camera at your screen, or send the copied link however you
would send any other link (chat, email). The invite carries no password of its own to read out
loud; whoever holds the QR or the link can join, so treat it the way you would a shared document
link.

A **Connection** card below shows the relay's address and the project token, which is hidden
until you choose the reveal icon next to it.

A **Stop sharing…** button sits at the bottom, for when a project should no longer accept new
devices or sync further. Because it cannot be undone from the screen, it asks you first —
"Stop sharing this project?" — and explains that every device that already holds a copy keeps it
but stops sending and receiving changes.

## Hosting the relay yourself

If no relay is available, or the shoot has no internet at all, switching the segmented toggle to
**Host on this machine** offers a **Hosting** switch (it reads "Stopped" while off, then
"Starting…" and "Online", or "Hosting could not start" if something went wrong) that turns your
own device into the relay everyone else connects to, with nothing separate to install or run.
This is the right choice for a laptop that is already open on the project — the video-village
machine on a shoot, or a producer's own computer acting as the project's long-term meeting point
between shoots.

![The Host on this machine panel](/img/screenshots/collab-host.png)

While the switch is on, the panel also shows:

- the **Advertised address** the others will be told to reach (a drop-down, for a machine that
  sits on several networks) and the **Port**, which you can change and **Apply**;
- a QR code and a copy-link button, with two choices: **Send the project to a device** (for a
  device that does not have the project yet — it scans it from **Join a shared project…**) and
  **Redirect a device that already has it** (for a device that already has the project — it
  scans it from **Switch relay…**);
- a **Connected** list of the devices currently on your relay, or "No one has joined yet";
- **Reconcile upstream…**, which sends the day's work back to the production's usual relay (see
  [The on-set server](on-set-server.md)).

A **Re-host this project on launch** checkbox brings hosting back on its own the next time you
open the project; it stays greyed out until the project has been shared or hosted once. Hosting a
relay opens it up to the rest of your local network, on purpose — see the firewall note in
[The on-set server](on-set-server.md#the-firewall-note-in-plain-terms) for what that means in
practice.

Whoever actually runs the machine as a relay for a full shoot day — rather than just turning the
switch on for a quick session — is the audience for the more technical operator's guide,
`docs/on-set-server.md` in the project's repository; point them to it rather than improvising.

## Hosting is desktop only

Turning a device *into* a relay is a desktop feature: on a tablet or a phone the sharing screen
has no "Host on this machine" toggle, only the remote-relay form. Such a device can still pair
to a relay and join a shared project like any other device, but it cannot host one itself. Nor
can a project opened as a read-only preview host or re-pair.
