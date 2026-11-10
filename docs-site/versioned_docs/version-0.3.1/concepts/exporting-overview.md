# Exporting, in short

<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: CC-BY-4.0
-->

## One gesture, everywhere

Every export happens from **one place: the `Export` control in the toolbar**. It is present in
every mode that can produce a document, so exporting is always the same action, in the same
spot.

A click on **Export** opens the **export panel**: a grid of cards, **one per document**. Each
card shows the document's name, a short description and its format (`PDF`, `XLSX` or
`.fountain`).

- A document that cannot be produced right now stays **shown but greyed**, and its description is
  replaced by the **reason** (for example: no shooting day planned yet). The panel therefore
  always tells you everything the mode can produce.
- Choosing a card opens the document's **options dialog** (where there is one), then a native
  **"Save As" dialog**. **Nothing is ever written silently** to a default location: you always
  choose where each file goes.

## An export's scope

When an export depends on an episode, it produces the **selected episode**. The suggested file
name then includes an episode tag (for example `ep. 2`), **only** when the project holds several
episodes — so that exporting two episodes into the same folder overwrites nothing.

## Sending the whole project

Below the documents grid, a separate card exports **the project itself** as a single `.ocptz`
file you can pass on. The same action is available without opening the project, from the **⋮**
menu of a card on the home screen — which is, incidentally, the only way to send a project whose
file is in an older format without migrating it.

## See also

The full list of documents, mode by mode, is gathered in
[Exporting your work](../exports/exporting-your-work.md).
