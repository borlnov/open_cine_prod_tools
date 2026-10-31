// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:fountain_kit/src/layout/fountain_script_composer.dart';
import 'package:fountain_kit/src/layout/fountain_script_page.dart';

/// A whole screenplay laid out into printed pages by
/// [FountainScriptComposer.compose].
class FountainScriptLayout extends Equatable {
  /// Creates a [FountainScriptLayout].
  const FountainScriptLayout({required this.pages});

  /// The screenplay's pages, in reading order.
  final List<FountainScriptPage> pages;

  @override
  List<Object?> get props => [pages];

  @override
  String toString() => 'FountainScriptLayout(${pages.length} pages)';
}
