// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_guest.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_slot_note_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_slot_people_subsection_title.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_slot_person_card.dart';

/// The guests half of a slot card's second row: the slot's own live guests wrapped at [cardWidth],
/// then the `+ Guest` footer. It is drawn whether or not the slot holds a guest, exactly like the
/// two other kinds.
class OcptScheduleSlotGuestBand extends StatelessWidget {
  /// The slot's own live guests, in `sortKey` order.
  final List<OcptShootingSlotGuest> guests;

  /// The whole address book, keyed by id — what a guest row's own name is read off.
  final Map<String, OcptPerson> personById;

  /// The whole address book, in display order — what the `+ Guest` picker offers.
  final List<OcptPerson> people;

  /// The width every guest card claims.
  final double cardWidth;

  /// Called with the id of the person picked by the `+ Guest` footer, or null while withheld.
  final ValueChanged<String>? onGuestAdded;

  /// Called with a guest attendance's id when its row's remove control is clicked, or null while
  /// withheld.
  final ValueChanged<String>? onGuestRemoved;

  /// Resolves a guest attendance's id to its own reason, as currently held.
  final String Function(String guestId) guestReasonValueOf;

  /// Called with a guest attendance's id and its raw reason text on every keystroke, or null while
  /// withheld.
  final void Function(String guestId, String rawValue)? onGuestReasonChanged;

  /// Resolves a guest attendance's id to its own notes, as currently held.
  final String Function(String guestId) guestNotesValueOf;

  /// Called with a guest attendance's id and its raw note text on every keystroke, or null while
  /// withheld.
  final void Function(String guestId, String rawValue)? onGuestNotesChanged;

  /// Class constructor
  const OcptScheduleSlotGuestBand({
    super.key,
    required this.guests,
    required this.personById,
    required this.people,
    required this.cardWidth,
    required this.onGuestAdded,
    required this.onGuestRemoved,
    required this.guestReasonValueOf,
    required this.onGuestReasonChanged,
    required this.guestNotesValueOf,
    required this.onGuestNotesChanged,
  });

  /// Build the schedule slot guest band as a [Column].
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OcptScheduleSlotPeopleSubsectionTitle(
          title: tr.scheduleSlotGuestsColumnTitle,
          count: guests.length,
        ),
        const SizedBox(height: 7),
        if (guests.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              tr.scheduleSlotGuestsEmptyHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final guest in guests)
                  SizedBox(
                    width: cardWidth,
                    child: _GuestRow(
                      key: ValueKey(guest.id),
                      guest: guest,
                      person: guest.personId == null ? null : personById[guest.personId],
                      reasonValue: guestReasonValueOf(guest.id),
                      onReasonChanged: onGuestReasonChanged == null
                          ? null
                          : (value) => onGuestReasonChanged!(guest.id, value),
                      notesValue: guestNotesValueOf(guest.id),
                      onNotesChanged: onGuestNotesChanged == null
                          ? null
                          : (value) => onGuestNotesChanged!(guest.id, value),
                      onRemoved: onGuestRemoved == null ? null : () => onGuestRemoved!(guest.id),
                    ),
                  ),
              ],
            ),
          ),
        if (onGuestAdded != null)
          PopupMenuButton<String>(
            tooltip: "",
            onSelected: onGuestAdded,
            itemBuilder: (context) => [
              for (final person in people)
                PopupMenuItem<String>(
                  value: person.id,
                  child: Text(
                    person.displayName.isEmpty ? tr.resourcesUnnamedPerson : person.displayName,
                  ),
                ),
            ],
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add, size: 14),
                const SizedBox(width: 4),
                Text(tr.scheduleAddGuestAction, style: theme.textTheme.labelSmall),
              ],
            ),
          ),
      ],
    );
  }
}

/// One guest card of the guest band, built in the same [OcptScheduleSlotPersonCard] shell as the
/// crew and cast cards: the guest's own name and the remove control on the first line, then its
/// reason, then its notes — **no clock at all**, like every other convocation card (the hours are
/// read in the `Convocations` dock tab).
///
/// The name is a **read-out, never a picker**: a guest's identity is fixed the moment they are
/// added, exactly as a crew row's person and a cast row's role are. A row whose [guest]'s own
/// `personId` is null reads its `freeName` instead — defensively, since nothing in this app ever
/// mints a free-named guest (only the address book picker adds one), but a stored row is read back
/// as-is either way.
class _GuestRow extends StatelessWidget {
  /// The guest attendance this row shows.
  final OcptShootingSlotGuest guest;

  /// The address-book person [guest] names, or null while [guest] is free-named instead (or not yet
  /// loaded).
  final OcptPerson? person;

  /// The reason field's current authoritative value (a pending edit, or its stored value).
  final String reasonValue;

  /// Called with the reason field's raw text on every keystroke, or null while withheld.
  final ValueChanged<String>? onReasonChanged;

  /// The notes field's current authoritative value (a pending edit, or its stored value).
  final String notesValue;

  /// Called with the notes field's raw text on every keystroke, or null while withheld.
  final ValueChanged<String>? onNotesChanged;

  /// Called when this row's remove control is clicked, or null while withheld.
  final VoidCallback? onRemoved;

  /// Class constructor
  const _GuestRow({
    super.key,
    required this.guest,
    required this.person,
    required this.reasonValue,
    required this.onReasonChanged,
    required this.notesValue,
    required this.onNotesChanged,
    required this.onRemoved,
  });

  /// Build the guest row as an [OcptScheduleSlotPersonCard].
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final name = guest.personId != null
        ? (person?.displayName.isEmpty ?? true ? tr.resourcesUnnamedPerson : person!.displayName)
        : (guest.freeName.isEmpty ? tr.resourcesUnnamedPerson : guest.freeName);

    return OcptScheduleSlotPersonCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              if (onRemoved != null)
                IconButton(
                  icon: const Icon(Icons.close, size: 14),
                  visualDensity: VisualDensity.compact,
                  tooltip: tr.scheduleRemoveGuestTooltip,
                  onPressed: onRemoved,
                ),
            ],
          ),
          const SizedBox(height: 2),
          _GuestTextLine(
            guestId: guest.id,
            value: reasonValue,
            hintText: tr.scheduleSlotGuestReasonHint,
            onChanged: onReasonChanged,
            keySuffix: "reason",
          ),
          const SizedBox(height: 2),
          _GuestTextLine(
            guestId: guest.id,
            value: notesValue,
            hintText: tr.scheduleSlotGuestNotesHint,
            onChanged: onNotesChanged,
            keySuffix: "notes",
          ),
        ],
      ),
    );
  }
}

/// One of a guest row's own two free-text lines (reason, notes): [OcptScheduleSlotNoteField]'s own
/// controller-sync field while [onChanged] is non-null, or plain read-only text — drawing
/// **nothing at all** while empty, the same rule the slot's own note follows.
class _GuestTextLine extends StatelessWidget {
  /// The guest attendance the line belongs to, what its field's key is derived from.
  final String guestId;

  /// The line's current authoritative value.
  final String value;

  /// The hint shown while [value] is empty.
  final String hintText;

  /// Called with the field's raw text on every keystroke, or null while withheld.
  final ValueChanged<String>? onChanged;

  /// The suffix telling the reason line's key from the notes line's.
  final String keySuffix;

  /// Class constructor
  const _GuestTextLine({
    required this.guestId,
    required this.value,
    required this.hintText,
    required this.onChanged,
    required this.keySuffix,
  });

  /// Build the guest text line as an [OcptScheduleSlotNoteField].
  @override
  Widget build(BuildContext context) {
    final onChanged = this.onChanged;
    if (onChanged == null) {
      if (value.isEmpty) {
        return const SizedBox.shrink();
      }
      return Text(value, style: Theme.of(context).textTheme.bodySmall);
    }

    return OcptScheduleSlotNoteField(
      key: ValueKey("$guestId-$keySuffix"),
      value: value,
      hintText: hintText,
      onChanged: onChanged,
    );
  }
}
