// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';

/// The colours [ocptPresenceColor] picks a peer's avatar from, one fixed palette shared by every
/// project: unlike a project's own per-project palette (`ocpt_coverage_palette.dart`), a replica's
/// identity has no project data to draw a colour index from, only its `deviceId` — so the palette
/// itself has to be the fixed, legible half of the pair.
///
/// Chosen to read clearly against the near-black toolbar the presence cluster always sits on
/// (`CLAUDE.md`'s "creative studio" surfaces are dark either way) while staying distinct from the
/// app's own `0xFF6C5CE7` accent, which is reserved for the self ring
/// (`OcptPresenceIndicator`'s own doc comment).
const List<Color> ocptPresenceColorPalette = [
  Color(0xFFE0A93E), // amber
  Color(0xFF4FB0C6), // teal
  Color(0xFFEF7B45), // orange
  Color(0xFF5E9F5A), // green
  Color(0xFFD25F8C), // rose
  Color(0xFF7B93D6), // periwinkle
];

/// A colour deterministically derived from [deviceId], picked from [ocptPresenceColorPalette].
///
/// The same id always yields the same colour — the same one on every replica that ever sees it, and
/// the same one across app restarts. That is why this hashes [deviceId]'s own code units (a fixed
/// FNV-1a fold) rather than reaching for `String.hashCode`, which Dart randomises per isolate run:
/// with the built-in hash a peer's colour would flip on every relaunch and differ from device to
/// device, when a presence colour's whole job is to stay put. There is no shared registry to look a
/// colour up in, only the id every presence frame already carries. Two different ids may of course
/// collide on the same colour once there are more than [ocptPresenceColorPalette]'s own six
/// participants at once, exactly as a project's own per-project palette can.
Color ocptPresenceColor(String deviceId) {
  // FNV-1a over the code units: a small, stable, seed-free hash — all that is needed to spread ids
  // across the palette deterministically, on every run and every device alike.
  var hash = 0x811c9dc5;
  for (final unit in deviceId.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0xFFFFFFFF;
  }
  final index = hash % ocptPresenceColorPalette.length;

  return ocptPresenceColorPalette[index];
}
