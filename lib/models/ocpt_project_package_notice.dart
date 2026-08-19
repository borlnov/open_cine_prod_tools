// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_package_notice_kind.dart';

/// What the last project package export has to say, and what it needs to say it with.
///
/// The mode reads this out of its own state and resolves it into a sentence through
/// `ocptProjectPackageNoticeMessage`, exactly as every other export outcome of this app is
/// reported: no bloc ever holds a `Tr`, so the numbers travel and the words are found at the end.
class OcptProjectPackageNotice extends Equatable {
  /// What happened.
  final OcptProjectPackageNoticeKind kind;

  /// Where the package was written, or null when nothing was.
  final String? path;

  /// How many referenced files could not travel because they were already gone.
  ///
  /// Reported again on success rather than only before the write: the user answered that question
  /// a moment ago, and the package they now hold is the one that answer produced.
  final int skippedAssetCount;

  /// Class constructor
  const OcptProjectPackageNotice({required this.kind, this.path, this.skippedAssetCount = 0});

  /// Object properties
  @override
  List<Object?> get props => [kind, path, skippedAssetCount];
}
