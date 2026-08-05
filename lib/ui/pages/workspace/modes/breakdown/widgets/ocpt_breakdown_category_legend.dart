// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_breakdown_labels.dart';
import 'package:open_cine_prod_tools/utils/ocpt_breakdown_legend.dart';

/// The opacity a hidden legend row is dimmed to: faint enough to read as "off", never so faint the
/// row stops being legible — hiding a category is a reading aid the user must be able to find and
/// undo, not a row that disappears.
const double _ocptBreakdownLegendHiddenOpacity = 0.4;

/// The tallest the legend's own row list is ever drawn, in logical pixels, before it scrolls
/// internally rather than pushing the rest of the left dock's column out of shape.
const double _ocptBreakdownLegendMaxHeight = 240;

/// The breakdown mode's left dock legend, mounted by `OcptBreakdownScenePanel` under its scene
/// list: one clickable row per [OcptBreakdownLegendEntry] — a colour swatch, its label and how many
/// distinct targets fall under it — dimmed while its key is in [hiddenKeys]. A `Show all` action
/// sits beside the title, shown only while something is hidden.
///
/// Hiding a key is a reading aid for `OcptBreakdownScriptView`'s own highlighting alone: a hidden
/// category's words on the sheet stay clickable and still select their target, only their colour
/// wash is withheld — so a row here never grows a disabled look of its own, it only dims.
///
/// Purely presentational, like every other widget of this mode: it renders [entries] and reports
/// every click upward, reading nothing off a manager.
class OcptBreakdownCategoryLegend extends StatelessWidget {
  /// The legend rows to show, already built by `ocptBreakdownLegendEntriesOf` from the loaded
  /// snapshot's targets.
  final List<OcptBreakdownLegendEntry> entries;

  /// The legend keys currently hidden from the script view's own highlighting.
  final Set<OcptBreakdownLegendKey> hiddenKeys;

  /// Called with an entry's key when its row is clicked, toggling whether it is hidden.
  final ValueChanged<OcptBreakdownLegendKey> onEntryToggled;

  /// Called when the `Show all` action is clicked, revealing every hidden key.
  final VoidCallback onShowAllRequested;

  /// Class constructor
  const OcptBreakdownCategoryLegend({
    super.key,
    required this.entries,
    required this.hiddenKeys,
    required this.onEntryToggled,
    required this.onShowAllRequested,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(tr.breakdownLegendTitle, style: theme.textTheme.titleSmall),
              ),
              if (hiddenKeys.isNotEmpty)
                InkWell(
                  onTap: onShowAllRequested,
                  mouseCursor: ocptClickableCursor,
                  borderRadius: BorderRadius.circular(ocptRadiusSmall),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Text(
                      tr.breakdownLegendShowAllAction,
                      style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary),
                    ),
                  ),
                ),
            ],
          ),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: _ocptBreakdownLegendMaxHeight),
          child: ListView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: 8),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              return _OcptBreakdownLegendRow(
                entry: entry,
                isHidden: hiddenKeys.contains(entry.key),
                onTap: () => onEntryToggled(entry.key),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// One row of [OcptBreakdownCategoryLegend]: its own clickable swatch, label and count.
class _OcptBreakdownLegendRow extends StatelessWidget {
  /// The entry this row shows.
  final OcptBreakdownLegendEntry entry;

  /// Whether [entry]'s key is currently hidden from the script view's highlighting.
  final bool isHidden;

  /// Called when this row is clicked.
  final VoidCallback onTap;

  /// Class constructor
  const _OcptBreakdownLegendRow({required this.entry, required this.isHidden, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return InkWell(
      onTap: onTap,
      mouseCursor: ocptClickableCursor,
      child: Opacity(
        opacity: isHidden ? _ocptBreakdownLegendHiddenOpacity : 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Color(entry.color),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  ocptBreakdownLegendKeyLabel(tr, entry.key),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  "${entry.count}",
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
