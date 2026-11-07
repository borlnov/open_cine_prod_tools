// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_breakdown_search.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_target_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';

/// One catalogue row the tag popover can offer, flattened out of whichever of `elements`, `roles`
/// or `sets` [kind] names — the popover shows the three catalogues side by side and needs one shape
/// to rank and cap, not three.
class OcptBreakdownSearchCandidate extends Equatable {
  /// Which of the three catalogues this candidate comes from.
  final OcptBreakdownTargetKind kind;

  /// The stable, unique id of the underlying element, role or set.
  final String id;

  /// This candidate's display name — the only field a query is matched against, see
  /// [ocptBreakdownSearchCatalogues].
  final String name;

  /// The element's category, non-null only when [kind] is [OcptBreakdownTargetKind.element],
  /// exactly as `OcptBreakdownTarget.category` is.
  final OcptElementCategory? category;

  /// How many live scenes this row is already tagged in; 0 for a row the breakdown never touched.
  ///
  /// Used only to break ties in [ocptBreakdownSearchCatalogues]'s ranking: a thing already found
  /// once in the script is the more likely match for the thing being read now.
  final int taggedSceneCount;

  /// Class constructor
  const OcptBreakdownSearchCandidate({
    required this.kind,
    required this.id,
    required this.name,
    required this.category,
    required this.taggedSceneCount,
  });

  /// List the fields that decide equality.
  @override
  List<Object?> get props => [kind, id, name, category, taggedSceneCount];
}
