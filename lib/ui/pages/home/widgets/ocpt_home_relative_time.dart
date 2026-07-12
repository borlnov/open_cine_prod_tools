// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <benoit.rolandeau@allcircuits.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/widgets.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';

/// Formats [dateTime] as a short, localized relative time compared to [now] (defaulting to
/// [DateTime.now]), for example "2 days ago"/"il y a 2 jours".
///
/// This is used to show a project card's last-opened date without the visual weight of a full
/// timestamp. It intentionally only has minute/hour/day resolution: nothing in this UI needs
/// second-level precision, and coarser buckets stay stable while a card is on screen.
String formatHomeRelativeTime(BuildContext context, DateTime dateTime, {DateTime? now}) {
  final tr = Tr.of(context);
  final difference = (now ?? DateTime.now()).difference(dateTime);

  if (difference.inMinutes < 1) {
    return tr.homeRelativeTimeJustNow;
  }
  if (difference.inHours < 1) {
    return tr.homeRelativeTimeMinutesAgo(difference.inMinutes);
  }
  if (difference.inDays < 1) {
    return tr.homeRelativeTimeHoursAgo(difference.inHours);
  }

  return tr.homeRelativeTimeDaysAgo(difference.inDays);
}
