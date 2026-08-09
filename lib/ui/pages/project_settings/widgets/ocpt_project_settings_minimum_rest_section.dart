// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/utils/ocpt_day_minute.dart';

/// The project settings page's "Minimum rest between two shooting days" section card: a single
/// field, typed in minutes, whose committed value is read back as a formatted duration through
/// [ocptFormatMinuteDuration] — typing `660` and leaving the field shows `11 h`.
///
/// **Empty is legal, and means nobody has recorded a minimum** — never that no minimum applies —
/// exactly the reading `project_info.minimumRestMinutes`'s own doc comment gives and
/// `OcptScheduleRestTimeAlert` depends on to stay silent rather than advancing a claim nobody
/// entered; clearing the field is as real a gesture as typing one. It is **deliberately not
/// pre-filled with 660**: eleven hours is French law, and this app ships in more than one country,
/// so a default here would be the app advancing a legal figure nobody has validated. Both readings
/// are in the card's own hint, under the field, for the same reason the permit card's own validity
/// dates carry one.
class OcptProjectSettingsMinimumRestSection extends StatelessWidget {
  /// The project's current minimum rest, in minutes, or null while nobody has recorded one.
  final int? minimumRestMinutes;

  /// Called with the newly committed minimum, in minutes, or null to clear it.
  final ValueChanged<int?> onMinimumRestMinutesChanged;

  /// Class constructor
  const OcptProjectSettingsMinimumRestSection({
    required this.minimumRestMinutes,
    required this.onMinimumRestMinutesChanged,
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
            Text(
              tr.projectSettingsMinimumRestSectionTitle,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: Text(tr.projectSettingsMinimumRestLabel)),
                _OcptProjectSettingsMinimumRestField(
                  minimumRestMinutes: minimumRestMinutes,
                  onChanged: onMinimumRestMinutesChanged,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              tr.projectSettingsMinimumRestHint,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// The minimum rest field itself: typed freely in minutes, committed on submit or focus loss, and
/// read back as a formatted duration — `OcptScheduleMinuteField`'s own idiom
/// (`lib/ui/pages/workspace/modes/schedule/widgets/`), with the one difference its own doc comment
/// states: an **empty** submission here is a legal value (null, "nobody has recorded one") rather
/// than a reversion, since there is nothing else for this field to fall back to the way a slot's
/// clock falls back to its own resolved hour.
///
/// A negative or zero figure is not a minimum anybody meant and reverts the field to whatever was
/// last committed, exactly as an unparseable one does.
class _OcptProjectSettingsMinimumRestField extends StatefulWidget {
  /// The project's current minimum rest, in minutes, or null while unset.
  final int? minimumRestMinutes;

  /// Called with the minutes just committed, or null when the field was submitted empty.
  final ValueChanged<int?> onChanged;

  /// Class constructor
  const _OcptProjectSettingsMinimumRestField({
    required this.minimumRestMinutes,
    required this.onChanged,
  });

  @override
  State<_OcptProjectSettingsMinimumRestField> createState() =>
      _OcptProjectSettingsMinimumRestFieldState();
}

/// The state of [_OcptProjectSettingsMinimumRestField]: owns the controller and the
/// commit-on-submit-or-focus-loss idiom.
class _OcptProjectSettingsMinimumRestFieldState
    extends State<_OcptProjectSettingsMinimumRestField> {
  /// The field's own text controller, seeded from
  /// [_OcptProjectSettingsMinimumRestField.minimumRestMinutes]'s own formatted reading.
  late final TextEditingController _controller = TextEditingController(text: _formatted);

  /// The field's own focus node, committing the moment it loses focus.
  final FocusNode _focusNode = FocusNode();

  /// The value this field last reported — compared against on every commit rather than
  /// [_OcptProjectSettingsMinimumRestField.minimumRestMinutes] itself, so a submission's own focus
  /// loss never commits the very same edit twice (`OcptScheduleMinuteField`'s own reasoning).
  late int? _lastReportedMinutes = widget.minimumRestMinutes;

  /// [_OcptProjectSettingsMinimumRestField.minimumRestMinutes] formatted through
  /// [ocptFormatMinuteDuration], or the empty string while it is null.
  String get _formatted =>
      widget.minimumRestMinutes == null ? "" : ocptFormatMinuteDuration(widget.minimumRestMinutes!);

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(covariant _OcptProjectSettingsMinimumRestField oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.minimumRestMinutes != widget.minimumRestMinutes) {
      _lastReportedMinutes = widget.minimumRestMinutes;
      if (!_focusNode.hasFocus) {
        _controller.text = _formatted;
      }
    }
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_onFocusChanged)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  /// Commits the field's current text once it loses focus.
  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      _commit();
    }
  }

  /// Parses the field's current text and reports it: empty clears the minimum (a real gesture,
  /// reported as null), a positive figure is reported and read back formatted, and anything else —
  /// zero, negative, or unparseable — reverts the field to whatever was last committed.
  void _commit() {
    final text = _controller.text.trim();

    if (text.isEmpty) {
      _controller.text = "";
      if (_lastReportedMinutes != null) {
        _lastReportedMinutes = null;
        widget.onChanged(null);
      }
      return;
    }

    final parsed = int.tryParse(text);
    if (parsed == null || parsed <= 0) {
      _controller.text = _formatted;
      return;
    }

    _controller.text = ocptFormatMinuteDuration(parsed);
    if (parsed != _lastReportedMinutes) {
      _lastReportedMinutes = parsed;
      widget.onChanged(parsed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 96,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        onSubmitted: (_) => _commit(),
        keyboardType: TextInputType.number,
        style: theme.textTheme.bodySmall,
        decoration: const InputDecoration(isDense: true),
      ),
    );
  }
}
