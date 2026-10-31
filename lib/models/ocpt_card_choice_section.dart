// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/ocpt_card_choice_entry.dart';

/// One titled group of cards inside `OcptCardChoiceDialog<T>`.
///
/// A dialog offering one kind of thing holds a single section with no [heading]; one offering two
/// kinds — the export panel's documents and the project itself — holds a section each, drawn one
/// under the other behind a divider. Sections exist so that a group which is *not* the same kind of
/// thing as the one above it can say so, rather than being dropped into the same grid and read as
/// one more of them.
class OcptCardChoiceSection<T> extends Equatable {
  /// The short heading naming what this group is, or null when the dialog offers a single group
  /// and its own message already said it.
  final String? heading;

  /// The cards of this group, in the given order.
  final List<OcptCardChoiceEntry<T>> entries;

  /// Class constructor
  const OcptCardChoiceSection({required this.entries, this.heading});

  /// Object properties
  @override
  List<Object?> get props => [heading, entries];
}
