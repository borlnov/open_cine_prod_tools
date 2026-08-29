<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: CC-BY-4.0
-->

# Frequently asked questions

## Does my data go to a server?

No. Everything is **local**: a project fits in a single `.ocpt` file on your disk. Nothing is
sent online. Collaboration and sync are planned for later, but are not part of the current
version.

## Does the application work offline?

Yes, entirely — including spell checking, whose dictionaries ship with the application.

## How do I back up a project?

Copy its `.ocpt` file, simply. To send a complete project to someone, export it as an **`.ocptz`**
package (see [Exporting your work](../exports/exporting-your-work.md)). Consider also [project
versions](../concepts/project-versions.md) to set milestones inside a project.

## Can I manage a series?

Yes. A project holds one or more **episodes** in one file — one screenplay per episode, but one
crew and one schedule. See [Projects and episodes](../concepts/projects-and-episodes.md).

## Which formats can I import and export?

- **Import** a screenplay: `.fountain`, `.fdx` (Final Draft) and `.celtx` (Celtx). The last two
  are converted to Fountain on import, with no way back.
- **Export**: PDF, XLSX and `.fountain`, depending on the mode. The full list is in [Exporting
  your work](../exports/exporting-your-work.md).

## Which systems does it run on?

Linux and Windows are in active development. A macOS build exists but **has never been tested**.
Android and iOS are only scaffolded for now. See
[Installation](../getting-started/installation.md).

## In which languages does the application come?

The interface is in **English** and **French**. This guide is too; the language switcher is at
the top right.

## Under which licence?

The application is published under the **Apache-2.0** free licence. This guide's content is
published under **CC-BY-4.0**.
