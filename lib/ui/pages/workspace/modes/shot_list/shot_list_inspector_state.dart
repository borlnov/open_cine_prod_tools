// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_pending_edit_key.dart';

/// The state of `OcptShotListInspectorBloc`: what the shot inspector and the scenario coverage
/// dialog hold of their own.
///
/// The shot, its cast and its coverage ranges themselves are the mode's data
/// (`OcptShotListState.snapshot`, `OcptShotListState.roles`): this is the text typed and still
/// waiting for its write, the anchor of the coverage range being drawn, and the write error.
class OcptShotListInspectorState extends BlocStateForMixin<OcptShotListInspectorState> {
  /// Every shot field edit currently sitting in the inspector's autosave debounce, keyed by
  /// [OcptShotListPendingEditKey], holding the raw text last typed for it.
  ///
  /// What a field shows takes this map's entry over the shot's own stored value whenever one is
  /// present, so typing is never overwritten by a reload triggered by an unrelated write (another
  /// field's own flush, a status change on a different shot). An entry is removed the moment its
  /// write lands, whether through the debounce elapsing or an explicit flush, and when the shot it
  /// targets is gone from the mode's shot list.
  final Map<OcptShotListPendingEditKey, String> pendingFieldEdits;

  /// The first word clicked of a scenario coverage range currently being drawn in the coverage
  /// dialog, or null while none is being drawn (no click yet, or the range was just closed or
  /// removed).
  ///
  /// Its two fields are the anchor word's own scene-relative `OcptScriptWord` offsets, which
  /// identify it on their own — a range may span several blocks, so the block a click lands in
  /// never takes part in the decision. Cleared whenever the mode's selected shot or sequence
  /// changes, and after every coverage write (see `OcptShotListInspectorBloc`'s own doc comment on
  /// its coverage word-click handler for the full three-state interaction this backs).
  final ({int wordStartOffset, int wordEndOffset})? pendingCoverageAnchor;

  /// Whether the last write the inspector made failed; shown as a transient SnackBar then
  /// dismissed.
  final bool hasWriteError;

  /// Class constructor
  const OcptShotListInspectorState({
    required this.pendingFieldEdits,
    required this.pendingCoverageAnchor,
    required this.hasWriteError,
  });

  /// Builds the state of an inspector nothing has been typed in yet.
  const OcptShotListInspectorState.init()
    : pendingFieldEdits = const {},
      pendingCoverageAnchor = null,
      hasWriteError = false;

  /// {@macro act_flutter_utility.BlocStateForMixin.copyWith}
  ///
  /// [pendingCoverageAnchor] legitimately goes back to null while the inspector is alive, so it has
  /// its own force flag.
  @override
  OcptShotListInspectorState copyWith({
    Map<OcptShotListPendingEditKey, String>? pendingFieldEdits,
    ({int wordStartOffset, int wordEndOffset})? pendingCoverageAnchor,
    bool forcePendingCoverageAnchorValue = false,
    bool? hasWriteError,
  }) => OcptShotListInspectorState(
    pendingFieldEdits: pendingFieldEdits ?? this.pendingFieldEdits,
    pendingCoverageAnchor:
        pendingCoverageAnchor ??
        (forcePendingCoverageAnchorValue ? null : this.pendingCoverageAnchor),
    hasWriteError: hasWriteError ?? this.hasWriteError,
  );

  /// Object properties
  @override
  List<Object?> get props => [
    ...super.props,
    pendingFieldEdits,
    pendingCoverageAnchor,
    hasWriteError,
  ];
}
