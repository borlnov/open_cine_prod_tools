<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: CC-BY-4.0
-->

# Fountain, the source of truth

## What Fountain is

**Fountain** is a plain-text screenplay format: you write the screenplay in ordinary text, and a
few conventions (a line in capitals becomes a character name, an `INT.`/`EXT.` line becomes a
scene heading…) are enough to format it. It is an open format, readable as-is, that locks you
into no software.

You do not need to know these conventions to write: the Screenplay mode offers an editor that
formats everything for you. But it helps to know that, **under the hood, your screenplay is
Fountain**.

## Why it matters

In Open Cine Prod Tools, the screenplay text is the **heart of the project**. The other modes do
not copy that text: they **hook onto** it.

- The **shot list** links each shot to the exact passages of the screenplay it covers.
- The **breakdown** tags passages of the screenplay to fill the resources catalogues.
- The **schedule** places shots, which point back to scenes.

The result: when the screenplay changes, the application knows what is affected and warns you
(for example, a shot whose covered text has moved is flagged "needs checking"). It is also why
everything starts from good foundations: a clean screenplay makes the rest of the work reliable.

## A word on vocabulary

In the English interface, a **scene** is a screenplay scene, in the usual sense. In the French
interface the same thing is called *une séquence*, because the word *scène* names something else
in that trade — a naming rule that touches French alone. For the concrete formatting, see the
[Fountain cheat sheet](../reference/fountain-cheatsheet.md).
