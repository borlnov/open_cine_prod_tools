// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';

/// One breakdown prop of the focused sequence, for the palette's own `Sequence` group chips — a
/// read-only projection of the *dépouillement*'s own
/// `scene_elements` link joined with the `elements` catalogue, loaded by the bloc (no `Tr` in
/// services): [quantity] is already resolved to the link's own override or the element's own
/// catalogue quantity, whichever is set, and is empty while neither carries one.
class OcptFloorPlanPropChip extends Equatable {
  /// The element's own catalogue id — what a placed prop symbol's label is filled from, never
  /// stored as a link of its own (`OcptFloorPlanSymbolsTable`'s own doc comment: a label is free
  /// text).
  final String elementId;

  /// The element's own display name — the chip's own label, and what a placed symbol's own label
  /// is set to.
  final String name;

  /// The effective quantity (the scene's own override, or the element's own catalogue quantity), a
  /// decimal stored as text, or empty while neither is set — the chip shows `<name> ×<quantity>`
  /// only while this isn't empty.
  final String quantity;

  /// Class constructor
  const OcptFloorPlanPropChip({
    required this.elementId,
    required this.name,
    required this.quantity,
  });

  /// List the fields that decide equality.
  @override
  List<Object?> get props => [elementId, name, quantity];
}
