// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <benoit.rolandeau@allcircuits.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_dart_result/act_dart_result.dart';

/// The outcome of a `OcptProjectsManager` operation that creates or opens a project.
///
/// {@template open_cine_prod_tools.OcptProjectStatus}
/// This is used as the [ResultWithStatus] status of `OcptProjectsManager.createProject` and
/// `OcptProjectsManager.openProject`.
/// {@endtemplate}
enum OcptProjectStatus with MixinResultStatus {
  /// The operation succeeded: the project is now the current one.
  ok(isSuccess: true, canBeRetried: false),

  /// The project file doesn't exist at the given path.
  fileNotFound(isSuccess: false, canBeRetried: false),

  /// The project file exists but isn't a valid Open Cine Prod Tools project database.
  corruptedFile(isSuccess: false, canBeRetried: false),

  /// Another create/open/close operation is already in progress on this manager.
  alreadyOpen(isSuccess: false, canBeRetried: true),

  /// A filesystem or database error occurred while creating/opening the project.
  ioError(isSuccess: false, canBeRetried: true);

  /// {@macro act_dart_result.MixinResultStatus.isSuccess}
  @override
  final bool isSuccess;

  /// {@macro act_dart_result.MixinResultStatus.canBeRetried}
  @override
  final bool canBeRetried;

  /// Class constructor
  const OcptProjectStatus({required this.isSuccess, required this.canBeRetried});
}
