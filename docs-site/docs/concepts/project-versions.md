<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: CC-BY-4.0
-->

# Project versions

## What they are

A **project version** is a named, permanent, read-only snapshot of the **whole project** — your
own checkpoint. It is the equivalent of a dated, labelled "save as": you set a milestone before
an important decision, and you can always come back to it.

Versions are managed from the **Versions** tab in the side panels, present in every mode since it
is about the project, not the mode.

## The Versions panel

The panel reads top to bottom, from the present towards the sealed history:

- at the top, the **working-copy card**: live counters, an indication of whether the current
  state still matches its base version, and a **Create a version** button;
- below it, one **card per saved version**.

## The gestures

All these actions are confirmed **inside the card** they belong to, one at a time — with no
separate dialog, because a list of cards needs to say *which* one.

- **Create**: click **Create a version** on the working-copy card, then name it.
- **Preview**: click a version card to enter its read-only preview; click it again to leave (see
  [The read-only preview](read-only-preview.md)).
- **Restore**: from the card's menu, choose **Restore this version**. This is an **edit, not a
  wipe**: the state being replaced is itself saved as a new version (named "Before restoring
  …"), so going back is never one-way.
- **Rename**: the card's **Rename** action.
- **Delete**: the card's **Delete** action permanently removes that snapshot. The version you are
  currently previewing can be restored, but not deleted.

:::tip

The versions you create are distinct from the automatic screenplay-only snapshots the
application keeps behind the scenes. Project versions are your deliberate milestones, on the
whole project.

:::
