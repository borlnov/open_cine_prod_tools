// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// One resource's, one revenue's or one family's own `Promis`/`Rentré`/`Reste à venir`, in cents —
/// [receivedCents]/[outstandingCents] null wherever the figure cannot be read, see
/// `OcptBudgetFinancing`'s own class doc comment.
class OcptBudgetFinancingRowFigures {
  /// This row's own promised amount — always known.
  final int promisedCents;

  /// This row's own received amount, or null while it cannot be read.
  final int? receivedCents;

  /// This row's own outstanding amount, or null alongside [receivedCents].
  final int? outstandingCents;

  /// Class constructor
  const OcptBudgetFinancingRowFigures({
    required this.promisedCents,
    required this.receivedCents,
    required this.outstandingCents,
  });
}
