// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';

/// The events handled by `MixinOcptProjectPackageBloc`, i.e. by every production mode's bloc.
///
/// They extend [BlocEventForMixin] directly rather than joining a mode's own sealed event
/// hierarchy, exactly as the project versions' own events do: what they act on is the project, and
/// the mode is only where the user happened to ask from.

/// Requests writing the open project out as a portable package.
///
/// What the `Export` panel's standing project card dispatches. The handler scans the referenced
/// files first: everything being there, it goes straight to the save dialog; anything missing, it
/// asks through the state instead and waits for [OcptProjectPackageExportConfirmedEvent].
///
/// [fileTypeLabel] is the native save dialog's own type filter label, resolved by the mode — the
/// last place holding a `Tr` before this reaches the manager layer.
class OcptProjectPackageExportRequestedEvent extends BlocEventForMixin {
  /// The label of the save dialog's type filter.
  final String fileTypeLabel;

  /// Class constructor
  const OcptProjectPackageExportRequestedEvent({required this.fileTypeLabel});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, fileTypeLabel];
}

/// Reports that the mode has opened the question about the missing files, which clears it from the
/// state.
///
/// The one-shot state field is consumed the moment it has been acted on, exactly as every transient
/// notice of this app is: the question is a modal dialog the user still has in front of them, and a
/// later state emission must not open a second one behind it.
class OcptProjectPackageMissingFilesAskDismissedEvent extends BlocEventForMixin {
  /// Class constructor
  const OcptProjectPackageMissingFilesAskDismissedEvent();
}

/// Reports that the user answered the missing-files question by asking for the package anyway.
///
/// Carries [fileTypeLabel] again rather than having the handler remember what the request event
/// brought: the mode resolves it from the very context it just showed the dialog in, and a bloc
/// holding a resolved string across a user's think time would be holding a word from a locale that
/// may have changed under it.
class OcptProjectPackageExportConfirmedEvent extends BlocEventForMixin {
  /// The label of the save dialog's type filter.
  final String fileTypeLabel;

  /// Class constructor
  const OcptProjectPackageExportConfirmedEvent({required this.fileTypeLabel});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, fileTypeLabel];
}

/// Clears the transient project package notice currently shown, if any.
class OcptProjectPackageNoticeDismissedEvent extends BlocEventForMixin {
  /// Class constructor
  const OcptProjectPackageNoticeDismissedEvent();
}
