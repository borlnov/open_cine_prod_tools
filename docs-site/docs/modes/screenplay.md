# Screenplay

<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: CC-BY-4.0
-->

The Screenplay mode is where you write the screenplay of the selected episode. The application
works in **Fountain** (a plain-text screenplay format), but you never have to think in "code":
you write on a formatted page, or you edit the raw Fountain text with a preview beside it.

![The screenplay mode, showing the styled page](/img/screenshots/screenplay.png)

## The two editing modes

- **Styled editor** — a surface that shows the screenplay the way it will print. Each paragraph
  is a typed block (scene heading, action, character, dialogue…), formatted automatically. With
  page simulation, your text lays onto real paper-sized sheets, printed page numbers included.
- **Raw Fountain text** — a text field where you type the Fountain source directly, with a
  **paper-simulated preview side by side** that shows the formatted result as you go.

To switch between the two: **Ctrl+Shift+M** (or the **⋮** menu). Undo history belongs to the
surface you are on: switching starts a fresh history, so finish an edit before you toggle.

## Zooming the page

You can zoom the page, in the styled editor and in the paper preview of the raw mode (the raw
Fountain text keeps its size). The zoom is the same in both, and it is remembered for you,
whatever the project.

- Use the **`−`**, the percentage and the **`+`** at the right of the status bar. Click the
  percentage for the list of sizes, from 50 % to 200 %, and **Fit to width**: the page then fills
  the width of the area and follows the window when you resize it.
- Hold **Ctrl** (**Cmd** on a Mac) and turn the mouse wheel: one step per notch, around the point
  under the pointer, however far a notch turns on your system. A smooth wheel or a trackpad, which
  send many small movements, steps each time they add up to a notch. A plain wheel still scrolls.
- **Ctrl** and **+** (or **=**) zoom in, **Ctrl** and **−** zoom out, **Ctrl** and **0** go back
  to 100 %.

The pagination does not change with the zoom: the same lines fall on the same pages. When the page
is wider than the area, scroll sideways. On a phone or a narrow window there is no zoom.

## The elements the editor understands

The editor recognises and formats the standard screenplay elements: **scene headings**
(`INT.`/`EXT.`, with a number written `#N#` if needed), **action**, **character** (with
extensions such as `(V.O.)`), **dialogue** and **parentheticals**, **transitions**, **centered
text**, **notes** (kept out of print), plus **sections**, **synopses** and **lyrics**.

A few useful gestures in the styled editor:

- **Tab / Shift+Tab** cycles the current block's type through the six common types and locks it.
- **Enter** starts the block type that normally follows; **Shift+Enter** keeps the same type.
- A block-type menu and the **B / I / U** toggles live in the toolbar; a right-click offers Cut,
  Copy, Paste, Select all and a block-type submenu.
- Copy-paste inside the app preserves block types; text pasted from outside is analysed and
  split into the right elements.

## Dual dialogue

Two characters who speak at the same time are written as a **dual dialogue**: the second
character's name ends with `^` (for example `KIM ^`), and the two speeches are printed **side by
side**, one column each, on the page of the preview, the PDF and the sheets of the other modes.
A pair is never cut by a page break: if it does not fit, it moves whole to the next page. A `^`
with no speech right before it to pair with prints as an ordinary dialogue, and a note or any
other line between the two speeches breaks the pair.

In the styled editor you do not type the `^`: put the caret in the second speech and choose
**Dual dialogue** in the right-click menu, in the toolbar's format controls (or their **⋮**
menu), or press **Ctrl+Alt+D** (**Cmd+Alt+D** on macOS). The entry is checked while the speech is
part of a pair, and choosing it again undoes the pairing. It only appears when another speech
sits next to the one you are in. The styled editor keeps the two speeches **one under the other**,
and a **bracket in the left margin** shows they are a pair; a `^` that pairs with nothing appears
dimmed after the character's name. Typing a `^` at the end of a name works too, and the raw Fountain
text shows it as written.

## The scene panel (on the left)

A resizable panel lists your scenes so you can navigate and jump between them.

About **scene numbers**: an explicit `#N#` is always respected. In styled mode, the editor can
also **display a computed number** for a heading that has none (the *Show scene numbers* toggle
in the **⋮** menu, on by default). Computed numbers are display only: they are never written into
your file, and an explicit `#N#` always wins. The preview and the PDF print only explicit
numbers.

## The title page

In styled mode, the title page is an **editable first sheet**. It shows its six fields —
**Title, Credit, Author, Draft date, Contact, Source** — with hints for empty ones, laid out
like a real title page. You edit in place, or via the **Edit…** button in the metadata panel. If
every field is empty, no title page is written; when present, it occupies the whole of page 1 and
does not count in the numbering.

## Importing a screenplay from another format

The application opens a screenplay received from a production — a **Final Draft `.fdx`** or a
**Celtx `.celtx`** — and converts it to Fountain, which becomes your source. Headings, action,
characters, parentheticals, dialogue, transitions, dual dialogue, act breaks, emphasis and the
title page are brought across.

:::caution The conversion is one-way and not exhaustive

An `.fdx` leaves behind its margin notes, its revision marks and its locked pages. A `.celtx`
brings in only its **first** script document. Importing **replaces** the current screenplay: the
application has you **confirm** before it overwrites your text.

:::

## Statistics and tools

- The **status bar** shows live counters over the printable screenplay: number of pages, scenes,
  speaking characters, words and signs.
- The tabbed right-hand panel holds a preview, a scene inspector (heading, speaking characters,
  estimated duration), the title page, the versions, and a **Fountain syntax guide** available
  in both modes.
- **Spell checking** runs as you type: see [Spell check and the
  dictionary](../concepts/spell-check-and-dictionary.md).

## What this mode exports

- a **screenplay PDF** (paginated, with the title page and your explicit scene numbers);
- a **`.fountain`** file (text).

Both suggest a file name that includes the episode, so a screenplay from another episode saved
into the same folder is not overwritten.
