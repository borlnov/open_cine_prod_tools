<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: CC-BY-4.0
-->

# Troubleshooting

## Windows refuses to launch the application (SmartScreen)

Because the application is unsigned, SmartScreen shows "Windows protected your PC" on first
launch. Click **More info**, then **Run anyway**. The warning does not appear again afterwards.

## macOS refuses to launch the application (Gatekeeper)

Right-click the application in `Applications`, choose **Open**, then **Open** again. See the
[Installation page](../getting-started/installation.md) for the command-line alternative.
Reminder: the macOS build has never been tested.

## "This file was created by a newer version"

A project saved by a **newer** version of the application cannot be opened by an older one: the
file is **refused, not damaged**, and left untouched. Update the application to the latest
version, then reopen the file.

## "This file must be migrated"

Conversely, a project in an **older format** asks to be migrated before it opens. The application
has you confirm and states where it keeps a **backup copy** (a `.backup-v<n>.ocpt` file placed
beside the original) before migrating. No backup, no migration.

## A photo or a document does not appear

Photos and documents are **referenced by their path, not embedded** in the project. If the file
was moved or deleted, the record flags it: this is a normal situation. Put the file back in
place, or reference it again from the record.

## Spell check underlines nothing

Two settings must both be on: the **screenplay language** (project settings — not **None**) and
**Show spell check** (the **⋮** menu). See [Spell check and the
dictionary](../concepts/spell-check-and-dictionary.md).

## Sending a project reports missing files

Before writing an `.ocptz` package, the application checks the referenced files and warns you if
some are missing. You can go ahead anyway: the package then carries the references, without the
absent files.
