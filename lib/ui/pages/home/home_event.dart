// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';

/// The events handled by `OcptHomeBloc`.
sealed class OcptHomeEvent extends BlocEventForMixin {
  /// Class constructor
  const OcptHomeEvent();
}

/// Requests a refresh of the recent projects list from the properties manager, recomputing
/// whether each project's file still exists on disk.
class OcptHomeRefreshRequestedEvent extends OcptHomeEvent {
  /// Class constructor
  const OcptHomeRefreshRequestedEvent();
}

/// Requests the creation of a new project named [name].
///
/// On desktop this shows the native save-file dialog first, suggesting `<name>.ocpt` inside
/// `OcptProjectsManager.suggestedProjectsDirectory` — the last folder a save dialog landed in, or
/// the default projects folder the very first time — and the project is only ever created at the
/// path the user actually picked; cancelling the dialog creates nothing. On mobile, where there is
/// no such dialog (`file_selector`'s `getSaveLocation` has no Android/iOS implementation), a free
/// file path is resolved with no dialog at all, exactly as before. Either way, the project is
/// created and the app navigates to the editor once it is.
class OcptHomeCreateProjectRequestedEvent extends OcptHomeEvent {
  /// The name entered by the user for the new project — kept as the project's own name whichever
  /// file name the desktop save dialog is actually given (the dialog only ever renames the file, not
  /// the project).
  final String name;

  /// The label of the project file type shown in the desktop save-file dialog.
  final String fileTypeLabel;

  /// Class constructor
  const OcptHomeCreateProjectRequestedEvent({required this.name, required this.fileTypeLabel});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, name, fileTypeLabel];
}

/// Requests opening a project, then navigating to the editor.
///
/// If [filePath] is null, an open-file dialog filtered to project files is shown first to let the
/// user pick one (the "Open…" action); otherwise [filePath] is opened directly, without a dialog
/// (a recent project card was tapped).
///
/// Whichever way the file was named, its own format is read before it is opened: a file from
/// another build stops here and is stated through the page's state rather than opened.
class OcptHomeOpenProjectRequestedEvent extends OcptHomeEvent {
  /// The path of the project to open, or null to let the user pick one from a dialog.
  final String? filePath;

  /// The label of the file type shown in the open-file dialog, localized by the caller.
  final String fileTypeLabel;

  /// Whether the user has answered for the migration of a file at an older format, and so wants it
  /// brought up to date — a copy of it being kept on the way.
  ///
  /// False for every open the user starts, true only for the one the page dispatches back after
  /// they confirmed the question `pendingFileCompatibility` raised. The default is what makes an
  /// unanswered file stop rather than migrate.
  final bool allowMigration;

  /// Class constructor
  const OcptHomeOpenProjectRequestedEvent({
    this.filePath,
    required this.fileTypeLabel,
    this.allowMigration = false,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, filePath, fileTypeLabel, allowMigration];
}

/// Requests opening the project at [filePath], then navigating to its Partager screen
/// (`OcptRoute.sharing`) instead of the workspace.
///
/// Raised by a project card's own "Partager / Synchroniser…" overflow menu action: [filePath]
/// always names an existing entry there, so there is no dialog to show first, unlike
/// [OcptHomeOpenProjectRequestedEvent].
class OcptHomeShareProjectRequestedEvent extends OcptHomeEvent {
  /// The path of the project to open before navigating to its Partager screen.
  final String filePath;

  /// Class constructor
  const OcptHomeShareProjectRequestedEvent({required this.filePath});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, filePath];
}

/// Requests navigating to the "Rejoindre un projet partagé" screen (`OcptRoute.joining`).
///
/// Raised by the home page toolbar's own "Join a shared project…" action. Unlike
/// [OcptHomeShareProjectRequestedEvent], this opens no project first — joining is how a project
/// comes to exist on this replica in the first place.
class OcptHomeJoinSharedProjectRequestedEvent extends OcptHomeEvent {
  /// Class constructor
  const OcptHomeJoinSharedProjectRequestedEvent();
}

/// Reports that the home page has stated what the probe found about a project file, which clears
/// it from the state.
///
/// The one-shot field is consumed the moment it has been acted on, exactly as every transient
/// question of this app is: the user still has that dialog in front of them, and a later state
/// emission must not open a second one behind it.
class OcptHomeFileCompatibilityStatedEvent extends OcptHomeEvent {
  /// Class constructor
  const OcptHomeFileCompatibilityStatedEvent();
}

/// Requests removing the recent project at [path] from the recent projects list.
class OcptHomeRemoveRecentProjectRequestedEvent extends OcptHomeEvent {
  /// The path of the recent project to remove.
  final String path;

  /// Class constructor
  const OcptHomeRemoveRecentProjectRequestedEvent({required this.path});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, path];
}

/// Dismisses the transient error currently shown, if any.
class OcptHomeErrorDismissedEvent extends OcptHomeEvent {
  /// Class constructor
  const OcptHomeErrorDismissedEvent();
}

/// Requests creating a new project seeded with the content of a picked screenplay file.
///
/// This shows an open-file dialog to pick the screenplay — a `.fountain`, an `.fdx` or a
/// `.celtx`, the last two being converted to Fountain as they are read. On desktop, a save-file
/// dialog then lets the user pick where the new project itself lands (mirroring
/// [OcptHomeCreateProjectRequestedEvent]'s own dialog, suggested inside
/// `OcptProjectsManager.suggestedProjectsDirectory`), and the project's own name is taken from
/// whichever file name the user actually saved it under; cancelling either dialog creates nothing.
/// On mobile, where there is no save dialog, a free file path is resolved with no dialog at all and
/// the project is named after the picked screenplay, exactly as before. Either way, the picked
/// file's text is imported into the fresh project, and the app navigates to the editor.
///
/// A picked file that cannot be read as a screenplay creates nothing at all: it lands in
/// `OcptHomeState.screenplayImportError` for the page to word, no project ever being created for
/// it.
class OcptHomeImportScreenplayRequestedEvent extends OcptHomeEvent {
  /// The label of the screenplay file types shown in the native open-file dialog.
  final String screenplayFileTypeLabel;

  /// The label of the project file type shown in the desktop save-file dialog.
  final String projectFileTypeLabel;

  /// Class constructor
  const OcptHomeImportScreenplayRequestedEvent({
    required this.screenplayFileTypeLabel,
    required this.projectFileTypeLabel,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, screenplayFileTypeLabel, projectFileTypeLabel];
}

/// Dismisses the transient screenplay import error currently shown, if any.
class OcptHomeScreenplayImportErrorDismissedEvent extends OcptHomeEvent {
  /// Class constructor
  const OcptHomeScreenplayImportErrorDismissedEvent();
}

/// Requests unpacking a picked portable project package (`.ocptz`) into a project of its own.
///
/// Picks the package through an open-file dialog, then a **parent folder** to create
/// `<project name>/` inside — never a single file, since a package unpacks into a folder holding
/// the `.ocpt` and its `assets/`. It does not open the project it unpacks, and does not navigate
/// anywhere: the outcome lands in the state, either
/// `OcptHomeState.projectPackageImportError` (a status the page words) or
/// `OcptHomeState.projectPackageImportReport` (for the page to state the skipped files, if any,
/// then dispatch [OcptHomeOpenProjectRequestedEvent] itself) — the same compatibility gate every
/// other door into a project file goes through, rather than a silent migration.
class OcptHomeImportProjectPackageRequestedEvent extends OcptHomeEvent {
  /// The label of the `.ocptz` file type shown in the native open-file dialog.
  final String packageFileTypeLabel;

  /// The label of the native folder picker's own confirm button, shown when picking the
  /// destination's parent folder.
  final String destinationConfirmButtonText;

  /// Class constructor
  const OcptHomeImportProjectPackageRequestedEvent({
    required this.packageFileTypeLabel,
    required this.destinationConfirmButtonText,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, packageFileTypeLabel, destinationConfirmButtonText];
}

/// Dismisses the transient project package import error currently shown, if any.
class OcptHomeProjectPackageImportErrorDismissedEvent extends OcptHomeEvent {
  /// Class constructor
  const OcptHomeProjectPackageImportErrorDismissedEvent();
}

/// Reports that the page has read the last project package import's report — the one-shot field
/// the page consumes to state the skipped files (if any) and then open the project itself — which
/// clears it from the state.
class OcptHomeProjectPackageImportReportDismissedEvent extends OcptHomeEvent {
  /// Class constructor
  const OcptHomeProjectPackageImportReportDismissedEvent();
}
