// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/ocpt_storyboard_panel.dart';

/// The whole storyboard of a screenplay, as `OcptStoryboardService.loadStoryboard` builds it: every
/// live shot's panels, keyed by shot id — the shape the board mode reads against
/// `OcptShotListSnapshot`'s own shots, mirroring how `OcptShotListSnapshot.shotsById` is a flat
/// lookup built once rather than something every reader re-derives.
///
/// A shot with no panel simply has no entry (or an empty list — [panelsOfShot] treats the two the
/// same), rather than every shot of the screenplay being represented: the board shows a dashed
/// placeholder for that case on its own, with nothing to read from this snapshot.
class OcptStoryboardSnapshot extends Equatable {
  /// The screenplay this storyboard belongs to.
  final String screenplayId;

  /// Every live panel, keyed by [OcptStoryboardPanel.shotId], each shot's list already in
  /// [OcptStoryboardPanel.sortKey] order.
  final Map<String, List<OcptStoryboardPanel>> panelsByShotId;

  /// Class constructor
  const OcptStoryboardSnapshot({required this.screenplayId, required this.panelsByShotId});

  /// [shotId]'s panels, in order, or an empty list if it has none.
  List<OcptStoryboardPanel> panelsOfShot(String shotId) =>
      panelsByShotId[shotId] ?? const <OcptStoryboardPanel>[];

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptStoryboardSnapshot(screenplayId: $screenplayId, shotsWithPanels: "
      "${panelsByShotId.length})";

  /// Object properties
  @override
  List<Object?> get props => [screenplayId, panelsByShotId];
}
