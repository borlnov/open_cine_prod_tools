// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_group.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_lead_field.dart';

/// The day view's own groups band, drawn between the summary band and the first slot card: the
/// day's own
/// [OcptShootingDayGroup]s, each as a small card carrying its own label, its own lead time and how
/// many crew and cast rows currently point at it, over a `+ Group` control.
///
/// **This is the one place a group is created, renamed, retimed or deleted.** A slot card's own
/// crew and cast rows only ever *pick* one of [groups] — the figure and the label live here, so a
/// crew member and an actor sharing a call time never drift out of step by one of them typing a
/// number a group card should have owned instead.
///
/// [labelValueOf] mirrors every other mode's own pending-edit-aware field read: a label rides the
/// mode's own 2 s field-edit debounce, so what is shown while typing is the pending edit rather than
/// the group's own stored value. [onLeadChanged] is a discrete write instead, exactly as every other
/// minute or lead figure this mode writes.
///
/// **Deleting a group is irreversible**: [onGroupDeletionRequested] only *asks* — the mode itself
/// opens `OcptConfirmDialog` before dispatching the deletion, following every other destructive
/// action of this mode (a day, a slot, a block). What that dialog says matters here specifically:
/// deleting a group leaves its members with no group rather than removing them from the day
/// (`OcptScheduleService.deleteGroup`'s own rule) — the confirmation must say so, not just "cannot
/// be undone".
///
/// Every writing affordance is a nullable callback, withheld while a project version is being
/// previewed: the label field, the lead field, `+ Group` and the delete control. A day with no group
/// at all still shows the band — its own empty hint, and, unless read-only, its `+ Group` control —
/// rather than disappearing.
///
/// The title's own ⓘ icon, explaining what a group is for, reads nothing that changes and writes
/// nothing itself, so it stays on screen — including while a version is being previewed — exactly
/// like every other read-out of this mode.
class OcptScheduleGroupsBand extends StatelessWidget {
  /// The day's own live groups, in `sortKey` order.
  final List<OcptShootingDayGroup> groups;

  /// How many live crew and cast rows of the day currently point at each group, keyed by id — a
  /// group with no entry here has no member at all (`OcptScheduleState.groupMemberCountsOfDay`'s
  /// own convention).
  final Map<String, int> memberCountByGroupId;

  /// Resolves a group's id to its own currently held label (a pending edit, or its stored value).
  final String Function(String groupId) labelValueOf;

  /// Called with a group's id and its raw label text on every keystroke, or null while withheld.
  final void Function(String groupId, String rawValue)? onLabelChanged;

  /// Called with a group's id and its own new lead time once committed, or null while withheld.
  final void Function(String groupId, int leadMinutes)? onLeadChanged;

  /// Called when the `+ Group` control is clicked, or null while withheld.
  final VoidCallback? onGroupAdded;

  /// Called with a group's id when its own delete control is clicked, or null while withheld.
  final ValueChanged<String>? onGroupDeletionRequested;

  /// Class constructor
  const OcptScheduleGroupsBand({
    super.key,
    required this.groups,
    required this.memberCountByGroupId,
    required this.labelValueOf,
    required this.onLabelChanged,
    required this.onLeadChanged,
    required this.onGroupAdded,
    required this.onGroupDeletionRequested,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(ocptRadiusMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tr.scheduleGroupsBandTitle.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(width: 6),
              Tooltip(
                message: tr.scheduleGroupsBandHelpTooltip,
                child: Icon(Icons.info_outline, size: 14, color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (groups.isEmpty)
            Text(
              tr.scheduleGroupsEmptyHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [for (final group in groups) _buildGroupCard(context, theme, tr, group)],
            ),
          if (onGroupAdded != null) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onGroupAdded,
              icon: const Icon(Icons.add, size: 16),
              label: Text(tr.scheduleAddGroupAction),
            ),
          ],
        ],
      ),
    );
  }

  /// One group's own card: its label, its lead time and its member count, over its own delete
  /// control.
  Widget _buildGroupCard(BuildContext context, ThemeData theme, Tr tr, OcptShootingDayGroup group) {
    final onLabelChanged = this.onLabelChanged;
    final labelValue = labelValueOf(group.id);
    final count = memberCountByGroupId[group.id] ?? 0;

    return Container(
      width: 230,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(ocptRadiusSmall),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: onLabelChanged == null
                    ? Text(
                        labelValue.isEmpty ? tr.scheduleGroupUnnamed : labelValue,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                      )
                    : _OcptScheduleGroupLabelField(
                        key: ValueKey(group.id),
                        value: labelValue,
                        hintText: tr.scheduleGroupUnnamed,
                        onChanged: (rawValue) => onLabelChanged(group.id, rawValue),
                      ),
              ),
              if (onGroupDeletionRequested != null)
                IconButton(
                  icon: const Icon(Icons.close, size: 14),
                  visualDensity: VisualDensity.compact,
                  tooltip: tr.scheduleDeleteGroupTooltip,
                  onPressed: () => onGroupDeletionRequested!(group.id),
                ),
            ],
          ),
          const SizedBox(height: 4),
          // A `Wrap` rather than a `Row` with a `Spacer`: the lead field's own suffix and the member
          // count together don't reliably fit one line at every text scale, and wrapping to a second
          // line reads far better than an overflow error.
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 2,
            children: [
              Text("${tr.scheduleLeadTimeLabel} ", style: theme.textTheme.labelSmall),
              OcptScheduleLeadField(
                leadMinutes: group.leadMinutes,
                isClearable: false,
                onChanged: onLeadChanged == null
                    ? null
                    // A group's own lead time is never null (`isClearable: false` above guarantees
                    // this callback is never invoked with one), so the non-nullable event this
                    // widget dispatches can read it back unwrapped.
                    : (value) => onLeadChanged!(group.id, value!),
              ),
              Text(
                tr.scheduleGroupMemberCount(count),
                style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A group card's own single-line label field, following the same controller-sync idiom as
/// `OcptScheduleSlotCard`'s own slot label field: [value] is the field's current authoritative
/// value, and the internal controller is only reset to it when it genuinely differs from what the
/// controller already holds, so the caret never jumps mid-typing.
class _OcptScheduleGroupLabelField extends StatefulWidget {
  /// The field's current authoritative value.
  final String value;

  /// The hint shown while [value] is empty.
  final String hintText;

  /// Called with the field's raw text on every keystroke.
  final ValueChanged<String> onChanged;

  /// Class constructor
  const _OcptScheduleGroupLabelField({
    super.key,
    required this.value,
    required this.hintText,
    required this.onChanged,
  });

  @override
  State<_OcptScheduleGroupLabelField> createState() => _OcptScheduleGroupLabelFieldState();
}

/// The state of [_OcptScheduleGroupLabelField]: owns the controller the class doc comment explains.
class _OcptScheduleGroupLabelFieldState extends State<_OcptScheduleGroupLabelField> {
  /// The field's own text editing controller, seeded from the widget's initial value and kept in
  /// sync with it afterward, see [didUpdateWidget].
  late final TextEditingController _controller = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(covariant _OcptScheduleGroupLabelField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    onChanged: widget.onChanged,
    style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
    decoration: InputDecoration(isDense: true, hintText: widget.hintText),
  );
}
