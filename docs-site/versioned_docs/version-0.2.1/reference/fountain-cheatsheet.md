# Fountain cheat sheet

<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: CC-BY-4.0
-->

**Fountain** formats a screenplay from plain text. In styled mode the editor applies these rules
for you; in raw mode you type them directly. Here are the most common elements. The editor also
offers a **syntax guide** in the right-hand panel.

## Scene heading

A line that starts with `INT.`, `EXT.`, `INT./EXT.` or `EST.`:

```text
INT. CAFÉ - DAY

EXT. COBBLED STREET - NIGHT
```

An explicit scene number goes between hashes at the end of the line:

```text
INT. CAFÉ - DAY #12#
```

## Action

Just a paragraph. It describes what we see:

```text
Marie pushes the door. The room is empty; a cup still steams on the counter.
```

## Character, dialogue and parenthetical

A name in **capitals** introduces a line; the parenthetical goes between the two:

```text
MARIE
(quietly)
Is anyone there?
```

An extension goes in parentheses after the name, for example `MARIE (V.O.)` for a voice-over.

## Transition

A line in capitals ending in `TO:` (or prefixed with `>`):

```text
CUT TO:
```

## Centered text

Wrapped in `>` and `<`:

```text
> THE END <
```

## Note (kept out of print)

A comment visible in the source but absent from the printed screenplay, between double brackets:

```text
[[check with the production]]
```

## Emphasis

As in Markdown: `*italic*`, `**bold**`, `_underline_`.

## Title page

At the top of the file, as `Key: value` fields. In styled mode it is edited as a first sheet
instead (see [Screenplay](../modes/screenplay.md)).

```text
Title: My Film
Author: An Author
```
