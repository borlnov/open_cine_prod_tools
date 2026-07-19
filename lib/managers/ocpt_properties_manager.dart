// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';

import 'package:act_dart_utility/act_dart_utility.dart';
import 'package:act_global_manager/act_global_manager.dart';
import 'package:act_intl/act_intl.dart';
import 'package:act_local_storage_manager/act_local_storage_manager.dart';
import 'package:act_themes_manager/act_themes_manager.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/models/ocpt_recent_project_model.dart';
import 'package:open_cine_prod_tools/types/ocpt_editor_mode.dart';

/// The maximum number of projects kept in [OcptPropertiesManager.recentProjects].
const _maxRecentProjects = 10;

/// This is the builder for the properties manager of the app
class OcptPropertiesManagerBuilder extends AbstractPropertiesBuilder<OcptPropertiesManager> {
  /// Class constructor
  const OcptPropertiesManagerBuilder() : super(OcptPropertiesManager.new);
}

/// This is the properties manager of the app.
///
/// On top of the [MixinLocaleProperties] wanted locale and the [MixinThemesProperties] theme and
/// brightness, it stores the list of recently opened projects, the preferred editor mode and the
/// app-wide page margins preference.
class OcptPropertiesManager extends AbstractPropertiesManager
    with MixinLocaleProperties, MixinThemesProperties {
  /// This is the key used to store the recently opened projects in the local storage.
  ///
  /// Loading it returns null if nothing has been stored yet, which is equivalent to an empty
  /// list; prefer [addRecentProject] and [removeRecentProject] over storing to this item
  /// directly.
  final recentProjects = SharedPrefsItemWithParser<List<OcptRecentProjectModel>, String>(
    "RECENT_PROJECTS",
    parser: _parseRecentProjects,
    castTo: _castRecentProjects,
  );

  /// This is the key used to store the preferred editor mode in the local storage.
  ///
  /// Loading it returns null if nothing has been stored yet, which is equivalent to
  /// [OcptEditorMode.styled].
  final editorMode = SharedPrefsItemWithParser<OcptEditorMode, String>(
    "EDITOR_MODE",
    parser: _parseEditorMode,
    castTo: (value) => value.name,
  );

  /// This is the key used to store whether the editor's "Word-like" page simulation is enabled.
  ///
  /// Loading it returns null if nothing has been stored yet, which is equivalent to `true`
  /// (page simulation is on by default).
  final isPageSimulationEnabled = SharedPreferencesItem<bool>("PAGE_SIMULATION_ENABLED");

  /// This is the key used to stringify or parse the [FountainPageMargins.leftInches] from/to the
  /// JSON object stored for [pageMargins].
  static const _marginLeftKey = "leftInches";

  /// This is the key used to stringify or parse the [FountainPageMargins.rightInches] from/to the
  /// JSON object stored for [pageMargins].
  static const _marginRightKey = "rightInches";

  /// This is the key used to stringify or parse the [FountainPageMargins.topInches] from/to the
  /// JSON object stored for [pageMargins].
  static const _marginTopKey = "topInches";

  /// This is the key used to stringify or parse the [FountainPageMargins.bottomInches] from/to the
  /// JSON object stored for [pageMargins].
  static const _marginBottomKey = "bottomInches";

  /// This is the key used to store the app-wide page margins preference in the local storage.
  ///
  /// Margins are a rendering preference shared by every project (unlike the page format, which is
  /// stored per project in `project_info.pageFormat`). Loading it returns null if nothing has been
  /// stored yet, which is equivalent to `FountainPageMargins.standard()`, applied at the call site.
  final pageMargins = SharedPrefsItemWithParser<FountainPageMargins, String>(
    "PAGE_MARGINS",
    parser: _parsePageMargins,
    castTo: _castPageMargins,
  );

  /// Add [project] to [recentProjects], or move it to the front if it's already there.
  ///
  /// The list is kept sorted with the most recently opened project first and capped at
  /// [_maxRecentProjects] entries; the oldest entries are dropped past that cap.
  Future<void> addRecentProject(OcptRecentProjectModel project) async {
    final current = await recentProjects.load() ?? const [];
    final withoutDuplicate = current.where((element) => element.path != project.path);
    final updated = [project, ...withoutDuplicate].take(_maxRecentProjects).toList();

    await recentProjects.store(updated);
  }

  /// Remove the project at [path] from [recentProjects], if it's present.
  Future<void> removeRecentProject(String path) async {
    final current = await recentProjects.load() ?? const [];
    final updated = current.where((element) => element.path != path).toList();

    await recentProjects.store(updated);
  }

  /// Parse the [value] stored in the local storage to the list of recent projects.
  ///
  /// Returns null if the [value] isn't a valid JSON array of recent projects.
  static List<OcptRecentProjectModel>? _parseRecentProjects(String value) {
    final jsonList = JsonUtility.parseJsonArrayBodyToArray(value, logger: appLogger());
    if (jsonList == null) {
      appLogger().w("The recent projects stored in the local storage isn't a JSON array, we "
          "can't convert it");
      return null;
    }

    final projects = <OcptRecentProjectModel>[];
    for (final jsonEntry in jsonList) {
      final project = OcptRecentProjectModel.fromJson(jsonEntry);
      if (project != null) {
        projects.add(project);
      }
    }

    return projects;
  }

  /// Cast the list of recent projects to the string representation stored in the local storage.
  static String? _castRecentProjects(List<OcptRecentProjectModel> value) =>
      jsonEncode(value.map((project) => project.toJson()).toList());

  /// Parse the [value] stored in the local storage to the wanted [OcptEditorMode].
  ///
  /// Returns null if the [value] doesn't match any of the [OcptEditorMode] values.
  static OcptEditorMode? _parseEditorMode(String value) {
    for (final mode in OcptEditorMode.values) {
      if (mode.name == value) {
        return mode;
      }
    }

    appLogger().w("The editor mode stored in the local storage: $value, isn't a known editor "
        "mode, we can't convert it");
    return null;
  }

  /// Parse the [value] stored in the local storage to the app-wide page margins.
  ///
  /// Returns null if the [value] isn't a valid JSON object holding the four margins.
  static FountainPageMargins? _parsePageMargins(String value) {
    final json = JsonUtility.parseJsonBodyToObj(value, logger: appLogger());
    if (json == null) {
      appLogger().w("The page margins stored in the local storage isn't a JSON object, we can't "
          "convert it");
      return null;
    }

    final leftResult = JsonUtility.getOnePrimaryElement<double>(
      json: json,
      key: _marginLeftKey,
      logger: appLogger(),
    );
    final rightResult = JsonUtility.getOnePrimaryElement<double>(
      json: json,
      key: _marginRightKey,
      logger: appLogger(),
    );
    final topResult = JsonUtility.getOnePrimaryElement<double>(
      json: json,
      key: _marginTopKey,
      logger: appLogger(),
    );
    final bottomResult = JsonUtility.getOnePrimaryElement<double>(
      json: json,
      key: _marginBottomKey,
      logger: appLogger(),
    );

    if (!leftResult.isOk || !rightResult.isOk || !topResult.isOk || !bottomResult.isOk) {
      appLogger().w("A problem occurred when tried to get the page margins from the given JSON");
      return null;
    }

    return FountainPageMargins(
      leftInches: leftResult.value!,
      rightInches: rightResult.value!,
      topInches: topResult.value!,
      bottomInches: bottomResult.value!,
    );
  }

  /// Cast the page margins to the JSON string representation stored in the local storage.
  static String? _castPageMargins(FountainPageMargins value) => jsonEncode({
    _marginLeftKey: value.leftInches,
    _marginRightKey: value.rightInches,
    _marginTopKey: value.topInches,
    _marginBottomKey: value.bottomInches,
  });
}
