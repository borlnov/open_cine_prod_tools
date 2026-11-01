// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/types/ocpt_schedule_centre_view.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_event.dart';

/// Select day [dayId] and switch the centre to the day view — the shared "open this day"
/// gesture the strip's own header click, a week column header click, a month cell click, a
/// positions matrix or presence grid column header click and an alert's own card all answer the
/// same way.
///
/// Selecting a day and switching the centre flush nothing: an edit typed before is written by its
/// own debounce.
void ocptScheduleOpenDay(BuildContext context, String dayId) {
  context.read<OcptScheduleBloc>()
    ..add(OcptScheduleDaySelectedEvent(dayId: dayId))
    ..add(const OcptScheduleCentreViewSelectedEvent(view: OcptScheduleCentreView.day));
}
