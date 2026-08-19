// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';

/// What the toolbar's `Export` panel hands back, generic over the active mode's own export enum
/// [T]: one of that mode's documents, or the project itself.
///
/// Sealed rather than a nullable [T], because the panel offers one card the modes do not declare:
/// the project package sits in every mode's panel and is owned by the dialog itself, so five modes
/// cannot each let its wording, its position and its availability drift apart. A mode's own
/// `switch` on the pick is what turns that into one extra branch per call site rather than one
/// extra enum value per mode.
sealed class OcptWorkspaceExportPick<T> extends Equatable {
  /// Class constructor
  const OcptWorkspaceExportPick();
}

/// The user picked one of the active mode's own documents.
class OcptWorkspaceExportDocumentPick<T> extends OcptWorkspaceExportPick<T> {
  /// The document picked, as the mode's own export enum names it.
  final T document;

  /// Class constructor
  const OcptWorkspaceExportDocumentPick(this.document);

  /// Object properties
  @override
  List<Object?> get props => [document];
}

/// The user picked the project package: the whole project as one archive somebody can send.
///
/// It carries nothing — there is one project, and the panel knows which mode it was opened from
/// only to draw the documents above this card.
class OcptWorkspaceExportProjectPackagePick<T> extends OcptWorkspaceExportPick<T> {
  /// Class constructor
  const OcptWorkspaceExportProjectPackagePick();

  /// Object properties
  @override
  List<Object?> get props => const [];
}
