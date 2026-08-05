// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_centre_view.dart';

/// The horizontal padding of the switch's own two segments, in logical pixels.
const double _ocptBreakdownSegmentPadding = 14;

/// The fixed width of the header's own search field, in logical pixels.
const double _ocptBreakdownSearchFieldWidth = 260;

/// The width of the header's own progress track, in logical pixels.
const double _ocptBreakdownProgressBarWidth = 110;

/// The height of the header's own progress track, in logical pixels.
const double _ocptBreakdownProgressBarHeight = 5;

/// The narrowest the header is drawn with its progress track at all, in logical pixels: under
/// this, the switch and the search field are the only things left, since a control that cannot be
/// dropped (they are the only way to change what the centre shows) outranks a read-out that is
/// also printed elsewhere — see [OcptBreakdownHeader]'s own doc comment.
const double _ocptBreakdownHeaderProgressBarMinWidth = 620;

/// The narrowest the header is drawn with its hint and its progress **label**, in logical pixels.
/// Under this, the track alone carries the progress, tooltipped with the very label that was
/// dropped.
const double _ocptBreakdownHeaderFullWidth = 1000;

/// The breakdown mode's own header band, sitting above the centre view: the `Script`/`Recap`
/// switch, the search field beside it, a muted hint contextual to whichever view is active, and —
/// pushed to the right by a spacer — the pass's own progress (targets tagged, scenes done) as a
/// label and a small track.
///
/// Purely presentational, like every other widget of this mode: it renders and reports every
/// click and keystroke upward, reading nothing off a manager. Every affordance here only reads —
/// the switch and the search field filter what the centre shows, they never write to the project
/// database — so, like `OcptBreakdownRecapTable`, this widget needs no `isReadOnly` flag: a
/// previewed version withholds nothing this header offers.
///
/// **The band sheds what it cannot fit rather than overflowing**, since the centre it sits above is
/// only guaranteed the 320 px floor `OcptWorkspaceDock` leaves it: under
/// [_ocptBreakdownHeaderFullWidth] the hint and the progress label go, the track then carrying that
/// very label as its tooltip; under [_ocptBreakdownHeaderProgressBarMinWidth] the track goes too,
/// leaving the switch and the field, which then shrinks in turn. Nothing is lost by that: the two
/// controls are the only way to change what the centre shows, while the counters they make room for
/// are read-outs the status bar and the scene panel's own header already print. The two texts
/// ellipsize on top of all that, so a translation longer than the English never overflows between
/// two thresholds either.
class OcptBreakdownHeader extends StatelessWidget {
  /// Which of the two views is currently active, the switch's own value.
  final OcptBreakdownCentreView centreView;

  /// Called with the view just picked, when a segment of the switch is clicked.
  final ValueChanged<OcptBreakdownCentreView> onCentreViewSelected;

  /// The search field's current authoritative value — `OcptBreakdownState.searchQuery`.
  final String searchQuery;

  /// Called with the field's raw text on every keystroke, and by its own clear button with an
  /// empty string.
  final ValueChanged<String> onSearchQueryChanged;

  /// The number of distinct targets tagged across the whole screenplay — `snapshot.taggedTargetCount`.
  final int taggedTargetCount;

  /// The number of scenes marked done — `snapshot.doneSceneCount`.
  final int doneSceneCount;

  /// The screenplay's own scene count.
  final int sceneCount;

  /// Class constructor
  const OcptBreakdownHeader({
    super.key,
    required this.centreView,
    required this.onCentreViewSelected,
    required this.searchQuery,
    required this.onSearchQueryChanged,
    required this.taggedTargetCount,
    required this.doneSceneCount,
    required this.sceneCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    final progressLabel =
        "${tr.breakdownStatsTagged(taggedTargetCount)} · "
        "${tr.breakdownHeaderScenesProgressLabel(doneSceneCount, sceneCount)}";

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isProgressBarShown =
              constraints.maxWidth >= _ocptBreakdownHeaderProgressBarMinWidth;
          final isFullyShown = constraints.maxWidth >= _ocptBreakdownHeaderFullWidth;

          return Row(
            children: [
              _OcptBreakdownViewSwitch(value: centreView, onChanged: onCentreViewSelected),
              const SizedBox(width: 12),
              // Loose, so the field keeps its full width wherever there is room for it and shrinks
              // rather than pushing the row past its constraints where there is not.
              Flexible(
                flex: 3,
                child: SizedBox(
                  width: _ocptBreakdownSearchFieldWidth,
                  child: _OcptBreakdownSearchField(
                    query: searchQuery,
                    onChanged: onSearchQueryChanged,
                  ),
                ),
              ),
              if (isFullyShown) ...[
                const SizedBox(width: 12),
                Flexible(
                  flex: 2,
                  child: Text(
                    centreView == OcptBreakdownCentreView.script
                        ? tr.breakdownHeaderScriptHint
                        : tr.breakdownHeaderRecapHint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
              if (isProgressBarShown) ...[
                const Spacer(),
                if (isFullyShown) ...[
                  Flexible(
                    flex: 4,
                    child: Text(
                      progressLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Tooltip(
                  message: progressLabel,
                  child: _OcptBreakdownProgressBar(done: doneSceneCount, total: sceneCount),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// The `Script`/`Recap` switch: a small bordered rounded container, the active segment filled
/// `primary` and bolder.
class _OcptBreakdownViewSwitch extends StatelessWidget {
  /// The switch's own current value.
  final OcptBreakdownCentreView value;

  /// Called with the segment just clicked, when it differs from [value].
  final ValueChanged<OcptBreakdownCentreView> onChanged;

  /// Class constructor
  const _OcptBreakdownViewSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(ocptRadiusMedium),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSegment(context, OcptBreakdownCentreView.script, Tr.of(context).breakdownHeaderScriptSegmentLabel),
          _buildSegment(context, OcptBreakdownCentreView.recap, Tr.of(context).breakdownHeaderRecapSegmentLabel),
        ],
      ),
    );
  }

  /// One of the switch's own two segments.
  Widget _buildSegment(BuildContext context, OcptBreakdownCentreView segment, String label) {
    final theme = Theme.of(context);
    final isActive = value == segment;

    return InkWell(
      onTap: isActive ? null : () => onChanged(segment),
      mouseCursor: ocptClickableCursor,
      borderRadius: BorderRadius.circular(ocptRadiusSmall),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: _ocptBreakdownSegmentPadding,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: isActive
              ? theme.colorScheme.primary.withValues(alpha: ocptSelectedStateAlpha)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(ocptRadiusSmall),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: isActive ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

/// The header's own search field: a dense text field with a `search` prefix icon and a clear (×)
/// suffix once non-empty, mirroring `OcptResourcesSearchField`.
///
/// [query] is the field's current authoritative value: the controller is only reset to it when it
/// genuinely differs from what the controller already holds (the bloc cleared it, or restored it
/// on a fresh load), never on an unrelated rebuild, so the caret never jumps mid-typing.
class _OcptBreakdownSearchField extends StatefulWidget {
  /// The field's current authoritative value.
  final String query;

  /// Called with the field's raw text on every keystroke, and by the clear button with an empty
  /// string.
  final ValueChanged<String> onChanged;

  /// Class constructor
  const _OcptBreakdownSearchField({required this.query, required this.onChanged});

  @override
  State<_OcptBreakdownSearchField> createState() => _OcptBreakdownSearchFieldState();
}

/// The state of [_OcptBreakdownSearchField]: owns the controller the class doc comment explains
/// the reasoning for.
class _OcptBreakdownSearchFieldState extends State<_OcptBreakdownSearchField> {
  /// The field's own text editing controller, seeded from the widget's initial value and kept in
  /// sync with it afterward, see [didUpdateWidget].
  late final TextEditingController _controller = TextEditingController(text: widget.query);

  @override
  void didUpdateWidget(covariant _OcptBreakdownSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.query != _controller.text) {
      _controller.text = widget.query;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      style: Theme.of(context).textTheme.bodySmall,
      decoration: InputDecoration(
        isDense: true,
        hintText: tr.breakdownHeaderSearchHint,
        prefixIcon: const Icon(Icons.search, size: 18),
        suffixIcon: widget.query.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close, size: 16),
                tooltip: tr.breakdownHeaderSearchClearTooltip,
                onPressed: _handleClear,
              ),
      ),
    );
  }

  /// Blanks the field and reports the empty query.
  void _handleClear() {
    _controller.clear();
    widget.onChanged("");
  }
}

/// The header's own progress track: a rounded bar filled to `done / total` in the theme's accent
/// colour, empty while [total] is zero.
class _OcptBreakdownProgressBar extends StatelessWidget {
  /// The number of scenes marked done.
  final int done;

  /// The screenplay's own scene count.
  final int total;

  /// Class constructor
  const _OcptBreakdownProgressBar({required this.done, required this.total});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fraction = total <= 0 ? 0.0 : (done / total).clamp(0.0, 1.0);

    return Container(
      width: _ocptBreakdownProgressBarWidth,
      height: _ocptBreakdownProgressBarHeight,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(ocptRadiusSmall),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: fraction,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(ocptRadiusSmall),
          ),
        ),
      ),
    );
  }
}
