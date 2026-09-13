# Sharing a project

<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: CC-BY-4.0
-->

Sharing turns a project that only lives on your device into one the rest of the crew can join.
Read [How collaboration works](how-collaboration-works.md) first if you have not — it explains
what "shared" actually means before you turn it on.

## Opening the sharing screen

From a project's card on the home screen, open its **⋮** menu and choose **Partager**. You can
also open it from inside an already-open project. Sharing needs a place for every device to meet:
a **relay** — either one already running somewhere (a self-hosted server, or one a colleague set
up), or your own machine acting as one, covered below.

## Pairing to a relay

If you already know a relay's address — the one your production runs, or one you host yourself —
choose the remote-relay option and enter:

- the relay's **address**;
- the **enrolment secret** that relay's operator gave you.

Confirming this **pairs** the project to that relay: it generates a private token for this
project, sends your project's current content to the relay so the next person who joins can
download it, and starts syncing. From this point on, the project is shared.

## The invite

Once paired, the screen shows the project's **invite**: a QR code and its equivalent as a
copyable link. Anyone who scans the QR or opens the link can join the project — see
[Joining a project](joining-a-project.md) for what that looks like on their side.

Share the QR by pointing a colleague's camera at your screen, or send the copied link however you
would send any other link (chat, email). The invite carries no password of its own to read out
loud; whoever holds the QR or the link can join, so treat it the way you would a shared document
link.

A **stop sharing** action is also here, for when a project should no longer accept new devices or
sync further; because this cannot be undone from the screen, it is confirmed before it takes
effect.

## Hosting the relay yourself

If no relay is available, or the shoot has no internet at all, the same screen offers a
**"Héberger sur ce poste"** ("host on this machine") panel: a switch that turns your own device
into the relay everyone else pairs to, with nothing separate to install or run. This is the right
choice for a laptop that is already open on the project — the video-village machine on a shoot, or
a producer's own computer acting as the project's long-term meeting point between shoots.

This panel also shows who is currently connected to your hosted relay, and a **"réhéberger au
démarrage"** option so hosting comes back on its own the next time you open the project. Hosting
a relay opens it up to the rest of your local network, on purpose — see the firewall note in
[The on-set server](on-set-server.md#the-firewall-note-in-plain-terms) for what that means in
practice.

Whoever actually runs the machine as a relay for a full shoot day — rather than just turning the
switch on for a quick pairing — is the audience for the more technical operator's guide,
`docs/on-set-server.md` in the project's repository; point them to it rather than improvising.

## Hosting is desktop only

Turning a device *into* a relay is a desktop feature: a tablet or a phone can pair to a relay and
join a shared project like any other device, but it cannot host one itself.
