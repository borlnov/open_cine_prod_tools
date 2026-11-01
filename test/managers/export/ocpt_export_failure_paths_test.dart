// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';
import 'dart:typed_data';

import 'package:act_platform_manager/act_platform_manager.dart';
import 'package:act_test_utility/act_test_utility.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_export_write_service.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_save_location_service.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_share_service.dart';
import 'package:path/path.dart' as p;
import 'ocpt_export_manager_test_doubles.dart';

/// A [PlatformManager] whose [isMobile] is stubbed.
class _StubPlatformManager extends PlatformManager {
  /// Whether this double stands for a mobile platform.
  @override
  final bool isMobile;

  /// Class constructor
  _StubPlatformManager({required this.isMobile});
}

/// A share service whose temporary directory cannot be resolved.
class _ThrowingShareService extends OcptShareService {
  /// Class constructor
  const _ThrowingShareService() : super(logger: const SilentLogger());

  /// Fail as a platform with no temporary directory does.
  @override
  Future<Directory> temporaryDirectory() async => throw const FileSystemException("no directory");
}

/// The soft failures of the export funnel: each is logged and answered as a null outcome (or
/// false) rather than thrown.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  final bytes = Uint8List.fromList([1, 2, 3]);

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync("ocpt_export_failures_");
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  OcptExportWriteService serviceOf({
    required bool isMobile,
    OcptSaveLocationService? saveLocation,
    OcptShareService? share,
  }) => OcptExportWriteService(
    logger: const SilentLogger(),
    saveLocationService: saveLocation ?? FakeSaveLocationService(),
    shareService: share ?? const OcptShareService(logger: SilentLogger()),
    platformManager: _StubPlatformManager(isMobile: isMobile),
  );

  test("a desktop write into a missing folder is answered as a null outcome", () async {
    final missing = p.join(tempDir.path, "missing", "export.pdf");
    final service = serviceOf(
      isMobile: false,
      saveLocation: FakeSaveLocationService(result: missing),
    );

    final outcome = await service.writeToPickedLocation(
      suggestedFileName: "export.pdf",
      fileTypeLabel: "PDF",
      extensions: const ["pdf"],
      bytes: bytes,
    );

    expect(outcome, isNull);
  });

  test("a share whose temporary directory fails is answered as a null outcome", () async {
    final service = serviceOf(isMobile: true, share: const _ThrowingShareService());

    final outcome = await service.shareBytes(fileName: "export.pdf", bytes: bytes);

    expect(outcome, isNull);
  });

  test("a folder write into a missing folder is answered as false", () async {
    final service = serviceOf(isMobile: false);

    final isWritten = await service.writeBytesInFolder(
      folderPath: p.join(tempDir.path, "missing"),
      fileName: "sheet.pdf",
      bytes: bytes,
    );

    expect(isWritten, isFalse);
  });

  test("a save dialog that cannot be shown is answered as null", () async {
    const service = OcptSaveLocationService(logger: SilentLogger());

    final path = await service.pickSaveLocation(
      suggestedFileName: "export.pdf",
      fileTypeLabel: "PDF",
      extensions: const ["pdf"],
    );

    expect(path, isNull);
  });

  test("a folder dialog that cannot be shown is answered as null", () async {
    const service = OcptSaveLocationService(logger: SilentLogger());

    final path = await service.pickDirectory(confirmButtonText: "Choose");

    expect(path, isNull);
  });

  test("a share sheet that cannot be shown is answered as false", () async {
    const service = OcptShareService(logger: SilentLogger());

    final isShown = await service.shareFiles(paths: [p.join(tempDir.path, "a.pdf")]);

    expect(isShown, isFalse);
  });
}
