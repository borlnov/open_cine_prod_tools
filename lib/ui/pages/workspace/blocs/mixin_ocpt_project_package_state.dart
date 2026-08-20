// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_package_notice.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_package_report.dart';

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

  /// {@template open_cine_prod_tools.MixinOcptProjectPackageState.copyProjectPackageState}
  /// This is the copyWith method for the mixin.
  ///
  /// Both fields legitimately go back to null while the mode is alive (a question answered, a
  /// notice dismissed), so each carries its own clear flag rather than relying on "a null argument
  /// means unchanged".
  /// {@endtemplate}
  S copyProjectPackageState({
    OcptProjectPackagePreflight? projectPackagePendingExport,
    bool clearProjectPackagePendingExport = false,
    OcptProjectPackageNotice? projectPackageNotice,
    bool clearProjectPackageNotice = false,
  });

  /// {@macro act_flutter_utility.BlocStateForMixin.props}
  @override
  List<Object?> get props => [...super.props, projectPackagePendingExport, projectPackageNotice];
}
