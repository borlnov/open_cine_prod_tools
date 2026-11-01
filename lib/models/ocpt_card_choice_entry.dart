// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';

/// One card of `OcptCardChoiceDialog<T>`: a single thing the dialog offers, generic over whatever
/// the caller wants back when it is picked.
///
/// `OcptCardChoiceDialog` builds no word of its own — the caller resolves every string of it, which
/// is why this carries no `Tr`. [title] is the offered thing's own **name** (`Call sheets`,
/// `A project`), never a sentence of action (`Export the call sheets…`): the card already says
/// what clicking it does by being a card in this dialog.
///
/// [formatLabel] (`PDF`, `XLSX`, `.fountain`, `.ocptz`) deliberately does not come from the ARB
/// files either — a format's name reads the same in both languages, and a key for it would only
/// ever be translated to itself.
class OcptCardChoiceEntry<T> extends Equatable {
  /// The value `OcptCardChoiceDialog.show` pops when this card is picked.
  final T value;

  /// The offered thing's own name.
  final String title;

  /// A line saying what it is, shown under [title] — replaced by [unavailableReason] when the card
  /// is unavailable.
  final String description;

  /// The format it comes out in, shown as a trailing label rather than a second target.
  final String formatLabel;

  /// Why this card cannot be picked right now, or null while it can.
  ///
  /// A non-null reason renders the card greyed and inert, its [description] replaced by this
  /// sentence — the card is never hidden, since a card that disappeared would make the dialog lie
  /// about what exists.
  final String? unavailableReason;

  /// Whether this card can be picked right now.
  bool get isAvailable => unavailableReason == null;

  /// Class constructor
  const OcptCardChoiceEntry({
    required this.value,
    required this.title,
    required this.description,
    required this.formatLabel,
    this.unavailableReason,
  });

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() => "OcptCardChoiceEntry(title: $title, isAvailable: $isAvailable)";

  /// Object properties
  @override
  List<Object?> get props => [value, title, description, formatLabel, unavailableReason];
}
