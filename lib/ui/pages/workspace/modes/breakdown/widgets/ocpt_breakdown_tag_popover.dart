// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_cine_prod_tools/constants/ocpt_breakdown_palette.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart' as ocpt_theme;
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_breakdown_search.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_breakdown_search_candidate.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_breakdown_search_results.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_target_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/widgets/ocpt_breakdown_tag_popover_anchor.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_breakdown_labels.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_resources_labels.dart';

export 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/widgets/ocpt_breakdown_tag_popover_anchor.dart';

/// The widest the tag popover's own panel is ever drawn, in logical pixels — the mock-up's own
/// figure.
const double _ocptBreakdownTagPopoverWidth = 340;

/// The popover a range closes on: the passage in quotes, a search field pre-filled with it and
/// focused, the matches from [candidates] grouped `Roles`/`Sets`/`Elements`, the
/// `Create an element` category grid, the `Create a set` control, an `Open in Resources` action
/// shown when the search names no role and no set, and a trailing hint.
///
/// **An element and a set are the two things this popover may create; a role is not.** A role
/// exists because a character speaks in the screenplay — `OcptRoleIndexService` reconciles it from
/// the cue — so inventing one here would be inventing a character. A set has no such source: the
/// script names the place (`INT. CUISINE`) but nothing in the project knows it yet, and sending the
/// user to the resources mode to invent a location first would break the one reading the whole mode
/// exists for. Its location is therefore picked here, from [locations], or minted along with it.
///
/// The field's own text is both the query [candidates] are filtered against
/// (`ocptBreakdownSearchCatalogues`) and the name a category chip's creation would use — there is
/// no separate name field: correcting the name and picking the category are the same one gesture.
/// Purely presentational: every write goes upward through [onCandidateSelected] (linking) or
/// [onCategorySelected] (creating), the mode itself resolving each into
/// `OcptBreakdownService.createTag`/`createElementAndTag`.
///
/// Closed by [onClose] on its own × button, on `Escape`, or on a tap outside it
/// ([TapRegion.onTapOutside]) — the range interaction's own cancel, clearing the pending range
/// **and** the anchor.
class OcptBreakdownTagPopover extends StatefulWidget {
  /// The passage this popover is about, quoted in its header and used as the search field's initial
  /// text.
  final String taggedText;

  /// The whole catalogue this popover searches, built once by the mode from the loaded snapshot.
  final List<OcptBreakdownSearchCandidate> candidates;

  /// Called with a match when one of its rows is clicked, linking the passage to it.
  final ValueChanged<OcptBreakdownSearchCandidate> onCandidateSelected;

  /// Called with a category and the field's own current text when one of the category chips is
  /// clicked, creating a new element in that category and tagging the passage with it.
  final void Function(OcptElementCategory category, String name) onCategorySelected;

  /// Every location of the project, `(id, name)`, offered by the `Create a set` control as the
  /// place the new set goes into. May be empty — a project with no location at all then only offers
  /// creating one along with the set.
  final List<(String, String)> locations;

  /// Called with the location the new set belongs to and the field's own current text when the
  /// `Create a set` control is answered, creating that set and tagging the passage with it.
  ///
  /// A null location id means **a new location of its own**, named after the set: a place the
  /// project has never heard of has to come into existence somewhere, and the sheet where the two
  /// are told apart is in the resources mode.
  final void Function(String? locationId, String name) onSetCreationSelected;

  /// Called when `Open in Resources` is clicked (shown only while the search names no role and no
  /// set).
  final VoidCallback onOpenInResourcesRequested;

  /// Called when the popover should close without writing anything: its own × button, `Escape`, or
  /// a tap outside it.
  final VoidCallback onClose;

  /// Class constructor
  const OcptBreakdownTagPopover({
    super.key,
    required this.taggedText,
    required this.candidates,
    required this.onCandidateSelected,
    required this.onCategorySelected,
    required this.locations,
    required this.onSetCreationSelected,
    required this.onOpenInResourcesRequested,
    required this.onClose,
  });

  @override
  State<OcptBreakdownTagPopover> createState() => _OcptBreakdownTagPopoverState();
}

/// The state of [OcptBreakdownTagPopover]: owns the query field's controller and focus and the
/// results computed from it.
class _OcptBreakdownTagPopoverState extends State<OcptBreakdownTagPopover> {
  /// The query field, pre-filled with the passage — also the name a creation would use.
  late final TextEditingController _controller = TextEditingController(text: widget.taggedText);

  /// The query field's own focus, requested as soon as the popover appears.
  final FocusNode _fieldFocusNode = FocusNode();

  /// The last computed results, refreshed on every keystroke.
  late OcptBreakdownSearchResults _results = ocptBreakdownSearchCatalogues(
    query: _controller.text,
    candidates: widget.candidates,
  );

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onQueryChanged)
      ..dispose();
    _fieldFocusNode.dispose();
    super.dispose();
  }

  /// Recomputes the results against the field's current text.
  void _onQueryChanged() {
    setState(() {
      _results = ocptBreakdownSearchCatalogues(
        query: _controller.text,
        candidates: widget.candidates,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return TapRegion(
      onTapOutside: (_) => widget.onClose(),
      child: Focus(
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
            widget.onClose();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Material(
          elevation: 8,
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(ocpt_theme.ocptRadiusMedium),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: _ocptBreakdownTagPopoverWidth,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: ocptBreakdownTagPopoverMaxHeight),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Header(taggedText: widget.taggedText, onClose: widget.onClose),
                  Divider(height: 1, color: theme.colorScheme.outlineVariant),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: TextField(
                              controller: _controller,
                              focusNode: _fieldFocusNode,
                              autofocus: true,
                              decoration: InputDecoration(
                                isDense: true,
                                hintText: tr.breakdownPopoverFieldHint,
                              ),
                            ),
                          ),
                          if (!_results.isEmpty)
                            _Matches(
                              results: _results,
                              onCandidateSelected: widget.onCandidateSelected,
                            ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                            child: Text(
                              tr.breakdownPopoverCreateElementTitle.toUpperCase(),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                            child: _CategoryGrid(
                              onCategorySelected: widget.onCategorySelected,
                              nameFromField: _nameFromField,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                            child: _SetCreationControl(
                              locations: widget.locations,
                              onSetCreationSelected: widget.onSetCreationSelected,
                              nameFromField: _nameFromField,
                            ),
                          ),
                          if (_results.roles.isEmpty && _results.sets.isEmpty)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                              child: OutlinedButton(
                                onPressed: widget.onOpenInResourcesRequested,
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(34),
                                ),
                                child: Text(tr.breakdownOpenInResourcesAction),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
                    ),
                    child: Text(
                      tr.breakdownPopoverFooterHint,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The name a creation would use: the field's own trimmed text, falling back to the untouched
  /// passage when the user cleared it — a click on a category chip must never create a nameless
  /// element.
  String _nameFromField() {
    final trimmed = _controller.text.trim();
    return trimmed.isEmpty ? widget.taggedText : trimmed;
  }
}

/// The quoted passage and the × close button.
class _Header extends StatelessWidget {
  /// The passage the popover is about.
  final String taggedText;

  /// Called when the × button is clicked.
  final VoidCallback onClose;

  /// Class constructor
  const _Header({required this.taggedText, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              '"$taggedText"',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall,
            ),
          ),
          InkWell(
            onTap: onClose,
            mouseCursor: ocpt_theme.ocptClickableCursor,
            borderRadius: BorderRadius.circular(ocpt_theme.ocptRadiusSmall),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Icon(Icons.close, size: 16, color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

/// The matches, grouped `Roles`/`Sets`/`Elements` — a group with no match of its own kind is left
/// out entirely.
class _Matches extends StatelessWidget {
  /// The results to show.
  final OcptBreakdownSearchResults results;

  /// Called with a match when its row is clicked.
  final ValueChanged<OcptBreakdownSearchCandidate> onCandidateSelected;

  /// Class constructor
  const _Matches({required this.results, required this.onCandidateSelected});

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (results.roles.isNotEmpty)
          _Group(
            title: tr.breakdownPopoverRolesGroupTitle,
            candidates: results.roles,
            onCandidateSelected: onCandidateSelected,
          ),
        if (results.sets.isNotEmpty)
          _Group(
            title: tr.breakdownPopoverSetsGroupTitle,
            candidates: results.sets,
            onCandidateSelected: onCandidateSelected,
          ),
        if (results.elements.isNotEmpty)
          _Group(
            title: tr.breakdownPopoverElementsGroupTitle,
            candidates: results.elements,
            onCandidateSelected: onCandidateSelected,
          ),
      ],
    );
  }
}

/// One group of the matches section: a title, then a clickable row per candidate.
class _Group extends StatelessWidget {
  /// The group's title.
  final String title;

  /// The candidates of the group.
  final List<OcptBreakdownSearchCandidate> candidates;

  /// Called with a match when its row is clicked.
  final ValueChanged<OcptBreakdownSearchCandidate> onCandidateSelected;

  /// Class constructor
  const _Group({required this.title, required this.candidates, required this.onCandidateSelected});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
          child: Text(
            title.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        for (final candidate in candidates)
          _MatchRow(candidate: candidate, onTap: () => onCandidateSelected(candidate)),
      ],
    );
  }
}

/// One clickable match row: its own swatch, its name and — while already tagged somewhere — the
/// number of scenes it is tagged in.
class _MatchRow extends StatelessWidget {
  /// The candidate the row shows.
  final OcptBreakdownSearchCandidate candidate;

  /// Called when the row is clicked.
  final VoidCallback onTap;

  /// Class constructor
  const _MatchRow({required this.candidate, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      mouseCursor: ocpt_theme.ocptClickableCursor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: Color(
                  ocptBreakdownColorOf(kind: candidate.kind, category: candidate.category),
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                candidate.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ),
            if (candidate.taggedSceneCount > 0) ...[
              const SizedBox(width: 8),
              Text(
                Tr.of(context).breakdownInspectorSceneCountLabel(candidate.taggedSceneCount),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The two-column category grid: a click creates the element in that category, named from the
/// field's own current text.
class _CategoryGrid extends StatelessWidget {
  /// Called with the clicked category and the name a creation would use.
  final void Function(OcptElementCategory category, String name) onCategorySelected;

  /// Reads the name a creation would use, at the time of the click.
  final String Function() nameFromField;

  /// Class constructor
  const _CategoryGrid({required this.onCategorySelected, required this.nameFromField});

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 6,
      crossAxisSpacing: 6,
      childAspectRatio: 3.4,
      children: [
        for (final category in OcptElementCategory.values)
          _OcptBreakdownPopoverCategoryChip(
            label: ocptElementCategoryLabel(tr, category),
            swatchColor: Color(
              ocptBreakdownColorOf(kind: OcptBreakdownTargetKind.element, category: category),
            ),
            onTap: () => onCategorySelected(category, nameFromField()),
          ),
      ],
    );
  }
}

/// The `Create a set` control: a menu naming every location the set could go into, plus the entry
/// minting a location of its own for it.
///
/// A menu rather than a chip grid, unlike the element categories right above it: a project has as
/// many locations as it has, and they are the user's own names rather than a fixed list.
class _SetCreationControl extends StatelessWidget {
  /// Every location of the project, `(id, name)`.
  final List<(String, String)> locations;

  /// Called with the chosen location id (null for a new location) and the name a creation would use.
  final void Function(String? locationId, String name) onSetCreationSelected;

  /// Reads the name a creation would use, at the time of the pick.
  final String Function() nameFromField;

  /// Class constructor
  const _SetCreationControl({
    required this.locations,
    required this.onSetCreationSelected,
    required this.nameFromField,
  });

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return PopupMenuButton<String>(
      tooltip: "",
      onSelected: (value) =>
          onSetCreationSelected(value == ocptNewLocationMenuValue ? null : value, nameFromField()),
      itemBuilder: (context) => [
        for (final (id, name) in locations)
          PopupMenuItem<String>(value: id, child: Text(tr.breakdownPopoverCreateSetInOption(name))),
        if (locations.isNotEmpty) const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: ocptNewLocationMenuValue,
          child: Text(tr.breakdownPopoverCreateSetInNewLocationOption),
        ),
      ],
      // A chip rather than a button, the way every other picker of the app anchors its own menu (the
      // location sheet's scenes, the scene inspector's sets): the tap belongs to the menu, and a
      // button with no `onPressed` of its own would read as disabled.
      child: Chip(
        avatar: const Icon(Icons.add, size: 14),
        label: Text(tr.breakdownPopoverCreateSetAction),
      ),
    );
  }
}

/// One entry of the popover's category grid: a swatch and a label, mirroring
/// `OcptBreakdownTargetInspector`'s own category chip minus the "currently selected" state, which
/// has no meaning here — nothing is selected before a category is clicked, clicking one *is* the
/// creation.
class _OcptBreakdownPopoverCategoryChip extends StatelessWidget {
  /// The chip's own label.
  final String label;

  /// The category's own palette colour, shown as a small swatch.
  final Color swatchColor;

  /// Called when the chip is clicked.
  final VoidCallback onTap;

  /// Class constructor
  const _OcptBreakdownPopoverCategoryChip({
    required this.label,
    required this.swatchColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      mouseCursor: ocpt_theme.ocptClickableCursor,
      borderRadius: BorderRadius.circular(ocpt_theme.ocptRadiusSmall),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ocpt_theme.ocptRadiusSmall),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: swatchColor, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
