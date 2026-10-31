// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/ui/widgets/ocpt_view_switch.dart';

/// One segment of [OcptViewSwitch]: the value it selects and its own label.
class OcptViewSwitchSegment<T> {
  /// The value this segment selects when clicked.
  final T value;

  /// The segment's own label.
  final String label;

  /// Class constructor
  const OcptViewSwitchSegment({required this.value, required this.label});
}
