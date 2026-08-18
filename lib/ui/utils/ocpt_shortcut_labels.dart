// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/foundation.dart';

/// Formats the label of a shortcut made of the platform's primary modifier and [key], as a menu
/// entry displays it beside the action it triggers: `⌘F` on macOS, `Ctrl+F` everywhere else.
///
/// Every shortcut this app binds is registered on both `control` and `meta` (see the `Shortcuts`
/// map in `editor_page.dart`), so both actually work on both platforms — this only picks the one a
/// user of that platform expects to read.
///
/// Not localized, and deliberately so: `Ctrl` and `⌘` name physical keys, which the keyboard
/// itself labels the same way whatever the UI language is.
String ocptPrimaryShortcutLabel(String key) =>
    defaultTargetPlatform == TargetPlatform.macOS ? "⌘$key" : "Ctrl+$key";
