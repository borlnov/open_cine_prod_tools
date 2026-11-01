// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// The parts of the budget mode's shared data that a view can ask the mode to read again after it
/// wrote (`OcptBudgetBloc.reload`).
///
/// The mode reads them with an exhaustive `switch` over this enum, so a part nobody can ask for
/// or nobody reads does not compile. The page setup is not here: nothing in the mode writes it,
/// and only a whole load (entry, a version preview, a restore) reads it again.
enum OcptBudgetReloadScope {
  /// The whole budget read: the quote, the cash journal, the financing plan, the revenue sharing,
  /// the catering-and-travel pass and the catalogues (roles, people, elements, mileage rates) it
  /// is joined with. They make one snapshot, so no part of it can be read alone, and reading it
  /// again also reconciles the shared selection against what it now holds.
  snapshot,
}
