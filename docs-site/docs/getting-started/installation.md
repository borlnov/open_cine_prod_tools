<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: CC-BY-4.0
-->

# Installation

Open Cine Prod Tools is a desktop application. You install it by downloading the file for your
system, then opening it. This page covers each platform.

## Where to download

Every installer is on the project's
[GitHub Releases](https://github.com/borlnov/open_cine_prod_tools/releases) page. Each published
release offers:

- the `.deb` package for **Linux**;
- the installer for **Windows**;
- the `.dmg` disk image for **macOS**.

Pick the latest release, then the file for your system.

:::info Unsigned applications

The binaries are not digitally signed. This is not a sign of danger, but your system will show a
warning on first launch. The sections below explain how to get past it on each platform.

:::

## Supported platforms

| Platform | Status |
| --- | --- |
| Linux | Active development |
| Windows | Active development |
| macOS | Build available, unsigned and **never tested** |
| Android | Scaffolded (not usable yet) |
| iOS | Scaffolded (not usable yet) |

Linux and Windows are the two platforms actually developed and used. Android and iOS are only
scaffolded for now.

## Linux

Download the `.deb` package, then install it from a terminal:

```bash
sudo apt install ./open-cine-prod-tools_<version>_amd64.deb
```

Replace `<version>` with the number of the file you downloaded. The application then appears in
your applications menu.

## Windows

Download the installer and run it. Because the application is unsigned, **SmartScreen** may show
a blue "Windows protected your PC" screen on first launch:

1. click **More info**;
2. click **Run anyway**.

The warning does not appear again afterwards.

## macOS

:::warning Build never tested on a Mac

The `.dmg` is produced automatically, but **nobody has run the application on a Mac yet**: the
project has none. Treat this build as a trial, and feel free to report what works and what does
not.

:::

Open the downloaded `.dmg`, then drag **Open Cine Prod Tools** onto the `Applications` shortcut
placed beside it.

Because the application is unsigned, **Gatekeeper** refuses to launch it directly. Two ways past
it:

- right-click the application in `Applications`, choose **Open**, then **Open** again in the
  dialog that follows;
- or clear the quarantine flag once, from a terminal:

```bash
xattr -dr com.apple.quarantine "/Applications/Open Cine Prod Tools.app"
```

## Next

Once the application is installed, move on to the [first steps](first-steps.md) to create your
first project.
