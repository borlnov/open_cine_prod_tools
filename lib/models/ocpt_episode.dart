// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';

/// One episode of the project: a `screenplays` row, read the way `docs/adr/0019` settles it — **a
/// screenplay row is an episode**, so this model is `OcptScreenplayService`'s own read of that row
/// rather than a second table's.
///
/// Unlike `OcptRole.number` (a role's rank, derived at read time and stored nowhere), [number] is
/// **stored on the row**: it is the printed number the ADR is explicit carries no uniqueness
/// constraint (two episodes numbered 4 is a state the user reaches by hand and repairs by hand),
/// while `sortKey` — never exposed here, exactly as `OcptRole` exposes no `sortKey` of its own — is
/// what actually orders the episodes. Nothing outside `OcptScreenplayService` orders by it.
///
/// [title] being empty is an ordinary state, not a placeholder to fill in a hurry: a series is
/// regularly numbered long before it is titled. Rendering `Episode 3` for an untitled one is UI
/// work the mode does, never this model — no manager or service ever sees a `Tr`, and a model is
/// read by both.
class OcptEpisode extends Equatable {
  /// The stable, unique id of this episode's screenplay row (a UUID).
  final String id;

  /// This episode's printed number. See the class doc comment for why it is stored rather than
  /// derived, unlike `OcptRole.number`.
  final int number;

  /// This episode's title, or the empty string while it has none — an ordinary state.
  final String title;

  /// Class constructor
  const OcptEpisode({required this.id, required this.number, required this.title});

  /// Builds an [OcptEpisode] from its stored [row].
  factory OcptEpisode.fromRow(OcptScreenplayRow row) =>
      OcptEpisode(id: row.id, number: row.number, title: row.title);

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() => "OcptEpisode(id: $id, number: $number, title: $title)";

  /// Object properties
  @override
  List<Object?> get props => [id, number, title];
}
