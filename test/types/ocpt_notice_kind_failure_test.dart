// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_package_notice_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_version_notice_kind.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_io_notice_kind.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_io_notice_kind.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_io_notice_kind.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_io_notice_kind.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_io_notice_kind.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_io_notice_kind.dart';

/// Guard the outcome each notice kind reports: the values that report a failure are listed, and
/// every other value must report a success.
void main() {
  test("the editor notice kinds", () {
    const failures = {
      OcptEditorIoNoticeKind.exportFailed,
      OcptEditorIoNoticeKind.importFailed,
      OcptEditorIoNoticeKind.importUnreadable,
      OcptEditorIoNoticeKind.pdfExportFailed,
    };
    for (final kind in OcptEditorIoNoticeKind.values) {
      expect(kind.isFailure, failures.contains(kind), reason: "$kind");
    }
  });

  test("the breakdown notice kinds", () {
    const failures = {
      OcptBreakdownIoNoticeKind.sheetsExportFailed,
      OcptBreakdownIoNoticeKind.xlsxExportFailed,
    };
    for (final kind in OcptBreakdownIoNoticeKind.values) {
      expect(kind.isFailure, failures.contains(kind), reason: "$kind");
    }
  });

  test("the budget notice kinds", () {
    for (final kind in OcptBudgetIoNoticeKind.values) {
      expect(kind.isFailure, kind == OcptBudgetIoNoticeKind.exportFailed, reason: "$kind");
    }
  });

  test("the resources notice kinds", () {
    const failures = {
      OcptResourcesIoNoticeKind.xlsxExportFailed,
      OcptResourcesIoNoticeKind.contactListExportFailed,
    };
    for (final kind in OcptResourcesIoNoticeKind.values) {
      expect(kind.isFailure, failures.contains(kind), reason: "$kind");
    }
  });

  test("the schedule notice kinds", () {
    const failures = {
      OcptScheduleIoNoticeKind.exportFailed,
      OcptScheduleIoNoticeKind.folderExportPartiallySucceeded,
    };
    for (final kind in OcptScheduleIoNoticeKind.values) {
      expect(kind.isFailure, failures.contains(kind), reason: "$kind");
    }
  });

  test("the shot list notice kinds", () {
    const failures = {
      OcptShotListIoNoticeKind.xlsxExportFailed,
      OcptShotListIoNoticeKind.scenarioCoverageExportFailed,
      OcptShotListIoNoticeKind.storyboardExportFailed,
      OcptShotListIoNoticeKind.floorPlansExportFailed,
    };
    for (final kind in OcptShotListIoNoticeKind.values) {
      expect(kind.isFailure, failures.contains(kind), reason: "$kind");
    }
  });

  test("the project package notice kinds", () {
    for (final kind in OcptProjectPackageNoticeKind.values) {
      expect(kind.isFailure, kind == OcptProjectPackageNoticeKind.exportFailed, reason: "$kind");
    }
  });

  test("every project version notice kind is a failure", () {
    for (final kind in OcptProjectVersionNoticeKind.values) {
      expect(kind.isFailure, isTrue, reason: "$kind");
    }
  });
}
