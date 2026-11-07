// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// The payload a row's own cross-slot drag carries: which block, and the id of the slot it
/// currently belongs to. The second half is what lets a slot card's own `DragTarget` refuse a block
/// dropped back onto its own timetable — that gesture is what in-slot reordering already does, and
/// letting a self-drop through here would fight it rather than merely duplicate it.
///
/// Shared by the row that starts the drag and the timetable that receives it, which live in two
/// files.
class OcptScheduleDraggedBlock {
  /// The id of the block being dragged.
  final String blockId;

  /// The id of the slot the block belongs to at the moment the drag starts.
  final String sourceSlotId;

  /// Build a drag payload.
  const OcptScheduleDraggedBlock({required this.blockId, required this.sourceSlotId});
}
