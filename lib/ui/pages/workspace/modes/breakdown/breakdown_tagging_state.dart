// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_pending_tag.dart';

/// The state of `OcptBreakdownTaggingBloc`: the range interaction of the script view, not yet
/// written to the project database.
///
/// Both pending values are ephemeral and write nothing on their own: the interaction they drive only
/// touches the database once the popover it opens answers with a link or an element creation.
class OcptBreakdownTaggingState extends BlocStateForMixin<OcptBreakdownTaggingState> {
  /// The first word clicked of a range not yet closed, or null while none is open — the script
  /// view's own cue to mark that word as pending. Cleared the moment the range closes
  /// (successfully or by falling into another scene, which simply replaces it) or is cancelled
  /// outright.
  final OcptBreakdownPendingTagAnchor? pendingTagAnchor;

  /// A range just closed by a second click, awaiting the popover's own answer, or null while none
  /// is — the script view's cue to anchor `OcptBreakdownTagPopover` under the word that closed it.
  final OcptBreakdownPendingTagRange? pendingTagRange;

  /// Whether the last tag write — the popover's own link or element creation, or a suggestion
  /// accepted from the target inspector's own "Suggested occurrences" section — was refused: the
  /// overlap, or a preview database that slipped through. A transient notice tells the user rather
  /// than the writer silently doing nothing. Reset the moment it has been shown once.
  final bool hasTagWriteError;

  /// Class constructor
  const OcptBreakdownTaggingState({
    required this.pendingTagAnchor,
    required this.pendingTagRange,
    required this.hasTagWriteError,
  });

  /// Builds the state of a bloc that has no range open.
  const OcptBreakdownTaggingState.init()
    : pendingTagAnchor = null,
      pendingTagRange = null,
      hasTagWriteError = false;

  /// Copies this state, replacing what is given. [pendingTagAnchor] and [pendingTagRange] go back to
  /// null only through their force flags, since a null argument means "keep".
  @override
  OcptBreakdownTaggingState copyWith({
    OcptBreakdownPendingTagAnchor? pendingTagAnchor,
    bool forcePendingTagAnchorValue = false,
    OcptBreakdownPendingTagRange? pendingTagRange,
    bool forcePendingTagRangeValue = false,
    bool? hasTagWriteError,
  }) => OcptBreakdownTaggingState(
    pendingTagAnchor:
        pendingTagAnchor ?? (forcePendingTagAnchorValue ? null : this.pendingTagAnchor),
    pendingTagRange: pendingTagRange ?? (forcePendingTagRangeValue ? null : this.pendingTagRange),
    hasTagWriteError: hasTagWriteError ?? this.hasTagWriteError,
  );

  /// Object properties
  @override
  List<Object?> get props => [...super.props, pendingTagAnchor, pendingTagRange, hasTagWriteError];
}
