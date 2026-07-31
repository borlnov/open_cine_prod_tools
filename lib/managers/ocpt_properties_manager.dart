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
import 'package:open_cine_prod_tools/types/ocpt_shot_list_column.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_workspace_mode.dart';

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
/// brightness, it stores the list of recently opened projects, the preferred editor mode, the
/// app-wide page margins preference, the editor's dock width fractions, its scene-number
/// visibility preference, the last used workspace mode, and the shot list mode's own dock
/// fractions, visible table columns and last right dock tab.
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

  /// This is the key used to store the last used workspace mode in the local storage.
  ///
  /// Loading it returns null if nothing has been stored yet, which is equivalent to
  /// [OcptWorkspaceMode.screenplay].
  final workspaceMode = SharedPrefsItemWithParser<OcptWorkspaceMode, String>(
    "WORKSPACE_MODE",
    parser: _parseWorkspaceMode,
    castTo: (value) => value.name,
  );

  /// This is the key used to store whether the editor's "Word-like" page simulation is enabled.
  ///
  /// Loading it returns null if nothing has been stored yet, which is equivalent to `true`
  /// (page simulation is on by default).
  final isPageSimulationEnabled = SharedPreferencesItem<bool>("PAGE_SIMULATION_ENABLED");

  /// This is the key used to store whether the styled editor shows every scene heading's number
  /// (explicit or computed) in its left gutter.
  ///
  /// Loading it returns null if nothing has been stored yet, which is equivalent to `true` (scene
  /// numbers are shown by default).
  final styledSceneNumbersVisible = SharedPreferencesItem<bool>("STYLED_SCENE_NUMBERS_VISIBLE");

  /// This is the key used to store the left (scenes) dock's width, as a fraction of the editor's
  /// editing row width.
  ///
  /// Loading it returns null if nothing has been stored yet, which is equivalent to
  /// `OcptWorkspaceDock.leftDefaultFraction`, applied at the call site.
  final editorLeftDockFraction = SharedPreferencesItem<double>("EDITOR_LEFT_DOCK_FRACTION");

  /// This is the key used to store the right (preview / syntax) dock's width, as a fraction of
  /// the editor's editing row width.
  ///
  /// Loading it returns null if nothing has been stored yet, which is equivalent to
  /// `OcptWorkspaceDock.rightDefaultFraction`, applied at the call site.
  final editorRightDockFraction = SharedPreferencesItem<double>("EDITOR_RIGHT_DOCK_FRACTION");

  /// This is the key used to store the shot list mode's left (sequences) dock width, as a
  /// fraction of its editing row width.
  ///
  /// Kept separate from [editorLeftDockFraction]: the two modes show different panels in that
  /// dock, so a width that suits one has no reason to suit the other. Loading it returns null if
  /// nothing has been stored yet, which is equivalent to `OcptWorkspaceDock.leftDefaultFraction`,
  /// applied at the call site.
  final shotListLeftDockFraction = SharedPreferencesItem<double>("SHOT_LIST_LEFT_DOCK_FRACTION");

  /// This is the key used to store the shot list mode's right (inspector) dock width, as a
  /// fraction of its editing row width.
  ///
  /// Kept separate from [editorRightDockFraction] for the same reason
  /// [shotListLeftDockFraction] is. Loading it returns null if nothing has been stored yet, which
  /// is equivalent to `OcptWorkspaceDock.rightDefaultFraction`, applied at the call site.
  final shotListRightDockFraction = SharedPreferencesItem<double>("SHOT_LIST_RIGHT_DOCK_FRACTION");

  /// This is the key used to store which optional columns of the shot list table are visible, as
  /// the [OcptShotListColumn] names joined by [_shotListColumnsSeparator].
  ///
  /// An empty stored string is a meaningful value (every optional column hidden) and is kept
  /// apart from "nothing stored yet", which loads as null and is equivalent to
  /// [OcptShotListColumn.defaultVisibleColumns], applied at the call site. A stored name no
  /// longer matching any enum value is dropped, so removing a column in a later version can never
  /// make this preference unreadable.
  final shotListVisibleColumns = SharedPrefsItemWithParser<Set<OcptShotListColumn>, String>(
    "SHOT_LIST_VISIBLE_COLUMNS",
    parser: _parseShotListColumns,
    castTo: _castShotListColumns,
  );

  /// This is the key used to store the tab the shot list mode's right dock last showed, so
  /// reopening the dock brings it back where the user left it.
  ///
  /// Loading it returns null if nothing has been stored yet, which is equivalent to
  /// [OcptShotListRightDockTab.inspector].
  final shotListLastRightDockTab = SharedPrefsItemWithParser<OcptShotListRightDockTab, String>(
    "SHOT_LIST_LAST_RIGHT_DOCK_TAB",
    parser: _parseShotListRightDockTab,
    castTo: (value) => value.name,
  );

  /// The separator joining the [OcptShotListColumn] names stored for [shotListVisibleColumns].
  static const _shotListColumnsSeparator = ",";

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

  /// Parse the [value] stored in the local storage to the wanted [OcptWorkspaceMode].
  ///
  /// Returns null if the [value] doesn't match any of the [OcptWorkspaceMode] values.
  static OcptWorkspaceMode? _parseWorkspaceMode(String value) {
    for (final mode in OcptWorkspaceMode.values) {
      if (mode.name == value) {
        return mode;
      }
    }

    appLogger().w("The workspace mode stored in the local storage: $value, isn't a known "
        "workspace mode, we can't convert it");
    return null;
  }

  /// Parse the [value] stored in the local storage to the visible shot list table columns.
  ///
  /// Never returns null: an unknown name is simply skipped, so a preference written by a version
  /// knowing a column this one doesn't still yields the columns both versions agree on rather
  /// than falling back to the defaults wholesale.
  static Set<OcptShotListColumn>? _parseShotListColumns(String value) {
    final names = value.split(_shotListColumnsSeparator);
    final columns = <OcptShotListColumn>{};

    for (final name in names) {
      for (final column in OcptShotListColumn.values) {
        if (column.name == name) {
          columns.add(column);
        }
      }
    }

    return columns;
  }

  /// Cast the visible shot list table columns to the string representation stored in the local
  /// storage.
  static String? _castShotListColumns(Set<OcptShotListColumn> value) =>
      value.map((column) => column.name).join(_shotListColumnsSeparator);

  /// Parse the [value] stored in the local storage to the wanted [OcptShotListRightDockTab].
  ///
  /// Returns null if the [value] doesn't match any of the [OcptShotListRightDockTab] values.
  static OcptShotListRightDockTab? _parseShotListRightDockTab(String value) {
    for (final tab in OcptShotListRightDockTab.values) {
      if (tab.name == value) {
        return tab;
      }
    }

    appLogger().w("The shot list right dock tab stored in the local storage: $value, isn't a "
        "known tab, we can't convert it");
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
