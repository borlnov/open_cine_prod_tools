// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';

/// One card of `OcptWorkspaceExportDialog<T>`: the descriptor of a single document a mode knows
/// how to print, generic over that mode's own export enum.
///
/// `OcptWorkspaceExportDialog` builds no word of its own — the mode resolves every string of it,
/// exactly as `OcptShotListXlsxLabels` and `OcptScenarioCoverageLabels` already do for the manager
/// layer's services, which is why this carries no `Tr`. [title] is the document's own **name**
/// (`Feuilles de service`), never a sentence of action (`Exporter les feuilles de service…`): the
/// card already says what clicking it does by being a card in this panel.
///
/// [formatLabel] (`PDF`, `XLSX`, `.fountain`) deliberately does not come from the ARB files
/// either — a format's name reads the same in both languages, and a key for it would only ever be
/// translated to itself.
class OcptWorkspaceExportEntry<T> extends Equatable {
  /// The value `OcptWorkspaceExportDialog.show` pops when this card is picked.
  final T value;

  /// The document's own name.
  final String title;

  /// A line saying what the document is, shown under [title] — replaced by [unavailableReason]
  /// when the card is unavailable.
  final String description;

  /// The document's format, shown as a trailing label rather than a second target.
  final String formatLabel;

  /// Why this document cannot be printed right now, or null while it can.
  ///
  /// A non-null reason renders the card greyed and inert, its [description] replaced by this
  /// sentence — the card is never hidden, since a card that disappeared would make the panel lie
  /// about what this mode knows how to print.
  final String? unavailableReason;

  /// Class constructor
  const OcptWorkspaceExportEntry({
    required this.value,
    required this.title,
    required this.description,
    required this.formatLabel,
    this.unavailableReason,
  });

  /// Whether this document can be printed right now.
  bool get isAvailable => unavailableReason == null;

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() => "OcptWorkspaceExportEntry(title: $title, isAvailable: $isAvailable)";

  /// Object properties
  @override
  List<Object?> get props => [value, title, description, formatLabel, unavailableReason];
}
