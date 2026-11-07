// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/types/ocpt_breakdown_target_kind.dart';

/// A tagged word's target selected by the caret/list, exactly as the bloc's own state holds it:
/// `(kind, id)`.
typedef OcptBreakdownSelectedTargetRef = (OcptBreakdownTargetKind, String)?;
