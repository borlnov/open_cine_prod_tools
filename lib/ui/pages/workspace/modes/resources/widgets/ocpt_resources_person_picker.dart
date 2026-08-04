// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';

/// The value the "nobody" entry of the menu carries, distinct from every person id — a
/// [PopupMenuButton] cannot carry a null value for an entry that must still be selectable.
const String _nobodyOption = "";

/// "Which person is this?", asked the same way wherever a resources sheet asks it: a label over a
/// badge doubling as a [PopupMenuButton] over the whole address book, an entry clearing the answer
/// at the top of it, and — once somebody is named — the `↗` opening their own sheet.
///
/// Four sheets ask it and they must not each answer it differently: a role's cast member, a
/// location's contact, and an element's owner and the person who brings it to set. Every one of
/// them is the same gesture over the same list, so it is one widget rather than four copies of a
/// badge, a menu and an arrow.
///
/// [onChanged] null is what withholds the menu (a project version being previewed read-only): the
/// badge is then plain text with no drop-down marker at all, in the app's withhold-don't-disable
/// idiom. [onPersonSheetOpenRequested] is independent of it — reading a person's sheet is not a
/// write, so the `↗` stays while a version is previewed.
class OcptResourcesPersonPicker extends StatelessWidget {
  /// The whole address book, in display order: what the menu offers.
  final List<OcptPerson> people;

  /// The person currently named, or null while nobody is.
  final OcptPerson? selectedPerson;

  /// The field's label, upper-cased for display (`Cast member`, `Contact`, `Owner`…).
  final String label;

  /// How the empty answer reads, both on the badge and as the menu's clearing entry (`Not cast`,
  /// `No contact`…) — never a bare em dash: what "nobody" means is the caller's own question.
  final String emptyLabel;

  /// Called with the id of the person picked, or null when the clearing entry was; null itself
  /// while the sheet may not be written to, which withholds the menu.
  final ValueChanged<String?>? onChanged;

  /// Called with the named person's id when the `↗` beside the badge is clicked, or null for a
  /// picker that offers no jump at all.
  final ValueChanged<String>? onPersonSheetOpenRequested;

  /// Class constructor
  const OcptResourcesPersonPicker({
    super.key,
    required this.people,
    required this.selectedPerson,
    required this.label,
    required this.emptyLabel,
    required this.onChanged,
    this.onPersonSheetOpenRequested,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final selectedPerson = this.selectedPerson;
    final onChanged = this.onChanged;
    final onPersonSheetOpenRequested = this.onPersonSheetOpenRequested;

    final badge = _buildBadge(context, tr);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            if (onChanged == null)
              Flexible(child: badge)
            else
              Flexible(
                child: PopupMenuButton<String>(
                  tooltip: "",
                  onSelected: (value) => onChanged(value == _nobodyOption ? null : value),
                  itemBuilder: (context) => [
                    PopupMenuItem<String>(value: _nobodyOption, child: Text(emptyLabel)),
                    const PopupMenuDivider(),
                    for (final person in people)
                      PopupMenuItem<String>(
                        value: person.id,
                        child: Text(_nameOf(tr, person)),
                      ),
                  ],
                  child: badge,
                ),
              ),
            if (selectedPerson != null && onPersonSheetOpenRequested != null) ...[
              const SizedBox(width: 6),
              Tooltip(
                message: tr.resourcesOpenPersonSheetTooltip,
                child: InkWell(
                  onTap: () => onPersonSheetOpenRequested(selectedPerson.id),
                  mouseCursor: ocptClickableCursor,
                  borderRadius: BorderRadius.circular(ocptRadiusSmall),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.north_east, size: 14),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  /// The badge itself: the named person, or [emptyLabel] in italics, followed by the drop-down
  /// marker only while the menu may actually be opened.
  Widget _buildBadge(BuildContext context, Tr tr) {
    final theme = Theme.of(context);
    final selectedPerson = this.selectedPerson;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            selectedPerson == null ? emptyLabel : _nameOf(tr, selectedPerson),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              fontStyle: selectedPerson == null ? FontStyle.italic : FontStyle.normal,
            ),
          ),
        ),
        if (onChanged != null) ...[
          const SizedBox(width: 4),
          Icon(Icons.arrow_drop_down, size: 16, color: theme.colorScheme.onSurfaceVariant),
        ],
      ],
    );
  }

  /// How [person] reads on the badge and in the menu: their display name, or the shared placeholder
  /// for somebody whose name has not been typed in yet.
  String _nameOf(Tr tr, OcptPerson person) =>
      person.displayName.isEmpty ? tr.resourcesUnnamedPerson : person.displayName;
}
