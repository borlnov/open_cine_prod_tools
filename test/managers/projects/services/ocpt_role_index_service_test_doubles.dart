// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:fountain_kit/fountain_kit.dart';

/// Parses [source] with the real Fountain parser, so reconciliation is exercised against a
/// realistic document rather than a hand-built one.
FountainDocument parse(String source) => const FountainParser().parse(source);
