// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/ui/widgets/ocpt_confirm_dialog.dart';

/// What the user chose in a dialog shown through [OcptConfirmDialog.showWithAlternative] — the
/// three-button extension [OcptConfirmDialog] takes on for an irreversible action that offers a
/// middle ground between doing nothing and destroying everything (e.g. removing a floor-plan set
/// element from one sequence versus deleting it everywhere).
///
/// [OcptConfirmDialog.show], the plain two-button call 35 other call sites already rely on, keeps
/// returning a plain `bool?` and never produces this type.
enum OcptConfirmDialogResult {
  /// The user dismissed the dialog without acting — the cancel button, or dismissing it any other
  /// way (a click outside it, `Escape`).
  cancelled,

  /// The user pressed the (possibly destructive) confirm action.
  confirmed,

  /// The user pressed the alternative action — a third choice short of [confirmed], e.g. "remove
  /// from this sequence" rather than "delete everywhere".
  alternative,
}
