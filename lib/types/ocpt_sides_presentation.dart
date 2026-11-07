// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/models/ocpt_script_sides_layout.dart';

/// Which shape a sides booklet is printed in — see [OcptScriptSidesLayout] for what each one keeps
/// and what it gives up.
enum OcptSidesPresentation {
  /// One output page per composed script page holding at least one selected row, laid out exactly
  /// as the screenplay itself prints it — a reader recognises the page they already know.
  scriptPages,

  /// The selected rows alone, reflowed onto fresh pages with nothing of the screenplay's own
  /// pagination between them — a shorter booklet, at the cost of no longer looking like a
  /// particular page of the script.
  packed,
}
