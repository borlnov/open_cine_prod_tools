<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: CC-BY-4.0
-->

# Open Cine Prod Tools

Welcome to the guide for **Open Cine Prod Tools**, the open-source suite of film-production
tools. This guide is for the people who *make* films — directing, producing, on-set
logistics, staging — not for the application's developers; the technical documentation lives
elsewhere, in the project's repository.

## What the application does

Open Cine Prod Tools brings a production's tools together in a single window, from the first
draft of the screenplay to the sharing of revenue. Each tool is a **mode** you pick at the
bottom of the window:

- **Screenplay** — write and format the screenplay, in the Fountain format.
- **Breakdown** — read the screenplay closely and tag everything the shoot must provide (roles,
  sets, props, costumes…).
- **Shot list** — break each scene down shot by shot and record what each shot covers.
- **Resources** — the address book, the cast, the locations and the elements catalogue.
- **Schedule** — decide *when* the film is shot: days, slots, call times.
- **Budget** — cost the film, follow the cash, the financing plan and the revenue sharing.

## A few principles

- **Everything is local.** A project fits in a single `.ocpt` file on your disk; nothing is
  sent to a server.
- **One project, several episodes.** A series, a mini-series or a film shot in parts all live
  in one file: one screenplay per episode, but one crew, one address book, one schedule.
- **The screenplay is the source of truth.** The Fountain text is the heart of the project; the
  other modes hook onto it.
- **Everything is exportable** to formats anyone can read: PDF, `.fountain`, spreadsheet
  workbooks.

## Where to start

If the application is new to you, start with [installation](getting-started/installation.md),
then follow the [first steps](getting-started/first-steps.md) to create your first project.

:::note About this guide

This guide's content is published under the **CC-BY-4.0** licence: you may reuse, translate and
adapt it, provided you credit the source. It comes in English and French; the language switcher
is at the top right.

:::
