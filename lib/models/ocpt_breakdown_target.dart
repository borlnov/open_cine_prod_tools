// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/constants/ocpt_breakdown_palette.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_target_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_status.dart';

/// The one thing every breakdown tag is ultimately about, resolved out of whichever catalogue
/// (`elements`, `roles` or `sets`) its [kind] names.
///
/// The recap table, the script view's highlighting and the inspector all read this model rather
/// than an element, a role or a set directly, so none of them has to branch on [kind] at the widget
/// level — the branching happens once, in `OcptBreakdownSnapshot.build`.
///
/// Only an [OcptBreakdownTargetKind.element] carries a [category] and a [status]: a role's kind
/// (speaking, silent, extra) and a set's location are the equivalent facts for the other two
/// target kinds, but they live on `OcptRole`/`OcptSet` themselves, not here — this model does not
/// flatten every catalogue's own fields into one shape, it only ever leaves the two element-only
/// fields null for a role or a set.
class OcptBreakdownTarget extends Equatable {
  /// What kind of catalogue row this target is.
  final OcptBreakdownTargetKind kind;

  /// The stable, unique id of the underlying element, role or set.
  final String id;

  /// This target's display name.
  final String name;

  /// The element's category, non-null only when [kind] is [OcptBreakdownTargetKind.element].
  final OcptElementCategory? category;

  /// The element's status, non-null only when [kind] is [OcptBreakdownTargetKind.element].
  final OcptElementStatus? status;

  /// The live scenes this target is tagged in, in scene order, each scene id appearing once even
  /// when the target is tagged more than once in it — see [occurrenceCount] for the count that does
  /// grow with a repeated tag.
  final List<String> sceneIds;

  /// The number of live tags pointing at this target, across every scene.
  ///
  /// **Not** `sceneIds.length`: a target tagged twice in the same scene occurs twice but appears in
  /// one scene, and the recap table's occurrence count is this field, while [sceneIds] is what the
  /// inspector's "jump to" list and the recap's per-scene column read.
  final int occurrenceCount;

  /// Class constructor
  const OcptBreakdownTarget({
    required this.kind,
    required this.id,
    required this.name,
    required this.category,
    required this.status,
    required this.sceneIds,
    required this.occurrenceCount,
  });

  /// This target's colour, delegating to [ocptBreakdownColorOf].
  int get color => ocptBreakdownColorOf(kind: kind, category: category);

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptBreakdownTarget(kind: $kind, id: $id, name: $name, occurrenceCount: $occurrenceCount)";

  /// Object properties
  @override
  List<Object?> get props => [kind, id, name, category, status, sceneIds, occurrenceCount];
}
