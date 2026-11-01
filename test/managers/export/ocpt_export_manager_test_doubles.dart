// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_test_utility/act_test_utility.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_save_location_service.dart';

/// A save-location service whose [pickSaveLocation] is stubbed and whose calls are recorded, so
/// the manager's export methods can be exercised without any real native dialog.
class FakeSaveLocationService extends OcptSaveLocationService {
  /// Class constructor
  FakeSaveLocationService({this.result}) : super(logger: const SilentLogger());

  /// The path [pickSaveLocation] returns, or null to simulate a cancelled dialog.
  final String? result;

  /// The suggested file name of the last [pickSaveLocation] call.
  String? lastSuggestedFileName;

  /// The file type label of the last [pickSaveLocation] call.
  String? lastFileTypeLabel;

  /// The extensions of the last [pickSaveLocation] call.
  List<String>? lastExtensions;

  /// The path [pickDirectory] returns, or null to simulate a cancelled dialog — independent of
  /// [result], since the call sheet exports pick a folder rather than a file.
  String? directoryResult;

  /// The confirm-button label of the last [pickDirectory] call.
  String? lastConfirmButtonText;

  @override
  Future<String?> pickSaveLocation({
    required String suggestedFileName,
    required String fileTypeLabel,
    required List<String> extensions,
    String? initialDirectory,
  }) async {
    lastSuggestedFileName = suggestedFileName;
    lastFileTypeLabel = fileTypeLabel;
    lastExtensions = extensions;
    return result;
  }

  @override
  Future<String?> pickDirectory({
    required String confirmButtonText,
    String? initialDirectory,
  }) async {
    lastConfirmButtonText = confirmButtonText;
    return directoryResult;
  }
}
