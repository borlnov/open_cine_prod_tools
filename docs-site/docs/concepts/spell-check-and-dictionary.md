# Spell check and the project dictionary

<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: CC-BY-4.0
-->

## How spell checking works

Spell checking runs **as you type**, in both screenplay editing modes. It uses **French and
British English** dictionaries bundled with the application: no internet connection and no system
service are required.

It checks **prose** and leaves the **screenplay form alone**: scene headings, character names and
transitions are never underlined, and neither are all-caps words or words containing digits.

For a word to be checked, **two switches** must both be on:

- the **screenplay language**, per project (in the project settings) — the **None** option turns
  checking off for that project;
- **Show spell check**, per machine (in the **⋮** menu).

## Correcting a word

In the styled editor, **right-click** an underlined word: up to five suggestions appear, along
with **Ignore this word** (for the session) and **Add to the project's dictionary**.

## The project dictionary

The words you teach the application travel **inside the `.ocpt` file**: they follow the project
to a colleague's machine.

- A word is stored **as you typed it** and matched case-insensitively.
- To manage it, open **project settings → Dictionary section** (it shows the word count) and
  click **Edit…**. The dialog lets you **read, filter, add and remove** words. Removing a word is
  confirmed **inside its own row** (`Remove? / Yes / No`), so you can prune a long list without a
  dialog popping up on every word.
