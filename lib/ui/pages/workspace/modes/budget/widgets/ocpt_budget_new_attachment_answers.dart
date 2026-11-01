// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/models/ocpt_budget_commitment_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_line.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_resource_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_share_form_fields.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_totals.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_commitment_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_gesture.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_gesture_attachment.dart';

/// Step 2's own answer — every field kept even while a different gesture is in effect, so
/// switching the gesture and switching back loses nothing.
///
/// The wizard's state owns one instance and mutates it inside its own `setState` calls.
class OcptBudgetNewAttachmentAnswers {
  /// The poste answered under `poste`/`optionalPoste`/`posteAndLine`, or null.
  String? posteId;

  /// Whether a `poste`/`optionalPoste` answer has been given at all — `optionalPoste`'s own `Hors
  /// devis` answers this true while leaving [posteId] null, which a bare null cannot tell apart
  /// from "nothing chosen yet".
  bool posteAnswered;

  /// The quote line answered under `posteAndLine`, or null.
  String? lineId;

  /// Whether `posteAndLine`'s own third answer, `Aucune`, was picked.
  bool lineNoneAnswered;

  /// The financing resource answered under `financingResource`, or null.
  String? resourceId;

  /// The taking answered under `taking`, or null.
  String? revenueId;

  /// The participant answered under `participant`, or null.
  String? shareId;

  /// The person answered under `person`, or null.
  String? personId;

  /// The financing resource step 2's own trailing row just collected, waiting to be created along
  /// with the movement, or null.
  OcptBudgetResourceFormFields? pendingNewResource;

  /// The participant step 2's own trailing row just collected, or null.
  OcptBudgetShareFormFields? pendingNewShare;

  /// Class constructor
  OcptBudgetNewAttachmentAnswers() : posteAnswered = false, lineNoneAnswered = false;

  /// Answers the poste, null standing for `Hors devis`.
  void selectPoste(String? posteId) {
    this.posteId = posteId;
    posteAnswered = true;
  }

  /// Takes the poste answer back, along with the line answered under it.
  void clearPoste() {
    posteAnswered = false;
    lineId = null;
    lineNoneAnswered = false;
  }

  /// Answers the quote line.
  void selectLine(String lineId) {
    this.lineId = lineId;
    lineNoneAnswered = false;
  }

  /// Answers `Aucune` to the quote line.
  void selectNoLine() {
    lineId = null;
    lineNoneAnswered = true;
  }

  /// Answers an existing financing resource, dropping the pending one.
  void selectResource(String resourceId) {
    this.resourceId = resourceId;
    pendingNewResource = null;
  }

  /// Answers a financing resource still to be created, dropping the existing one.
  void selectPendingResource(OcptBudgetResourceFormFields fields) {
    pendingNewResource = fields;
    resourceId = null;
  }

  /// Answers an existing participant, dropping the pending one.
  void selectShare(String shareId) {
    this.shareId = shareId;
    pendingNewShare = null;
  }

  /// Answers a participant still to be created, dropping the existing one.
  void selectPendingShare(OcptBudgetShareFormFields fields) {
    pendingNewShare = fields;
    shareId = null;
  }

  /// Whether step 2 has been answered for [gesture], which is what `Continue` waits for.
  bool isAnsweredFor(OcptBudgetGesture? gesture) {
    if (gesture == null) {
      return false;
    }

    return switch (ocptBudgetGestureAttachmentOf(gesture)) {
      OcptBudgetGestureAttachment.none => true,
      OcptBudgetGestureAttachment.poste ||
      OcptBudgetGestureAttachment.optionalPoste => posteAnswered,
      OcptBudgetGestureAttachment.posteAndLine =>
        posteAnswered && (lineId != null || lineNoneAnswered),
      OcptBudgetGestureAttachment.financingResource =>
        resourceId != null || pendingNewResource != null,
      OcptBudgetGestureAttachment.participant => shareId != null || pendingNewShare != null,
      OcptBudgetGestureAttachment.person => personId != null,
    };
  }

  /// The quote line [lineId] answered, searched across [postes], or null.
  OcptBudgetLine? lineIn(List<OcptBudgetPoste> postes) {
    final lineId = this.lineId;
    if (lineId == null) {
      return null;
    }
    for (final poste in postes) {
      final line = poste.lines.where((line) => line.id == lineId).firstOrNull;
      if (line != null) {
        return line;
      }
    }
    return null;
  }

  /// `commitSpend`'s own prefill when reached through the ordinary three-step flow (a poste, and
  /// optionally a line, just answered in step 2) — mirrors `budget_wizard_flows.dart`'s own
  /// `_handleLineCommitRequested`, everything the line already states carried across.
  OcptBudgetCommitmentFormFields? commitmentPrefillIn(List<OcptBudgetPoste> postes) {
    final posteId = this.posteId;
    if (posteId == null && !posteAnswered) {
      return null;
    }

    final line = lineNoneAnswered ? null : lineIn(postes);
    return OcptBudgetCommitmentFormFields(
      dueDate: null,
      label: line?.label ?? "",
      posteId: posteId ?? "",
      amountCents: line == null ? 0 : ocptBudgetLineTotalCents(line),
      isTaxInclusive: line?.unitPrice.isTaxInclusive ?? true,
      vatRateBasisPoints: line?.unitPrice.vatRateBasisPoints,
      status: OcptBudgetCommitmentStatus.quoteAccepted,
    );
  }
}
