// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';

import 'package:act_dart_utility/act_dart_utility.dart';
import 'package:act_logger_manager/act_logger_manager.dart';
import 'package:equatable/equatable.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_version_payload.dart';

/// The counters shown on a project version's card and in the read-only preview banner, e.g.
/// `41 pages · 3 sequence(s) broken down`.
///
/// They are computed **once**, when the version is created ([OcptProjectVersionSummary.of]), and
/// stored alongside it in `project_versions.summaryJson`: drawing the versions list must never mean
/// deserializing and re-measuring every payload.
class OcptProjectVersionSummary extends Equatable {
  /// The all-zero summary, used for a version whose stored counters can't be read back.
  static const empty = OcptProjectVersionSummary(pageCount: 0, brokenDownSequenceCount: 0);

  /// The category this class logs under.
  static const _loggerCategory = "project_version_summary";

  /// This is the key used to stringify or parse the [pageCount] from a JSON object
  static const _pageCountKey = "pageCount";

  /// This is the key used to stringify or parse the [brokenDownSequenceCount] from a JSON object
  static const _brokenDownSequenceCountKey = "brokenDownSequenceCount";

  /// The number of printed pages the version's screenplays paginated to, at the page setup the
  /// version itself carries.
  final int pageCount;

  /// The number of sequences (screenplay scenes) that had at least one shot when the version was
  /// created.
  final int brokenDownSequenceCount;

  /// Class constructor
  const OcptProjectVersionSummary({required this.pageCount, required this.brokenDownSequenceCount});

  /// Measure [payload], at the page setup that payload carries.
  ///
  /// The page count is the same one the status bar and the PDF exporter show, so a version's card
  /// and its restored project agree: it comes from [FountainScriptStatistics], summed over the live
  /// screenplays. A sequence counts as broken down as soon as one live shot points at it;
  /// orphaned shots (whose scene is gone) belong to no sequence and count for none.
  factory OcptProjectVersionSummary.of(OcptProjectVersionPayload payload) {
    const parser = FountainParser();
    final metrics = payload.pageSetup.toMetrics();

    var pageCount = 0;
    for (final screenplay in payload.screenplays) {
      if (screenplay.isDeleted) {
        continue;
      }

      pageCount += FountainScriptStatistics.of(
        parser.parse(screenplay.fountainText),
        metrics,
      ).pageCount;
    }

    final brokenDownSceneIds = <String>{
      for (final shot in payload.shots)
        if (!shot.isDeleted && shot.sceneId != null) shot.sceneId!,
    };

    return OcptProjectVersionSummary(
      pageCount: pageCount,
      brokenDownSequenceCount: brokenDownSceneIds.length,
    );
  }

  /// Transform the element to a JSON object
  Map<String, dynamic> toJson() => {
    _pageCountKey: pageCount,
    _brokenDownSequenceCountKey: brokenDownSequenceCount,
  };

  /// Get a string representation of the object, useful for debugging and logging.
  @override
  String toString() =>
      "OcptProjectVersionSummary(pageCount: $pageCount, "
      "brokenDownSequenceCount: $brokenDownSequenceCount)";

  /// Parse the given [json] to a [OcptProjectVersionSummary] object
  ///
  /// Returns null if the given [json] doesn't hold the expected keys or if one of its values can't
  /// be cast to the expected type.
  static OcptProjectVersionSummary? fromJson(Map<String, dynamic> json) {
    final pageCountResult = JsonUtility.getOnePrimaryElement<int>(
      json: json,
      key: _pageCountKey,
      logger: _createLogger(),
    );

    final brokenDownSequenceCountResult = JsonUtility.getOnePrimaryElement<int>(
      json: json,
      key: _brokenDownSequenceCountKey,
      logger: _createLogger(),
    );

    if (!pageCountResult.isOk || !brokenDownSequenceCountResult.isOk) {
      _createLogger().w(
        "A problem occurred when tried to get the project version summary from the "
        "given JSON",
      );
      return null;
    }

    return OcptProjectVersionSummary(
      pageCount: pageCountResult.value!,
      brokenDownSequenceCount: brokenDownSequenceCountResult.value!,
    );
  }

  /// Parse the [summaryJson] text stored in a `project_versions` row, falling back to [empty].
  ///
  /// A summary is a display detail: a version whose counters can't be read back is still perfectly
  /// restorable, so an unreadable one is logged and shown as zeroes rather than hiding the version
  /// from its own list.
  static OcptProjectVersionSummary parse(String summaryJson) {
    var summary = empty;
    try {
      final decoded = jsonDecode(summaryJson);
      if (decoded is! Map<String, dynamic>) {
        _createLogger().w("The stored project version summary isn't a JSON object");
      } else {
        summary = fromJson(decoded) ?? empty;
      }
    } on FormatException catch (error, stackTrace) {
      // A JSON error quotes the text around the fault, so only its type is logged.
      _createLogger().w(
        "The stored project version summary isn't valid JSON: ${error.runtimeType}",
        null,
        stackTrace,
      );
    }

    return summary;
  }

  /// Build the logger this class writes to.
  ///
  /// Built on every use rather than held: a model has no life cycle to release a logger with, and
  /// the global logger it is built over can be replaced.
  static LogsHelper _createLogger() => LogsHelper(category: _loggerCategory);

  /// List the fields that decide equality.
  @override
  List<Object?> get props => [pageCount, brokenDownSequenceCount];
}
