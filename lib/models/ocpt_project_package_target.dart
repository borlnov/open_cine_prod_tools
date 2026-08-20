// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';

/// The project a portable package export is about: its file path and its display name.
///
/// It exists because the export itself works from a file path and never from an open database
/// (`OcptProjectPackageService`) — which is exactly what lets a project card on the home page
/// export a project nothing has opened, the same way a mode's toolbar exports the one that is.
/// `MixinOcptProjectPackageBloc` resolves this once per request: the caller's own
/// [OcptProjectPackageTarget], or the project currently open when none was given.
class OcptProjectPackageTarget extends Equatable {
  /// The absolute path to the project file on disk.
  final String filePath;

  /// The project's display name, used to name the package's suggested file name.
  final String name;

  /// Class constructor
  const OcptProjectPackageTarget({required this.filePath, required this.name});

  /// Object properties
  @override
  List<Object?> get props => [filePath, name];
}
