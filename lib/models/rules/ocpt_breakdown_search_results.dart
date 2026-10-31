// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_breakdown_search_candidate.dart';

/// The matches of one query, grouped by kind the way the popover groups them — one section for
/// `Roles`, one for `Sets`, one for `Elements`, each already ranked and capped on its own.
class OcptBreakdownSearchResults extends Equatable {
  /// The matching roles, best match first.
  final List<OcptBreakdownSearchCandidate> roles;

  /// The matching sets, best match first.
  final List<OcptBreakdownSearchCandidate> sets;

  /// The matching elements, best match first.
  final List<OcptBreakdownSearchCandidate> elements;

  /// Class constructor
  const OcptBreakdownSearchResults({
    required this.roles,
    required this.sets,
    required this.elements,
  });

  /// Whether every section came back with nothing — the popover's cue to fall back on
  /// `Open in Resources` rather than an empty list.
  bool get isEmpty => roles.isEmpty && sets.isEmpty && elements.isEmpty;

  /// Object properties
  @override
  List<Object?> get props => [roles, sets, elements];
}
