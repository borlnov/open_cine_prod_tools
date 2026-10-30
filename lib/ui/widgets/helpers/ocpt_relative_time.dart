// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/widgets.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';

/// Formats [dateTime] as a short, localized relative time compared to [now] (defaulting to
/// [DateTime.now]), for example "2 days ago"/"il y a 2 jours".
///
/// It intentionally only has minute/hour/day resolution: this is meant for showing "roughly how
/// long ago" without the visual weight of a full timestamp, and coarser buckets stay stable while
/// shown on screen.
String formatRelativeTime(BuildContext context, DateTime dateTime, {DateTime? now}) {
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
