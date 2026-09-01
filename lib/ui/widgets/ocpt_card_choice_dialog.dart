// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_card_choice_entry.dart';
import 'package:open_cine_prod_tools/utils/ocpt_responsive.dart';

/// The width the grid lays its two columns out at, at an expanded width. Below
/// [ocptCompactWidthBreakpoint] the dialog drops to a single column and takes the width the screen
/// gives it instead, so its cards never sit cramped side by side (or overflow) on a phone.
const double _ocptCardChoiceGridWidth = 600;

/// The height the sections are bounded to together, so they scroll within the dialog rather than
/// growing it past the window whenever a caller offers many cards.
///
/// A ceiling rather than a size: a dialog offering one card opens one card tall, the content
/// shrink-wrapping whatever it holds until it reaches this.
const double _ocptCardChoiceMaxHeight = 420;

/// The fixed height one card is laid out at, tall enough for its title row (a name and a trailing
/// format label, both one line, [TextTheme.titleSmall] being the taller of the two) and its
/// description (or unavailability reason) over up to three lines of [TextTheme.bodySmall], with the
/// card's own 12px padding above and below and the 4px gap between the title row and the
/// description: at the dense scale's 12px titleSmall (Material's own 20/14 line height, so ≈17px)
/// and 11px bodySmall (Material's own 16/12 line height, so ≈15px per line, ≈44px for three), that
/// is 12 + 17 + 4 + 44 + 12 ≈ 89px — rounded up for a small margin so descenders never brush the
/// card's edge.
///
/// A fixed height rather than [GridView.count]'s `childAspectRatio`: the aspect ratio derives a
/// card's height from its *width*, so it silently stops fitting three lines the moment the grid
/// (or the dialog it sits in) is narrower than what it was tuned against — which is exactly how the
/// import dialog's cards ellipsized mid-sentence with no way to read the rest.
const double _ocptCardChoiceCardHeight = 96;

/// The opacity an unavailable card is drawn at, greying it without hiding it.
const double _ocptCardChoiceUnavailableOpacity = 0.5;

/// A dialog offering a handful of things as a grid of cards, generic over what the caller wants
/// back when one is picked.
///
/// The shape the app asks "which one of these?" in: the toolbar's `Export` panel
/// (`OcptWorkspaceExportDialog`, which flavours this for a mode's documents plus the project
/// itself) and the home page's `Import…` modal are the same dialog with different words, so a user
/// comparing the two gestures compares two lists laid out the same way.
///
/// It only asks: clicking an available card pops with its [OcptCardChoiceEntry.value] and nothing
/// else, through `OcptRouterManager.pop`, never `Navigator`. It knows nothing about what the caller
/// then does with the pick, which happens once this dialog is already on its way out of the tree.
///
/// A card whose [OcptCardChoiceEntry.unavailableReason] is non-null is greyed and inert, its
/// description replaced by that reason, and never hidden: the dialog is a presentation of what the
/// app knows how to produce, and a card that disappeared would make it lie about what exists.
///
/// A **section** holding no entries at all is a different case, and is dropped rather than drawn:
/// the budget mode at M1 opens this panel with its own documents section empty (it prints nothing
/// yet) and only the project package section to show, and a section with nothing in it draws
/// neither cards nor a heading — only the divider [_OcptCardChoiceSectionView] puts above every
/// section but the first, which a naive `sections.indexed` reading would still draw over the empty
/// section's own nothing, floating with no card above it. [build] filters the list down to the
/// sections actually worth drawing first, so "the first one" — the one told to skip its own
/// leading space and divider — means the first one a reader actually sees.
///
/// [title] and [message] are plain strings handed in by the caller, the wording of both being
/// per-caller.
class OcptCardChoiceDialog<T> extends StatelessWidget {
  /// The dialog's title.
  final String title;

  /// The sentence under the title saying what this dialog is.
  final String message;

  /// The groups of cards offered, in the given order, drawn one under the other behind a divider.
  final List<OcptCardChoiceSection<T>> sections;

  /// Class constructor
  const OcptCardChoiceDialog({
    required this.title,
    required this.message,
    required this.sections,
    super.key,
  });

  /// Shows the dialog and returns the [OcptCardChoiceEntry.value] of the card the user picked, or
  /// null if they cancelled it or picked no card at all.
  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    required String message,
    required List<OcptCardChoiceSection<T>> sections,
  }) => showDialog<T>(
    context: context,
    builder: (context) =>
        OcptCardChoiceDialog<T>(title: title, message: message, sections: sections),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final visibleSections = [for (final section in sections) if (section.entries.isNotEmpty) section];

    // On a phone-width screen the fixed 600px grid would overflow, and two columns leave each card
    // too narrow to read: below the breakpoint the dialog takes the width it is given and stacks its
    // cards in a single column instead.
    final isCompact = ocptIsCompactWidth(MediaQuery.sizeOf(context).width);
    final crossAxisCount = isCompact ? 1 : 2;

    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: isCompact ? double.maxFinite : _ocptCardChoiceGridWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
            // [_ocptCardChoiceMaxHeight] is a ceiling for a roomy dialog; wrapping it in a [Flexible]
            // lets the scroll area shrink below that when the dialog itself is shorter than the
            // ceiling — a single-column list on a phone, say — so the cards scroll within the space
            // there is rather than overflowing the dialog.
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: _ocptCardChoiceMaxHeight),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (index, section) in visibleSections.indexed)
                        _OcptCardChoiceSectionView<T>(
                          section: section,
                          isFirst: index == 0,
                          crossAxisCount: crossAxisCount,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => globalGetIt().get<OcptRouterManager>().pop<T>(),
          child: Text(tr.editorPageSetupCancelAction),
        ),
      ],
    );
  }
}

/// One group of [OcptCardChoiceDialog], its cards laid out as a grid of [crossAxisCount] columns
/// under an optional heading, and separated from whatever came before it by a divider.
class _OcptCardChoiceSectionView<T> extends StatelessWidget {
  /// The group being drawn.
  final OcptCardChoiceSection<T> section;

  /// Whether this is the topmost group, which needs neither the divider nor the space above it.
  final bool isFirst;

  /// How many columns to lay the cards out in — two at an expanded width, one on a phone-width
  /// screen (see [OcptCardChoiceDialog.build]).
  final int crossAxisCount;

  /// Class constructor
  const _OcptCardChoiceSectionView({
    required this.section,
    required this.isFirst,
    required this.crossAxisCount,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final heading = section.heading;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!isFirst) ...[const SizedBox(height: 16), const Divider(), const SizedBox(height: 8)],
        if (heading != null) ...[
          Text(
            heading,
            style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
        ],
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            mainAxisExtent: _ocptCardChoiceCardHeight,
          ),
          itemCount: section.entries.length,
          itemBuilder: (context, index) => _OcptCardChoiceCard<T>(entry: section.entries[index]),
        ),
      ],
    );
  }
}

/// One card of [OcptCardChoiceDialog], the whole surface clickable when [entry] is available.
class _OcptCardChoiceCard<T> extends StatelessWidget {
  /// The thing this card offers.
  final OcptCardChoiceEntry<T> entry;

  /// Class constructor
  const _OcptCardChoiceCard({required this.entry, super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAvailable = entry.isAvailable;

    return Opacity(
      opacity: isAvailable ? 1 : _ocptCardChoiceUnavailableOpacity,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          mouseCursor: ocptClickableCursor,
          onTap: isAvailable
              ? () => globalGetIt().get<OcptRouterManager>().pop<T>(entry.value)
              : null,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        entry.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      entry.formatLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: Text(
                    entry.unavailableReason ?? entry.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
