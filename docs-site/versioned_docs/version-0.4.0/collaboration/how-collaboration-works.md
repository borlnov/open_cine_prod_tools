# How collaboration works

<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: CC-BY-4.0
-->

A project can be **shared**: the director on a laptop, the assistant director on a tablet on set,
a producer at home, all working on the same project, each on their own device. This page explains
what that means before you open the sharing screens themselves.

## Every device keeps the whole project

There is no server holding "the real" project that your device only borrows from. Each device
that joins a shared project keeps a **complete copy** of it — the screenplay, the breakdown, the
resources, the schedule, the budget, all of it — and stays fully usable with that copy alone, with
no connection at all.

This is what makes the application work on a set with no signal: you keep writing, tagging shots,
moving people on the schedule, and every change is saved locally exactly as it would be in a
project you never shared.

## Edits queue and merge when you reconnect

While you are offline, your edits simply queue on your device. As soon as a connection to the
shared project's relay comes back — wifi, a mobile hotspot, a set network — your device sends its
queued edits and receives whatever the others made meanwhile. Both sides end up with the same
project.

Two people can safely edit **different fields of the same record** at the same time — the director
adjusting a shot's framing while the assistant director sets its shooting day, say — and both
changes survive; neither one overwrites the other. Two edits to the very *same* field are
resolved automatically, without asking you to choose, so sharing never blocks your work waiting
for a decision.

The one exception is the screenplay text itself: two people typing in the same passage at the same
time are merged line by line, the way a version-control tool would. On the rare occasion the two
edits genuinely clash on the same lines, the application does not guess: it leaves your own text
as you wrote it rather than silently overwriting it, and there is no screen yet to settle the
clash — so it is worth agreeing between you who edits a given passage.

## The sync status indicator

Once a project is shared, a small indicator sits in the workspace's status bar, visible from
every mode. It tells you, at a glance, where your device stands with the rest of the project:

- **In sync** — everything you and everyone else has done is reconciled; there is nothing waiting.
- **Syncing…** — edits are being sent or received right now.
- **Offline · 3 pending changes** — the count is how many of your own edits are still waiting to
  go out. This is normal and expected whenever the device has no connection to the relay;
  nothing is lost, it simply has not left yet. When the count is not known, it reads "Offline ·
  pending changes".
- **Sync error** — something the relay itself refused, worth a look rather than a simple
  connection drop; the panel below spells it out as "Relay error: …".

Click the indicator to open a panel with four actions: **Sync now**; **Show the invite QR code**
and **Re-pair…**, which both open the project's [sharing screen](sharing-a-project.md); and
**Switch relay…**, which points the project at a different relay (see
[The on-set server](on-set-server.md)). The indicator, and its panel, only appear once a project
is shared — an unshared project shows neither. On a project opened as a read-only preview the
panel is there, but its actions are withheld.

## Presence: who else has it open

A cluster of small round avatars in the top toolbar, just before **Export**, shows every device
that currently has the project open, yours included — never people who merely have a copy of it
somewhere, only the ones open right now. Each avatar carries the initial of the device's system
(for instance L for Linux, W for Windows); with more than three, the rest fold into a "+2" disc.
Hover an avatar to see its name and mode, or click the cluster to open the "On this project"
list, with the number online and, for each device, its name — the system and the last three
characters of its identifier, such as "Linux · a3f" — and **which mode** it is working in
(Screenplay, Schedule, Budget…), which is often enough on its own to know whether it is safe to,
say, re-order the schedule.

There are no accounts and no names to type in: each device is told apart by its own colour,
consistent for that device, and by that short identifier. Yourself is always listed first,
ringed in the accent colour and tagged "You". Presence is entirely live — it says nothing about
who *has* edited, only who is *currently* on the project — and disappears with the sync indicator
on an unshared project.

## Where to go next

- [Sharing a project](sharing-a-project.md) to invite the rest of the crew.
- [Joining a project](joining-a-project.md) for the device on the receiving end.
- [The on-set server](on-set-server.md) for a shoot with its own local relay.
- [Working on a tablet or phone](tablet-and-phone.md) for the layouts on a smaller screen.
