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
/// This first shows a save-file dialog to let the user pick where to save the new project, then
/// creates it and navigates to the editor.
class OcptHomeCreateProjectRequestedEvent extends OcptHomeEvent {
  /// The name entered by the user for the new project.
  final String name;

  /// Class constructor
  const OcptHomeCreateProjectRequestedEvent({required this.name});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, name];
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

/// Requests creating a new project seeded with the content of a picked `.fountain` file.
///
/// This shows an open-file dialog to pick the `.fountain` file, then a save-file dialog to let
/// the user pick where to save the new project, creates it, imports the picked file's text into
/// it, and navigates to the editor.
class OcptHomeImportScreenplayRequestedEvent extends OcptHomeEvent {
  /// The label of the `.fountain` file type shown in the native open-file dialog.
  final String fountainFileTypeLabel;

  /// Class constructor
  const OcptHomeImportScreenplayRequestedEvent({required this.fountainFileTypeLabel});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, fountainFileTypeLabel];
}
