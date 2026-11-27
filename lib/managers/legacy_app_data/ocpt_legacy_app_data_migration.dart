// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';
import 'dart:io';

import 'package:open_cine_prod_tools/models/ocpt_legacy_app_data_migration_result.dart';
import 'package:open_cine_prod_tools/models/ocpt_recent_project_model.dart';
import 'package:open_cine_prod_tools/types/ocpt_legacy_app_data_outcome.dart';
import 'package:open_cine_prod_tools/types/ocpt_legacy_file_action.dart';
import 'package:path/path.dart' as p;

/// The one-off migration of the application data a former product name left behind.
///
/// Platform-free on purpose, with nothing but `dart:io` and `dart:convert`: it takes the two
/// directories and a warning sink, so a test runs it on temporary directories. It never modifies
/// nor deletes anything in the legacy directory, so going back to an older build still finds its
/// data. The log files are not migrated.
///
/// The preferences file stores the keys of the async preferences API as they are, with no prefix.
/// The steps, in order:
///
/// 1. no legacy directory: nothing to do;
/// 2. the [markerKey] is already in the current preferences: nothing to do;
/// 3. the preferences are copied when the current directory has none, or merged otherwise (the
///    current value wins key by key, the keys only the legacy file holds are added, and the recent
///    projects are the union by path, newest first, capped at [ocptMaxRecentProjects]);
/// 4. the secure storage file is copied when the current directory has none, and the current one
///    is kept otherwise, since merging two DPAPI-encrypted stores would need to decrypt them;
/// 5. the [markerKey] is written, last, with the preferences.
///
/// A preferences file that is not a JSON object on either side stops the migration before anything
/// is written, marker included, so the next start tries again: writing the marker would otherwise
/// either overwrite a file we could not read or declare done what was not. The secure storage file
/// is independent of that and is still brought over.
class OcptLegacyAppDataMigration {
  /// The name of the file holding the preferences, in both directories.
  static const preferencesFileName = 'shared_preferences.json';

  /// The name of the file holding the secrets, in both directories.
  static const secretsFileName = 'flutter_secure_storage.dat';

  /// The key stored in the current preferences once the migration is done.
  static const markerKey = 'LEGACY_APP_DATA_MIGRATED';

  /// The key of the recent projects list: a JSON-encoded string holding a list of project maps.
  static const _recentProjectsKey = 'RECENT_PROJECTS';

  /// The key of a recent project's path.
  static const _pathKey = 'path';

  /// The key of a recent project's last opening date.
  static const _lastOpenedAtKey = 'lastOpenedAt';

  /// Not meant to be instantiated.
  const OcptLegacyAppDataMigration._();

  /// Run the migration from [legacyDirectory] to [currentDirectory].
  ///
  /// [onWarning] receives each message worth logging; none of them holds a path. An I/O error
  /// is not thrown: it is reported to [onWarning] and answered by
  /// [OcptLegacyAppDataOutcome.failed].
  static Future<OcptLegacyAppDataMigrationResult> run({
    required Directory legacyDirectory,
    required Directory currentDirectory,
    required void Function(String message) onWarning,
  }) async {
    OcptLegacyAppDataMigrationResult result;
    try {
      result = await _run(legacyDirectory, currentDirectory, onWarning);
    } on FileSystemException catch (error) {
      onWarning('The legacy application data migration failed: ${error.runtimeType}');
      result = const OcptLegacyAppDataMigrationResult(outcome: OcptLegacyAppDataOutcome.failed);
    }

    return result;
  }

  /// Run the migration, letting a file system error out.
  static Future<OcptLegacyAppDataMigrationResult> _run(
    Directory legacyDirectory,
    Directory currentDirectory,
    void Function(String message) onWarning,
  ) async {
    if (!legacyDirectory.existsSync()) {
      return const OcptLegacyAppDataMigrationResult(
        outcome: OcptLegacyAppDataOutcome.nothingToMigrate,
      );
    }

    final legacyPreferences = File(p.join(legacyDirectory.path, preferencesFileName));
    final currentPreferences = File(p.join(currentDirectory.path, preferencesFileName));
    final legacySecrets = File(p.join(legacyDirectory.path, secretsFileName));
    final currentSecrets = File(p.join(currentDirectory.path, secretsFileName));

    final current = await _readPreferences(currentPreferences);
    if (current.isMalformed) {
      onWarning('The current preferences are malformed, the legacy data is not migrated');
      return const OcptLegacyAppDataMigrationResult(
        outcome: OcptLegacyAppDataOutcome.failed,
        preferences: OcptLegacyFileAction.unreadable,
      );
    }
    if (current.values?[markerKey] == true) {
      return const OcptLegacyAppDataMigrationResult(
        outcome: OcptLegacyAppDataOutcome.alreadyMigrated,
      );
    }

    final legacy = await _readPreferences(legacyPreferences);
    if (legacy.isMalformed) {
      onWarning('The legacy preferences are malformed, the legacy data is not migrated');
    }

    await currentDirectory.create(recursive: true);

    // The secure storage does not depend on the preferences being readable.
    final secretsAction = await _migrateSecrets(legacySecrets, currentSecrets, onWarning);

    if (legacy.isMalformed) {
      return OcptLegacyAppDataMigrationResult(
        outcome: OcptLegacyAppDataOutcome.failed,
        preferences: OcptLegacyFileAction.unreadable,
        secrets: secretsAction,
      );
    }

    final preferencesAction = await _migratePreferences(
      legacy.values,
      current.values,
      currentPreferences,
    );

    return OcptLegacyAppDataMigrationResult(
      outcome: OcptLegacyAppDataOutcome.migrated,
      preferences: preferencesAction,
      secrets: secretsAction,
    );
  }

  /// Copy or keep the secure storage file, according to what the current directory holds.
  static Future<OcptLegacyFileAction> _migrateSecrets(
    File legacy,
    File current,
    void Function(String message) onWarning,
  ) async {
    if (!legacy.existsSync()) {
      return OcptLegacyFileAction.absent;
    }

    if (current.existsSync()) {
      onWarning(
        'Both the legacy and the current secure storage exist: keeping the current one, the '
        'legacy secrets are not merged',
      );
      return OcptLegacyFileAction.keptCurrent;
    }

    await _writeAtomically(current, await legacy.readAsBytes());
    return OcptLegacyFileAction.copied;
  }

  /// Write the merged preferences, with the marker, in [target].
  ///
  /// [legacy] is null when the legacy directory holds no preferences file, and [current] when the
  /// current one does not.
  static Future<OcptLegacyFileAction> _migratePreferences(
    Map<String, Object?>? legacy,
    Map<String, Object?>? current,
    File target,
  ) async {
    final merged = <String, Object?>{...?legacy, ...?current};
    if (legacy != null && current != null) {
      final recentProjects = _mergeRecentProjects(
        legacy[_recentProjectsKey],
        current[_recentProjectsKey],
      );
      if (recentProjects != null) {
        merged[_recentProjectsKey] = recentProjects;
      }
    }
    merged[markerKey] = true;

    await _writeAtomically(target, utf8.encode(jsonEncode(merged)));

    if (legacy == null) {
      return OcptLegacyFileAction.absent;
    }
    return current == null ? OcptLegacyFileAction.copied : OcptLegacyFileAction.merged;
  }

  /// Merge two stored recent projects lists into one, or return null when the current value is to
  /// stay as it is (one side is missing or does not hold a list of project maps).
  static String? _mergeRecentProjects(Object? legacyValue, Object? currentValue) {
    final legacyProjects = _decodeProjects(legacyValue);
    final currentProjects = _decodeProjects(currentValue);
    if (legacyProjects == null || currentProjects == null) {
      return null;
    }

    final byPath = <String, Map<String, Object?>>{};
    for (final project in [...legacyProjects, ...currentProjects]) {
      // The current entries come last, so they replace the legacy one of the same path.
      byPath[project[_pathKey]! as String] = project;
    }

    final merged = byPath.values.toList()
      ..sort((a, b) => _lastOpenedAt(b).compareTo(_lastOpenedAt(a)));

    return jsonEncode(merged.take(ocptMaxRecentProjects).toList());
  }

  /// Decode a stored recent projects value, keeping the maps that have a string path; null when it
  /// is not a JSON-encoded list.
  static List<Map<String, Object?>>? _decodeProjects(Object? value) {
    if (value is! String) {
      return null;
    }

    Object? decoded;
    try {
      decoded = jsonDecode(value);
    } on FormatException {
      decoded = null;
    }

    return decoded is List<Object?>
        ? [
            for (final entry in decoded)
              if (entry is Map<String, Object?> && entry[_pathKey] is String) entry,
          ]
        : null;
  }

  /// Get the last opening date of a recent project, the epoch when it holds none readable.
  static DateTime _lastOpenedAt(Map<String, Object?> project) {
    final value = project[_lastOpenedAtKey];
    final date = value is String ? DateTime.tryParse(value) : null;

    return date ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }

  /// Read the preferences [file]: [_ReadPreferences.values] is null when it does not exist, and
  /// [_ReadPreferences.isMalformed] says it is not a JSON object.
  static Future<_ReadPreferences> _readPreferences(File file) async {
    if (!file.existsSync()) {
      return const _ReadPreferences(values: null, isMalformed: false);
    }

    Object? decoded;
    try {
      decoded = jsonDecode(await file.readAsString());
    } on FormatException {
      decoded = null;
    }

    return decoded is Map<String, Object?>
        ? _ReadPreferences(values: decoded, isMalformed: false)
        : const _ReadPreferences(values: null, isMalformed: true);
  }

  /// Write [bytes] into [target] through a temporary sibling, so a crash never leaves it half
  /// written.
  static Future<void> _writeAtomically(File target, List<int> bytes) async {
    final temporary = File('${target.path}.migrating');
    await temporary.writeAsBytes(bytes, flush: true);
    await temporary.rename(target.path);
  }
}

/// The preferences file as read by [OcptLegacyAppDataMigration].
class _ReadPreferences {
  /// The stored values, or null when the file is absent or malformed.
  final Map<String, Object?>? values;

  /// Whether the file exists but is not a JSON object.
  final bool isMalformed;

  /// Class constructor
  const _ReadPreferences({required this.values, required this.isMalformed});
}
