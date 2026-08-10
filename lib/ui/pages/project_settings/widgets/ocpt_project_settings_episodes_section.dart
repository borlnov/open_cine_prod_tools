// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_episode.dart';

/// The project settings page's "Episodes" section card: one row per live episode of the project
/// (its editable number, its inline-editable title, its `▲`/`▼` reorder controls and its delete
/// action), plus the `+ Add` action appending a new one.
///
/// The number is editable because `screenplays.number` carries no uniqueness constraint by design
/// (`docs/adr/0019-one-project-several-episodes.md`): two episodes numbered 4 is a state the user
/// reaches by hand and repairs by hand. `▲`/`▼` only ever move `sortKey` — never `number` — and
/// [onEpisodeMoved] is not withheld at this level: with two or more episodes there is always at
/// least one direction to offer, so each row works out its own null on the end it sits at, exactly
/// as `OcptScheduleSlotCard`'s own pair does. The delete action, by contrast, is withheld outright
/// (no row is built with one) the moment [episodes] holds a single one — a project always holds at
/// least one screenplay.
class OcptProjectSettingsEpisodesSection extends StatelessWidget {
  /// The project's live episodes, in `sortKey` order.
  final List<OcptEpisode> episodes;

  /// Called when `+ Add` is tapped.
  final VoidCallback onEpisodeAdded;

  /// Called with an episode's id and the title just committed for it — the empty string is a
  /// legal title, read as "untitled" rather than reverted.
  final void Function(String screenplayId, String title) onEpisodeTitleChanged;

  /// Called with an episode's id and the printed number just committed for it.
  final void Function(String screenplayId, int number) onEpisodeNumberChanged;

  /// Called with an episode's id and the 0-based position it is moved to, from a row's own `▲`/`▼`.
  final void Function(String screenplayId, int newPosition) onEpisodeMoved;

  /// Called with the episode a row's delete action was clicked for. The page opens
  /// `OcptConfirmDialog` from this callback — this widget only ever asks.
  final ValueChanged<OcptEpisode> onEpisodeDeletionRequested;

  /// Class constructor
  const OcptProjectSettingsEpisodesSection({
    required this.episodes,
    required this.onEpisodeAdded,
    required this.onEpisodeTitleChanged,
    required this.onEpisodeNumberChanged,
    required this.onEpisodeMoved,
    required this.onEpisodeDeletionRequested,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr.projectSettingsEpisodesSectionTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            for (var index = 0; index < episodes.length; index++) ...[
              if (index > 0) const SizedBox(height: 4),
              _OcptProjectSettingsEpisodeRow(
                key: ValueKey(episodes[index].id),
                episode: episodes[index],
                onTitleChanged: (title) => onEpisodeTitleChanged(episodes[index].id, title),
                onNumberChanged: (number) => onEpisodeNumberChanged(episodes[index].id, number),
                onMovedUp: index == 0
                    ? null
                    : () => onEpisodeMoved(episodes[index].id, index - 1),
                onMovedDown: index == episodes.length - 1
                    ? null
                    : () => onEpisodeMoved(episodes[index].id, index + 1),
                onDeleteRequested: episodes.length <= 1
                    ? null
                    : () => onEpisodeDeletionRequested(episodes[index]),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onEpisodeAdded,
                child: Text(tr.projectSettingsEpisodeAddAction),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One row of [OcptProjectSettingsEpisodesSection]: the number and title fields follow this page's
/// own committed-edit idiom (`_OcptProjectSettingsMinimumRestField`'s doc comment) — committed on
/// submit or focus loss, never on every keystroke, and guarded against reporting the same edit
/// twice.
class _OcptProjectSettingsEpisodeRow extends StatefulWidget {
  /// The episode this row shows.
  final OcptEpisode episode;

  /// Called with the title just committed.
  final ValueChanged<String> onTitleChanged;

  /// Called with the number just committed.
  final ValueChanged<int> onNumberChanged;

  /// Moves this episode one place up, or null while it is already the first.
  final VoidCallback? onMovedUp;

  /// Moves this episode one place down, or null while it is already the last.
  final VoidCallback? onMovedDown;

  /// Deletes this episode, or null while it is the project's only live one.
  final VoidCallback? onDeleteRequested;

  /// Class constructor
  const _OcptProjectSettingsEpisodeRow({
    required this.episode,
    required this.onTitleChanged,
    required this.onNumberChanged,
    required this.onMovedUp,
    required this.onMovedDown,
    required this.onDeleteRequested,
    super.key,
  });

  @override
  State<_OcptProjectSettingsEpisodeRow> createState() => _OcptProjectSettingsEpisodeRowState();
}

/// The state of [_OcptProjectSettingsEpisodeRow]: owns the two controllers and the
/// commit-on-submit-or-focus-loss idiom for both fields.
class _OcptProjectSettingsEpisodeRowState extends State<_OcptProjectSettingsEpisodeRow> {
  /// The number field's own controller, seeded from [_OcptProjectSettingsEpisodeRow.episode].
  late final TextEditingController _numberController = TextEditingController(
    text: widget.episode.number.toString(),
  );

  /// The title field's own controller, seeded from [_OcptProjectSettingsEpisodeRow.episode].
  late final TextEditingController _titleController = TextEditingController(
    text: widget.episode.title,
  );

  /// The number field's own focus node, committing the moment it loses focus.
  final FocusNode _numberFocusNode = FocusNode();

  /// The title field's own focus node, committing the moment it loses focus.
  final FocusNode _titleFocusNode = FocusNode();

  /// The number this row last reported — compared against on every commit rather than
  /// [_OcptProjectSettingsEpisodeRow.episode]'s own number, so a submission's own focus loss never
  /// commits the very same edit twice (`_OcptProjectSettingsMinimumRestField`'s own reasoning).
  late int _lastReportedNumber = widget.episode.number;

  /// The title this row last reported, compared against the same way [_lastReportedNumber] is.
  late String _lastReportedTitle = widget.episode.title;

  @override
  void initState() {
    super.initState();
    _numberFocusNode.addListener(_onNumberFocusChanged);
    _titleFocusNode.addListener(_onTitleFocusChanged);
  }

  @override
  void didUpdateWidget(covariant _OcptProjectSettingsEpisodeRow oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.episode.number != widget.episode.number) {
      _lastReportedNumber = widget.episode.number;
      if (!_numberFocusNode.hasFocus) {
        _numberController.text = widget.episode.number.toString();
      }
    }
    if (oldWidget.episode.title != widget.episode.title) {
      _lastReportedTitle = widget.episode.title;
      if (!_titleFocusNode.hasFocus) {
        _titleController.text = widget.episode.title;
      }
    }
  }

  @override
  void dispose() {
    _numberFocusNode
      ..removeListener(_onNumberFocusChanged)
      ..dispose();
    _titleFocusNode
      ..removeListener(_onTitleFocusChanged)
      ..dispose();
    _numberController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  /// Commits the number field's current text once it loses focus.
  void _onNumberFocusChanged() {
    if (!_numberFocusNode.hasFocus) {
      _commitNumber();
    }
  }

  /// Commits the title field's current text once it loses focus.
  void _onTitleFocusChanged() {
    if (!_titleFocusNode.hasFocus) {
      _commitTitle();
    }
  }

  /// Parses the number field's current text and reports it: an unparseable or non-positive figure
  /// reverts the field to whatever was last committed, exactly as the minimum rest field's own
  /// zero-or-negative case does.
  void _commitNumber() {
    final parsed = int.tryParse(_numberController.text.trim());
    if (parsed == null || parsed <= 0) {
      _numberController.text = _lastReportedNumber.toString();
      return;
    }

    _numberController.text = parsed.toString();
    if (parsed != _lastReportedNumber) {
      _lastReportedNumber = parsed;
      widget.onNumberChanged(parsed);
    }
  }

  /// Reports the title field's current text: any string is legal, the empty one included — an
  /// untitled episode is an ordinary state (`OcptEpisode.title`'s own doc comment), never a
  /// reversion.
  void _commitTitle() {
    final text = _titleController.text;
    if (text != _lastReportedTitle) {
      _lastReportedTitle = text;
      widget.onTitleChanged(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);

    return Row(
      children: [
        SizedBox(
          width: 56,
          child: TextField(
            controller: _numberController,
            focusNode: _numberFocusNode,
            onSubmitted: (_) => _commitNumber(),
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
            decoration: const InputDecoration(isDense: true),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: _titleController,
            focusNode: _titleFocusNode,
            onSubmitted: (_) => _commitTitle(),
            style: theme.textTheme.bodySmall,
            decoration: InputDecoration(
              isDense: true,
              hintText: tr.projectSettingsEpisodeTitleHint,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.keyboard_arrow_up, size: 18),
          tooltip: tr.projectSettingsEpisodeMoveUpTooltip,
          visualDensity: VisualDensity.compact,
          onPressed: widget.onMovedUp,
        ),
        IconButton(
          icon: const Icon(Icons.keyboard_arrow_down, size: 18),
          tooltip: tr.projectSettingsEpisodeMoveDownTooltip,
          visualDensity: VisualDensity.compact,
          onPressed: widget.onMovedDown,
        ),
        if (widget.onDeleteRequested != null)
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            tooltip: tr.projectSettingsEpisodeDeleteTooltip,
            visualDensity: VisualDensity.compact,
            onPressed: widget.onDeleteRequested,
          ),
      ],
    );
  }
}
