// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_logger_manager/act_logger_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_screenplay_service.dart';
import 'package:open_cine_prod_tools/models/ocpt_open_project_model.dart';

/// Close the open project and keep the recent-projects entry's episode count truthful.
///
/// Stateless: the open project itself is the manager's state, which `closeProject` reports
/// clearing through `onClosed`, at the point the old behaviour cleared it.
abstract final class OcptProjectEpisodeOps {
  /// Close the `currentProject`, disposing its database handle. Does nothing if no project is
  /// open.
  ///
  /// A project closed while a version is being previewed disposes both of its connections: the
  /// in-memory one holding the version, then the project file itself. Before either goes, the
  /// recent-projects entry for this project is updated with its live episode count, read through
  /// [screenplayService]'s own [OcptScreenplayService.loadEpisodes] over
  /// [OcptOpenProjectModel.fileDatabase] — the working copy, **never**
  /// [OcptOpenProjectModel.database], which would be the in-memory preview database while a
  /// version is being previewed — so a session that added or deleted episodes leaves a truthful
  /// count behind rather than the one it opened with, and previewing a version never overwrites it
  /// with a count that isn't the project's own.
  static Future<void> closeProject({
    required OcptOpenProjectModel? project,
    required OcptScreenplayService screenplayService,
    required OcptPropertiesManager propertiesManager,
    required LogsHelper logger,
    required void Function() onClosed,
  }) async {
    if (project == null) {
      return;
    }

    final episodes = await screenplayService.loadEpisodes(database: project.fileDatabase);
    if (episodes.isError) {
      // Raises as the database used to: this goes when the manager answers a result of its own.
      throw StateError("The episodes of the project could not be counted");
    }

    final episodeCount = episodes.value!.length;

    onClosed();

    if (project.isReadOnly) {
      await project.database.close();
    }

    await project.fileDatabase.close();

    await recordEpisodeCount(
      path: project.path,
      episodeCount: episodeCount,
      propertiesManager: propertiesManager,
    );

    logger.i("A project was closed: ${project.primaryScreenplayId}");
  }

  /// Update the recent-projects entry for the `currentProject` so it carries the episode count
  /// the project holds right now. Does nothing when no project is open.
  ///
  /// `closeCurrentProject` records that count on the way out too, but only a session that *leaves*
  /// the project ever reaches it: an app closed while the project is still open never runs it, and
  /// the home card would then go on showing the count the project was opened with until the next
  /// time it is opened. Whoever adds or removes an episode calls this the moment it happens, so
  /// that count survives a window closed on the spot.
  ///
  /// The live count is read over [OcptOpenProjectModel.fileDatabase] — the working copy, **never**
  /// [OcptOpenProjectModel.database], which would be the in-memory preview database while a
  /// version is being previewed.
  static Future<void> recordOpenProjectEpisodeCount({
    required OcptOpenProjectModel? project,
    required OcptScreenplayService screenplayService,
    required OcptPropertiesManager propertiesManager,
  }) async {
    if (project == null) {
      return;
    }

    final episodes = await screenplayService.loadEpisodes(database: project.fileDatabase);
    if (episodes.isError) {
      // Raises as the database used to: this goes when the manager answers a result of its own.
      throw StateError("The episodes of the project could not be counted");
    }

    final episodeCount = episodes.value!.length;

    await recordEpisodeCount(
      path: project.path,
      episodeCount: episodeCount,
      propertiesManager: propertiesManager,
    );
  }

  /// Update the recent-projects entry for [path], if it is still in the list, so it carries
  /// [episodeCount] rather than whichever count was recorded when the project was opened.
  ///
  /// Left untouched, rather than created, when [path] isn't in the list at all — e.g. it was
  /// removed from the recent projects list while the project stayed open.
  static Future<void> recordEpisodeCount({
    required String path,
    required int episodeCount,
    required OcptPropertiesManager propertiesManager,
  }) async {
    final recents = await propertiesManager.recentProjects.load() ?? const [];
    final index = recents.indexWhere((entry) => entry.path == path);
    if (index == -1) {
      return;
    }

    final updated = [...recents];
    updated[index] = updated[index].copyWith(episodeCount: episodeCount);
    await propertiesManager.recentProjects.store(updated);
  }
}
