// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_package_notice.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_package_report.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_package_target.dart';

/// The slice of a production mode's state the project package export needs, mixed into every
/// mode's own state.
///
/// A package is the whole project rather than any one mode's data, so the `Export` panel offers it
/// from every mode and each of them needs the same two fields to run it: the question to ask, and
/// the outcome to report. Mixing them in (the `MixinActThemesState` idiom, and the one
/// `MixinOcptProjectVersionsState` already follows) is what keeps five modes from each growing
/// their own copy of the same pair.
mixin MixinOcptProjectPackageState<S extends MixinOcptProjectPackageState<S>>
    on BlocStateForMixin<S> {
  /// {@template open_cine_prod_tools.MixinOcptProjectPackageState.projectPackagePendingExport}
  /// What the pre-flight found when it read the project's referenced files, while the mode still
  /// has to ask the user about it; null the rest of the time.
  ///
  /// Only ever set when something is actually missing — a project whose every file is where it
  /// should be is packaged without a question. It is a **one-shot** field: the mode opens the
  /// question and dispatches `OcptProjectPackageMissingFilesAskDismissedEvent` straight away, so
  /// the answer the user is about to give is the only thing left to wait for.
  /// {@endtemplate}
  OcptProjectPackagePreflight? get projectPackagePendingExport;

  /// {@template open_cine_prod_tools.MixinOcptProjectPackageState.projectPackageNotice}
  /// The outcome of the last package export the user has to be told about, or null while there is
  /// nothing to report; shown as a transient SnackBar then dismissed.
  /// {@endtemplate}
  OcptProjectPackageNotice? get projectPackageNotice;

  /// {@template open_cine_prod_tools.MixinOcptProjectPackageState.projectPackagePendingExportTarget}
  /// The target the pre-flight question is currently about, from the moment it found a missing
  /// file until `OcptProjectPackageExportConfirmedEvent` uses it — null the rest of the time.
  ///
  /// `OcptProjectPackageExportConfirmedEvent` deliberately does not carry the target again: the
  /// mode or the page resolves it from the very question it just showed, and holding a **resolved
  /// word** across that wait (the way the confirmed event still carries `fileTypeLabel` fresh,
  /// rather than reusing what the request brought) would be holding something that could have
  /// changed under it — a locale can flip mid-dialog, a save dialog's own label with it. A file
  /// path is not that: it is a fact about which project this export is for, settled the moment the
  /// question was raised, so remembering it here rather than re-resolving it is safe in a way
  /// re-resolving `fileTypeLabel` would not be.
  ///
  /// Cleared once the confirmation has read it (the question answered) and whenever a notice is
  /// reported — never by dismissing the question, which the mode or the page dispatches the instant
  /// the pending state is read, well before the user has actually answered the dialog it is about
  /// to open: clearing the target there would lose it before the confirmation ever gets to use it.
  /// {@endtemplate}
  OcptProjectPackageTarget? get projectPackagePendingExportTarget;

  /// {@template open_cine_prod_tools.MixinOcptProjectPackageState.copyProjectPackageState}
  /// This is the copyWith method for the mixin.
  ///
  /// Both fields legitimately go back to null while the mode is alive (a question answered, a
  /// notice dismissed), so each carries its own force flag rather than relying on "a null argument
  /// means unchanged".
  /// {@endtemplate}
  S copyProjectPackageState({
    OcptProjectPackagePreflight? projectPackagePendingExport,
    bool forceProjectPackagePendingExportValue = false,
    OcptProjectPackageNotice? projectPackageNotice,
    bool forceProjectPackageNoticeValue = false,
    OcptProjectPackageTarget? projectPackagePendingExportTarget,
    bool forceProjectPackagePendingExportTargetValue = false,
  });

  /// Copies the state with the pre-flight [preflight] to ask the user about, [target] being the
  /// export it is about.
  S copyWithPackagePreflightAsked({
    required OcptProjectPackagePreflight preflight,
    required OcptProjectPackageTarget target,
  }) => copyProjectPackageState(
    projectPackagePendingExport: preflight,
    projectPackagePendingExportTarget: target,
  );

  /// Copies the state with the pending pre-flight question dropped.
  S copyWithPackagePreflightDismissed() =>
      copyProjectPackageState(forceProjectPackagePendingExportValue: true);

  /// Copies the state with the pending export target consumed, the user having answered the
  /// question.
  S copyWithPackageExportTargetConsumed() =>
      copyProjectPackageState(forceProjectPackagePendingExportTargetValue: true);

  /// Copies the state with the package notice dismissed.
  S copyWithPackageNoticeDismissed() =>
      copyProjectPackageState(forceProjectPackageNoticeValue: true);

  /// Copies the state with [notice] as the outcome of the export, the pending question dropped.
  S copyWithPackageNoticed({required OcptProjectPackageNotice notice}) => copyProjectPackageState(
    projectPackageNotice: notice,
    forceProjectPackagePendingExportValue: true,
    forceProjectPackagePendingExportTargetValue: true,
  );

  /// {@macro act_flutter_utility.BlocStateForMixin.props}
  @override
  List<Object?> get props => [
    ...super.props,
    projectPackagePendingExport,
    projectPackageNotice,
    projectPackagePendingExportTarget,
  ];
}
