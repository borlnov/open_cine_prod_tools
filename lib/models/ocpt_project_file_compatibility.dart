// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_file_verdict.dart';

/// What a read-only look at a project file says about opening it with this build: which format it
/// is in, which one this build writes, and what has to happen — or be refused — in between.
///
/// Everything a user is told before their project file is touched comes from here, [verdict]
/// included, so the sentence they read and the work that follows cannot say two different things.
/// [suggestedBackupPath] is the sharpest case of that: the migration dialog names that exact path
/// as where the copy will be kept, and the open then writes exactly there.
class OcptProjectFileCompatibility extends Equatable {
  /// The project file this is about.
  ///
  /// Carried rather than left to the caller to remember: the verdict travels through a page's state
  /// and comes back as the answer to a question the user took their time over, and the file that
  /// answer is about must be the one that was asked about.
  final String filePath;

  /// The `PRAGMA user_version` the file states about itself, or 0 when it states none — which is
  /// what an [OcptProjectFileVerdict.unreadable] file always reports.
  final int fileSchemaVersion;

  /// The schema version this build of the app writes.
  final int appSchemaVersion;

  /// The app version stamped into `project_info.appVersionAtCreation` when the project was
  /// created, or null when that table isn't there to read (a file from before it existed, or one
  /// that isn't a project at all).
  ///
  /// Only ever shown, never compared: it is what lets the refusal of a newer file name the build
  /// the user has to go and find, instead of leaving them with two schema numbers that mean
  /// nothing outside this code.
  final String? appVersionAtCreation;

  /// Where the copy of the file is to be kept before it is migrated, or null when no migration is
  /// on the table ([verdict] being anything but [OcptProjectFileVerdict.older]).
  ///
  /// It sits beside the original and keeps its extension on purpose: it is a file the older build
  /// can still open, which is the whole reason for taking it.
  final String? suggestedBackupPath;

  /// The app version stamped into `project_info.migratedByAppVersion` — the file's writer
  /// identity — or null when there is nothing to read (a file from before the column existed, one
  /// that never migrated, or one that isn't a project at all).
  ///
  /// Carried so a refusal of [OcptProjectFileVerdict.foreignDevBuild] can name the exact build the
  /// file was written by, which is the one build guaranteed to open it again.
  final String? migratedByAppVersion;

  /// Whether the running build's own version — not the file's — is a pre-release, per
  /// `docs/adr/0029-schema-versions-frozen-at-stable-releases.md`.
  ///
  /// Carried rather than left to the caller to re-parse, so the page can word an
  /// [OcptProjectFileVerdict.older] migration as a "development build, at your own risk" warning
  /// instead of the stable wording.
  final bool isRunningBuildPreRelease;

  /// What this file's format means for the build about to open it.
  final OcptProjectFileVerdict verdict;

  /// Class constructor
  const OcptProjectFileCompatibility({
    required this.filePath,
    required this.fileSchemaVersion,
    required this.appSchemaVersion,
    required this.verdict,
    this.appVersionAtCreation,
    this.suggestedBackupPath,
    this.migratedByAppVersion,
    required this.isRunningBuildPreRelease,
  });

  /// Object properties
  @override
  List<Object?> get props => [
    filePath,
    fileSchemaVersion,
    appSchemaVersion,
    appVersionAtCreation,
    suggestedBackupPath,
    migratedByAppVersion,
    isRunningBuildPreRelease,
    verdict,
  ];
}
