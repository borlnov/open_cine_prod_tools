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
class OcptHomeOpenProjectRequestedEvent extends OcptHomeEvent {
  /// The path of the project to open, or null to let the user pick one from a dialog.
  final String? filePath;

  /// The label of the file type shown in the open-file dialog, localized by the caller.
  final String fileTypeLabel;

  /// Class constructor
  const OcptHomeOpenProjectRequestedEvent({this.filePath, required this.fileTypeLabel});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, filePath, fileTypeLabel];
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
