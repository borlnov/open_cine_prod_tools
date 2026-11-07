// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// Which of the wizard's own three screens is currently drawn — mirrors
/// `_OcptBudgetEntryWizardStep`, one member wider.
enum OcptBudgetNewStep {
  /// Step 1: the fifteen answers, grouped by document.
  gesture,

  /// Step 2: what the movement attaches to — skipped outright for a gesture whose
  /// `OcptBudgetGestureAttachment` is `none`.
  attachment,

  /// Step 3: the money, or the form.
  form,
}
