# The on-set server

<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: CC-BY-4.0
-->

A shoot often has no reliable internet at all, yet still benefits from everyone's devices syncing
with each other over the local set network. This page covers pointing your device at that local
relay for the day, and what running one involves for whoever brings the laptop.

## Why a set has its own relay

Rather than relying on an internet connection that a location may simply not have, a production can
run its own relay for the day on a laptop already on set — through the same [Host on this
machine](sharing-a-project.md#hosting-the-relay-yourself) panel described in sharing a project (a
desktop feature). Every device on set then syncs against that machine over the local network only,
with no internet required at all. At the end of the day, whoever runs that laptop pushes the day's
work back up to the production's usual relay with the panel's **Reconcile upstream…** action: paste
the usual relay's invite link, choose **Reconcile**, and the panel reports how many changes were
pushed and pulled. The operator's own runbook, linked below, covers the whole day.

![The Host on this machine panel](/img/screenshots/collab-host.png)

## Pointing your device at the set relay

Your project does not need to be re-joined to work with the set relay — it keeps its own identity
and history. What changes is only *where* it looks for its relay:

1. On the sync status indicator in your workspace's status bar (see
   [How collaboration works](how-collaboration-works.md#the-sync-status-indicator)), open the
   panel and choose **Switch relay…**. The screen is titled `Switch relay for "<project name>"`.
2. Type the set relay's **Relay address** and its **Enrolment secret**, then choose **Switch
   relay**. On a tablet or phone you can instead choose **Scan a relay QR code** and point the
   camera at the QR code the set relay is showing — on the hosting laptop's own screen (pick
   **Redirect a device that already has it** in its hosting panel), or handed to you by whoever
   is running it from a terminal; **Enter details manually** brings the form back. A computer has
   no scan, so it always uses the form.
3. Your device now syncs against the set relay instead. Nothing about your project's content
   changes; only the meeting point does. The screen then offers a **Ready for the next device**
   QR code, with **Copy the enrolment link**, so you can hand the same switch on to the next
   person; choose **Done** when finished.

The same QR re-points any project — it names a relay, not a specific project — so one code shown
once is enough for the whole crew to point their own devices at it, each keeping their own
project.

## The firewall note, in plain terms

Hosting a relay — whether from the app or from a technical operator's own tools — opens it up to
the rest of the local network it runs on, on purpose: that is how the rest of the crew's devices
reach it. For a set network or a small production's own machine, that is an accepted, deliberate
choice, not an oversight. It also means a set relay is only ever meant to be reached from *that*
local network — reaching it from somewhere else over the internet is out of scope, and a
production that genuinely needs that should use a permanent, properly secured relay instead of an
on-set one.

## If the laptop running it is lost

The set relay is a convenience, never the one place the day's work lives: every device on set
already holds its own full copy of the project, edits included. If the laptop or machine running
the relay is lost, dropped, or left behind, any other computer that was on set can simply start
hosting in its place and carry on — nothing about the day depends on one machine surviving until
evening.

## For whoever runs the relay

Turning a laptop into the set's relay for the whole day — starting it, sharing its QR, reconciling
the day's work back to the production's own relay in the evening — is covered step by step in the
project's operator runbook, `docs/on-set-server.md` in the application's repository. It assumes no
coding knowledge, only comfort running the relay for the day; hand it to whoever is asked to bring
the laptop.
