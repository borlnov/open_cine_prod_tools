// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';

/// A genuine screenplay-text conflict `OcptScreenplayMergeService` could not resolve on its own:
/// this replica's own text and an incoming edit both touched the very same lines of the
/// screenplay's Fountain text, differently.
///
/// This is `docs/plans/collaboration-and-sync.md`'s "screenplay conflict view" (§3.5) — the only
/// conflict a user is ever asked to resolve — as far as M3 goes: **recorded, never resolved**. M5 is
/// what builds the view that lets a user pick a side or hand-merge the two; this class is simply
/// what a caller needs in hand to build that view later, and what M3's own tests assert against in
/// its place. Nothing about this class blocks or loses data on its own: raising one leaves the
/// screenplay's stored text exactly as it stood before the incoming edit arrived — [localText],
/// never [incomingText], is what stays live on screen and in the database.
class OcptScreenplayMergeConflict extends Equatable {
  /// The screenplay this conflict is about.
  final String screenplayId;

  /// The nearest common ancestor text the merge diffed both sides against, or the empty string
  /// when no common `screenplay_snapshots` row could be found at all — see
  /// `OcptScreenplayMergeService`'s own doc comment for when that happens and why this is still
  /// surfaced as a conflict rather than a crash.
  final String baseText;

  /// This replica's own text, left untouched: still the one stored in `screenplays.fountainText`
  /// and shown in the editor after this conflict is raised.
  final String localText;

  /// The incoming text this replica could not cleanly merge in.
  final String incomingText;

  /// Creates a screenplay merge conflict record.
  const OcptScreenplayMergeConflict({
    required this.screenplayId,
    required this.baseText,
    required this.localText,
    required this.incomingText,
  });

  @override
  List<Object?> get props => [screenplayId, baseText, localText, incomingText];

  @override
  String toString() =>
      'OcptScreenplayMergeConflict(screenplayId: $screenplayId, baseText: $baseText, '
      'localText: $localText, incomingText: $incomingText)';
}
