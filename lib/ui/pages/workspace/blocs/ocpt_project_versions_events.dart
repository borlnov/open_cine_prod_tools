// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';

/// The events handled by `MixinOcptProjectVersionsBloc`, i.e. by every production mode's bloc.
///
/// They extend [BlocEventForMixin] directly rather than joining a mode's own sealed event
/// hierarchy: the very point of the mixin is that the `Versions` dock tab dispatches the same
/// events whichever mode it is shown in.

/// Requests (re)loading the current project's version list into the state.
///
/// Dispatched by the mixin itself whenever the list may have changed — on entry, after a version
/// is created or deleted, and after entering or leaving a preview — so a mode never has to
/// remember to refresh it.
class OcptProjectVersionsRefreshRequestedEvent extends BlocEventForMixin {
  /// Class constructor
  const OcptProjectVersionsRefreshRequestedEvent();
}

/// Requests capturing the current project as a new version, named [name] and described by [note].
///
/// [name] and [note] come from the create dialog, which is where they are validated: the handler
/// takes them as given.
class OcptProjectVersionCreationRequestedEvent extends BlocEventForMixin {
  /// The user-facing name of the version to create.
  final String name;

  /// The user's free-text description of the version, empty when they wrote none.
  final String note;

  /// Class constructor
  const OcptProjectVersionCreationRequestedEvent({required this.name, required this.note});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, name, note];
}

/// Reports that the user clicked `Delete` on the card of the version [versionId], which shows that
/// card's inline confirmation rather than deleting anything.
class OcptProjectVersionDeletionRequestedEvent extends BlocEventForMixin {
  /// The id of the version whose deletion is being confirmed.
  final String versionId;

  /// Class constructor
  const OcptProjectVersionDeletionRequestedEvent({required this.versionId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, versionId];
}

/// Reports that the user cancelled the inline delete confirmation currently shown.
class OcptProjectVersionDeletionCancelledEvent extends BlocEventForMixin {
  /// Class constructor
  const OcptProjectVersionDeletionCancelledEvent();
}

/// Requests the permanent deletion of the version [versionId], confirmed inline in its card.
class OcptProjectVersionDeletionConfirmedEvent extends BlocEventForMixin {
  /// The id of the version to delete.
  final String versionId;

  /// Class constructor
  const OcptProjectVersionDeletionConfirmedEvent({required this.versionId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, versionId];
}

/// Requests entering the read-only preview of the version [versionId].
class OcptProjectVersionPreviewRequestedEvent extends BlocEventForMixin {
  /// The id of the version to preview.
  final String versionId;

  /// Class constructor
  const OcptProjectVersionPreviewRequestedEvent({required this.versionId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, versionId];
}

/// Requests leaving the read-only preview, putting the working copy back on screen.
class OcptProjectVersionPreviewExitRequestedEvent extends BlocEventForMixin {
  /// Class constructor
  const OcptProjectVersionPreviewExitRequestedEvent();
}

/// Clears the transient version notice currently shown, once the page has displayed it.
class OcptProjectVersionNoticeDismissedEvent extends BlocEventForMixin {
  /// Class constructor
  const OcptProjectVersionNoticeDismissedEvent();
}
