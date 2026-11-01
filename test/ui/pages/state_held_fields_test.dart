// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_package_notice.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_package_target.dart';
import 'package:open_cine_prod_tools/types/ocpt_person_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_package_notice_kind.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_state.dart';
import 'package:open_cine_prod_tools/ui/pages/joining/joining_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_people_state.dart';

/// The data a bloc used to keep in a field of its own now sits in its state: each of these moves
/// the way the field did, and enters the state's equality.
void main() {
  group("OcptEditorState", () {
    test("each scene jump request takes the next id, even for the same offset", () {
      final first = const OcptEditorState.init().copyWithSceneJumpRequested(charOffset: 12);
      final second = first.copyWithSceneJumpRequested(charOffset: 12);

      expect(first.jumpRequest?.id, 0);
      expect(second.jumpRequest?.id, 1);
      expect(second.jumpRequest?.charOffset, 12);
      expect(second, isNot(first));
      expect(second.selectionEpoch, first.selectionEpoch + 1);
    });
  });

  group("OcptJoiningState", () {
    test("a cancelled join differs from an idle one, and a new join clears the flag", () {
      const started = OcptJoiningState.init();
      final cancelled = started.copyWithJoinStarted().copyToCancelled();

      expect(cancelled.isCancelled, isTrue);
      expect(cancelled.isJoining, isFalse);
      expect(cancelled, isNot(started.copyWithJoinStarted().copyToIdle()));
      expect(cancelled.copyWithJoinStarted().isCancelled, isFalse);
    });
  });

  group("a view state's lost edits epoch", () {
    test("starts where it is given, and moves with the edits it drops", () {
      const initial = OcptResourcesPeopleState.init(lastLostEditsEpoch: 3);
      final typed = initial.copyWithFieldEditTyped(
        pendingFieldEdits: {("p", OcptPersonField.firstName): "x"},
      );
      final lost = typed.copyWithFieldEditsLost(lostEditsEpoch: 4);

      expect(initial.lastLostEditsEpoch, 3);
      expect(lost.lastLostEditsEpoch, 4);
      expect(lost.pendingFieldEdits, isEmpty);
      expect(lost, isNot(initial));
      expect(initial.copyWithFieldEditsLost(lostEditsEpoch: 4), isNot(initial));
    });
  });

  group("the pending project package export target", () {
    const target = OcptProjectPackageTarget(filePath: "/tmp/a.ocpt", name: "A");

    test("is consumed by the confirmation and by a notice, but not by a dismissal", () {
      final asked = const OcptEditorState.init().copyProjectPackageState(
        projectPackagePendingExportTarget: target,
      );

      expect(asked.projectPackagePendingExportTarget, target);
      expect(asked.copyWithPackagePreflightDismissed().projectPackagePendingExportTarget, target);
      expect(asked.copyWithPackageExportTargetConsumed().projectPackagePendingExportTarget, isNull);
      expect(
        asked
            .copyWithPackageNoticed(
              notice: const OcptProjectPackageNotice(
                kind: OcptProjectPackageNoticeKind.exportFailed,
              ),
            )
            .projectPackagePendingExportTarget,
        isNull,
      );
      expect(asked, isNot(asked.copyWithPackageExportTargetConsumed()));
    });
  });
}
