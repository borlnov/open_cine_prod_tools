// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/types/ocpt_legacy_app_data_outcome.dart';
import 'package:open_cine_prod_tools/types/ocpt_legacy_file_action.dart';

/// The answer of the legacy Windows application data migration: what it concluded and what it did
/// with each of the two files it brings over.
class OcptLegacyAppDataMigrationResult extends Equatable {
  /// What the migration concluded.
  final OcptLegacyAppDataOutcome outcome;

  /// What was done with `shared_preferences.json`.
  final OcptLegacyFileAction preferences;

  /// What was done with `flutter_secure_storage.dat`.
  final OcptLegacyFileAction secrets;

  /// Class constructor
  const OcptLegacyAppDataMigrationResult({
    required this.outcome,
    this.preferences = OcptLegacyFileAction.skipped,
    this.secrets = OcptLegacyFileAction.skipped,
  });

  /// Get a string representation of the object, useful for debugging and logging.
  @override
  String toString() =>
      "OcptLegacyAppDataMigrationResult(outcome: ${outcome.name}, "
      "preferences: ${preferences.name}, secrets: ${secrets.name})";

  /// List the fields that decide equality.
  @override
  List<Object?> get props => [outcome, preferences, secrets];
}
