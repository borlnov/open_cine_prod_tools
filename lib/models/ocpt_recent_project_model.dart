// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <benoit.rolandeau@allcircuits.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_dart_utility/act_dart_utility.dart';
import 'package:act_global_manager/act_global_manager.dart';
import 'package:equatable/equatable.dart';

/// Represents a project the user has recently opened, so it can be listed and reopened quickly.
class OcptRecentProjectModel extends Equatable {
  /// This is the key used to stringify or parse the [path] from a JSON object
  static const _pathKey = "path";

  /// This is the key used to stringify or parse the [name] from a JSON object
  static const _nameKey = "name";

  /// This is the key used to stringify or parse the [lastOpenedAt] from a JSON object
  static const _lastOpenedAtKey = "lastOpenedAt";

  /// The absolute path to the project file on disk.
  final String path;

  /// The display name of the project.
  final String name;

  /// The date and time at which the project was last opened.
  final DateTime lastOpenedAt;

  /// Class constructor
  const OcptRecentProjectModel({
    required this.path,
    required this.name,
    required this.lastOpenedAt,
  });

  /// Copy the current project and update the given elements
  OcptRecentProjectModel copyWith({
    String? path,
    String? name,
    DateTime? lastOpenedAt,
  }) => OcptRecentProjectModel(
    path: path ?? this.path,
    name: name ?? this.name,
    lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
  );

  /// Transform the element to a JSON object
  Map<String, dynamic> toJson() => {
    _pathKey: path,
    _nameKey: name,
    _lastOpenedAtKey: lastOpenedAt.toIso8601String(),
  };

  /// Parse the given [json] to a [OcptRecentProjectModel] object
  ///
  /// Returns null if the given [json] doesn't hold the expected keys or if one of its values
  /// can't be cast to the expected type.
  static OcptRecentProjectModel? fromJson(Map<String, dynamic> json) {
    final pathResult = JsonUtility.getOnePrimaryElement<String>(
      json: json,
      key: _pathKey,
      logger: appLogger(),
    );

    final nameResult = JsonUtility.getOnePrimaryElement<String>(
      json: json,
      key: _nameKey,
      logger: appLogger(),
    );

    final lastOpenedAtResult = JsonUtility.getOneElement<DateTime, String>(
      json: json,
      key: _lastOpenedAtKey,
      castValueFunc: DateTime.tryParse,
      logger: appLogger(),
    );

    if (!pathResult.isOk || !nameResult.isOk || !lastOpenedAtResult.isOk) {
      appLogger().w("A problem occurred when tried to get the recent project from the given JSON");
      return null;
    }

    return OcptRecentProjectModel(
      path: pathResult.value!,
      name: nameResult.value!,
      lastOpenedAt: lastOpenedAtResult.value!,
    );
  }

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptRecentProjectModel(path: $path, name: $name, lastOpenedAt: $lastOpenedAt)";

  /// Object properties
  @override
  List<Object?> get props => [path, name, lastOpenedAt];
}
