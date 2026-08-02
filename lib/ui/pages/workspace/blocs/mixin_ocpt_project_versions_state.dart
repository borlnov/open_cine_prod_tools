// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_version.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_version_notice_kind.dart';

/// The slice of a production mode's state the `Versions` dock tab reads, mixed into every mode's
/// own state.
///
/// A version covers the whole project rather than any one mode's data, so the panel is the same
/// widget in every dock and needs the same four fields wherever it is shown. Mixing them in (the
/// `MixinActThemesState` idiom) is what keeps the two — soon four — modes from each growing their
/// own copy of the same list, and what lets `OcptProjectVersionsPanel` be built from a state it
/// knows nothing else about.
mixin MixinOcptProjectVersionsState<S extends MixinOcptProjectVersionsState<S>>
    on BlocStateForMixin<S> {
  /// {@template open_cine_prod_tools.MixinOcptProjectVersionsState.projectVersions}
  /// The project's versions, newest first, as last read from the project file. Empty while nothing
  /// has been loaded yet, and in a project the user never created a version of.
  /// {@endtemplate}
  List<OcptProjectVersion> get projectVersions;

  /// {@template open_cine_prod_tools.MixinOcptProjectVersionsState.previewedVersionId}
  /// The id of the version currently being previewed read-only, or null while the working copy is
  /// on screen.
  ///
  /// Mirrors `OcptOpenProjectModel.previewedVersion`, which stays the source of truth: this is the
  /// copy of it a card is drawn from, refreshed whenever the mixin enters or leaves a preview.
  /// {@endtemplate}
  String? get previewedVersionId;

  /// {@template open_cine_prod_tools.MixinOcptProjectVersionsState.versionPendingDeletionId}
  /// The id of the version whose card currently shows its inline delete confirmation, or null
  /// while none does. At most one card confirms at a time.
  /// {@endtemplate}
  String? get versionPendingDeletionId;

  /// {@template open_cine_prod_tools.MixinOcptProjectVersionsState.projectVersionNotice}
  /// The outcome of the last version operation the user has to be told about, or null while there
  /// is nothing to report; shown as a transient SnackBar then dismissed.
  /// {@endtemplate}
  OcptProjectVersionNoticeKind? get projectVersionNotice;

  /// Whether a version is currently being previewed read-only.
  ///
  /// This is what every mode gates its editing affordances on: `OcptOpenProjectModel.isReadOnly` is
  /// the source of truth, and this is the copy of it the widgets are built from.
  bool get isPreviewingVersion => previewedVersionId != null;

  /// The version [previewedVersionId] names, or null while the working copy is on screen (or while
  /// the list hasn't caught up with a version that has just gone).
  ///
  /// Resolved from [projectVersions] rather than stored beside the id: the list already carries
  /// every version, the previewed one included, so a second copy could only ever disagree with it.
  OcptProjectVersion? get previewedVersion {
    final previewedVersionId = this.previewedVersionId;
    if (previewedVersionId == null) {
      return null;
    }

    for (final version in projectVersions) {
      if (version.id == previewedVersionId) {
        return version;
      }
    }

    return null;
  }

  /// {@template open_cine_prod_tools.MixinOcptProjectVersionsState.copyProjectVersionsState}
  /// This is the copyWith method for the mixin.
  ///
  /// The three nullable fields legitimately go back to null while the mode is alive (a preview
  /// left, a confirmation cancelled, a notice dismissed), so each carries its own clear flag
  /// rather than relying on "a null argument means unchanged".
  /// {@endtemplate}
  S copyProjectVersionsState({
    List<OcptProjectVersion>? projectVersions,
    String? previewedVersionId,
    bool clearPreviewedVersionId = false,
    String? versionPendingDeletionId,
    bool clearVersionPendingDeletionId = false,
    OcptProjectVersionNoticeKind? projectVersionNotice,
    bool clearProjectVersionNotice = false,
  });

  /// {@macro act_flutter_utility.BlocStateForMixin.props}
  @override
  List<Object?> get props => [
    ...super.props,
    projectVersions,
    previewedVersionId,
    versionPendingDeletionId,
    projectVersionNotice,
  ];
}
