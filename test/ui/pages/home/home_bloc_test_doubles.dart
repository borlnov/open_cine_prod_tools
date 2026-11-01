// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:act_dart_result/act_dart_result.dart';
import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:act_platform_manager/act_platform_manager.dart';
import 'package:act_test_utility/act_test_utility.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_save_location_service.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_imported_fountain_model.dart';
import 'package:open_cine_prod_tools/types/ocpt_route.dart';
import 'package:open_cine_prod_tools/types/ocpt_screenplay_import_status.dart';
import 'package:open_cine_prod_tools/ui/pages/home/home_bloc.dart';

/// A [PlatformManager] whose [isMobile] is stubbed, so a test can exercise either of
/// [OcptHomeBloc]'s "New project"/import branches without a real platform underneath it — the same
/// double `ocpt_export_manager_documents_and_write_funnel_test.dart`'s own `StubPlatformManager`
/// already is.
class StubPlatformManager extends PlatformManager {
  /// Whether this double stands for a mobile platform.
  @override
  final bool isMobile;

  /// Class constructor
  StubPlatformManager({required this.isMobile});
}

/// An export manager whose [pickAndReadScreenplay] is stubbed, to exercise the bloc's import flow
/// without any real file dialog. [fountainIoService] is left as the real, pure implementation.
///
/// [isMobile] defaults to true so a test not exercising the desktop save-file dialog keeps taking
/// the very same no-dialog branch it always has ([OcptProjectsManager.freeNewProjectFilePath]);
/// [saveLocationService] is only reached at all once a test sets [isMobile] to false.
class FakeExportManager extends OcptExportManager {
  /// The model [pickAndReadScreenplay] returns, or null to return no value at all.
  final OcptImportedFountainModel? importResult;

  /// The status [pickAndReadScreenplay] returns when [importResult] is null, defaulting to a
  /// cancelled open dialog.
  final OcptScreenplayImportStatus importStatus;

  /// The file type label of the last [pickAndReadScreenplay] call.
  String? lastFileTypeLabel;

  /// Class constructor
  FakeExportManager({
    this.importResult,
    this.importStatus = OcptScreenplayImportStatus.cancelled,
    bool isMobile = true,
    super.saveLocationService,
  }) : super(
         fileSelectorManager: const FileSelectorManager(),
         platformManager: StubPlatformManager(isMobile: isMobile),
       );

  /// Remember the file type label, and answer with the canned screenplay, or with the canned status
  /// when there is none.
  @override
  Future<ResultWithStatus<OcptScreenplayImportStatus, OcptImportedFountainModel>>
  pickAndReadScreenplay({required String fileTypeLabel}) async {
    lastFileTypeLabel = fileTypeLabel;

    final result = importResult;
    if (result == null) {
      return ResultWithStatus(status: importStatus);
    }

    return ResultWithStatus(status: OcptScreenplayImportStatus.ok, value: result);
  }
}

/// A projects manager whose [newProjectsDirectory] resolves to a fixed [directory] instead of
/// asking `path_provider` for the platform's real Downloads folder — `path_provider`'s desktop
/// implementations need the plugin-registrant plumbing a plain `flutter test` run doesn't reliably
/// provide, exactly the kind of pitfall `AGENTS.md`'s own "flutter test runs on the plain Dart VM"
/// note already flags elsewhere. This is what lets `OcptHomeBloc._onCreateProjectRequested`'s own
/// [OcptProjectsManager.freeNewProjectFilePath] call be exercised for real in these tests.
class TestProjectsManager extends OcptProjectsManager {
  /// The directory [newProjectsDirectory] and [suggestedProjectsDirectory] always resolve to.
  final Directory directory;

  /// Class constructor
  TestProjectsManager({required this.directory, super.propertiesManager, super.appLanguageCode});

  /// Answer with the directory the test gave.
  @override
  Future<Directory> newProjectsDirectory() async => directory;

  /// Overridden for the very same reason [newProjectsDirectory] is: the real
  /// [OcptProjectsManager.suggestedProjectsDirectory] falls back to
  /// [OcptProjectsManager.getDefaultProjectsDirectory], which asks `path_provider` for the
  /// platform's real documents directory the moment nothing has been remembered yet — exactly what
  /// a plain `flutter test` run cannot answer.
  @override
  Future<String> suggestedProjectsDirectory() async => directory.path;
}

/// A save location service answering [saveLocationAnswer]/[directoryAnswer] without ever showing a
/// native dialog, and recording that either was asked — used to exercise a project card's own
/// `Export…`, and a project package import's own destination folder picker, without a real dialog.
///
/// A null answer is the user cancelling the dialog, which every import/export of this app treats
/// as a silent no-op.
class RecordingSaveLocationService extends OcptSaveLocationService {
  /// The path [pickSaveLocation] hands back, or null to answer as a cancelled dialog.
  final String? saveLocationAnswer;

  /// The path [pickDirectory] hands back, or null to answer as a cancelled dialog.
  final String? directoryAnswer;

  /// How many times a save location was asked for.
  int askCount = 0;

  /// The [pickDirectory] confirm button text of the last call, or null if it was never called.
  String? lastDirectoryConfirmButtonText;

  /// The suggested file name of the last [pickSaveLocation] call, or null if it was never called.
  String? lastSuggestedFileName;

  /// The `initialDirectory` of the last [pickSaveLocation] call, or null if it was never called or
  /// none was passed.
  String? lastInitialDirectory;

  /// Class constructor
  RecordingSaveLocationService({this.saveLocationAnswer, this.directoryAnswer})
    : super(logger: const SilentLogger());

  /// Count the question, remember the suggested name and the initial directory, and answer with the
  /// canned location.
  @override
  Future<String?> pickSaveLocation({
    required String suggestedFileName,
    required String fileTypeLabel,
    required List<String> extensions,
    String? initialDirectory,
  }) async {
    askCount++;
    lastSuggestedFileName = suggestedFileName;
    lastInitialDirectory = initialDirectory;
    return saveLocationAnswer;
  }

  /// Remember the confirm button text, and answer with the canned directory.
  @override
  Future<String?> pickDirectory({
    required String confirmButtonText,
    String? initialDirectory,
  }) async {
    lastDirectoryConfirmButtonText = confirmButtonText;
    return directoryAnswer;
  }
}

/// A router manager whose [push] only records the route pushed: these bloc tests don't build a
/// real GoRouter for it to operate on.
class RecordingRouterManager extends OcptRouterManager {
  /// Runs while [push] is awaited, standing in for whatever the user did in the workspace before
  /// popping back to the home page — a real push only completes once they leave it.
  final Future<void> Function()? whilePushed;

  /// The last route [push] was called with, or null if it never was.
  OcptRoute? pushedRoute;

  /// Class constructor
  RecordingRouterManager({this.whilePushed});

  /// Record the route, wait for the hook while it is pushed, and answer with nothing.
  @override
  Future<Y?> push<Y extends Object?>(
    OcptRoute route, {
    Map<String, String> pathParameters = const <String, String>{},
    Map<String, dynamic> queryParameters = const <String, dynamic>{},
    Object? extra,
  }) async {
    pushedRoute = route;
    await whilePushed?.call();
    return null;
  }
}
