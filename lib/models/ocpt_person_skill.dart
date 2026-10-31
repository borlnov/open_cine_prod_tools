// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';

/// A single skill of a person: a driving licence, a language, an instrument — a chip on the person
/// sheet, and the thing an assistant director searches on.
///
/// Not one of the nine model files the resources mode plan enumerates by name: it exists only as a
/// nested shape of [OcptPerson], exactly as `person_skills` only ever surfaces through a person's
/// own sheet.
class OcptPersonSkill extends Equatable {
  /// The stable, unique id of this skill entry (a UUID).
  final String id;

  /// The person who has this skill.
  final String personId;

  /// The skill itself, free text (e.g. "Permis B", "Anglais courant", "Piano").
  final String label;

  /// Class constructor
  const OcptPersonSkill({required this.id, required this.personId, required this.label});

  /// Builds an [OcptPersonSkill] from its stored [row].
  factory OcptPersonSkill.fromRow(OcptPersonSkillRow row) =>
      OcptPersonSkill(id: row.id, personId: row.personId, label: row.label);

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() => "OcptPersonSkill(id: $id, label: $label)";

  /// Object properties
  @override
  List<Object?> get props => [id, personId, label];
}
