// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_allowance_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_cash_journal_xlsx_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_commitment_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_financial_report_export_options.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_financial_report_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_financing_plan_export_options.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_financing_plan_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_quote_export_options.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_quote_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_resource_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_revenue_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_share_form_fields.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_centre_view.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_tax_basis.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_provision.dart';

/// The events handled by `OcptBudgetBloc`.
sealed class OcptBudgetEvent extends BlocEventForMixin {
  /// Class constructor
  const OcptBudgetEvent();
}

/// Requests loading the current project's whole quote read: the postes with their lines (seeded on
/// first read), the project's currency and default VAT rate.
///
/// Dispatched once by the bloc's own constructor; it isn't meant to be sent by a widget.
class OcptBudgetLoadRequestedEvent extends OcptBudgetEvent {
  /// Class constructor
  const OcptBudgetLoadRequestedEvent();
}

/// Requests leaving the workspace: closes the current project and navigates back to the home page.
class OcptBudgetBackRequestedEvent extends OcptBudgetEvent {
  /// Class constructor
  const OcptBudgetBackRequestedEvent();
}

/// Selects a tab of the right dock (the already-active tab closes the dock, any other one opens or
/// switches to it).
class OcptBudgetRightDockTabSelectedEvent extends OcptBudgetEvent {
  /// The tab to select.
  final OcptBudgetRightDockTab tab;

  /// Class constructor
  const OcptBudgetRightDockTabSelectedEvent({required this.tab});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, tab];
}

/// Toggles the right dock from the workspace toolbar: an open dock closes, a closed one reopens on
/// its last tab.
class OcptBudgetRightDockToggledEvent extends OcptBudgetEvent {
  /// Class constructor
  const OcptBudgetRightDockToggledEvent();
}

/// Closes the right dock via its own × close button.
class OcptBudgetRightDockClosedEvent extends OcptBudgetEvent {
  /// Class constructor
  const OcptBudgetRightDockClosedEvent();
}

/// Applies and persists the right dock's new width fraction once a divider drag ends. There is no
/// left-side counterpart: this mode has no left dock (`docs/architecture/budget.md`).
class OcptBudgetRightDockFractionChangedEvent extends OcptBudgetEvent {
  /// The right dock's new fraction of the mode's content row width.
  final double fraction;

  /// Class constructor
  const OcptBudgetRightDockFractionChangedEvent({required this.fraction});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, fraction];
}

/// Selects which of the two centre views the mode shows, dispatched by the header's own view
/// chips.
class OcptBudgetCentreViewSelectedEvent extends OcptBudgetEvent {
  /// The view to select.
  final OcptBudgetCentreView view;

  /// Class constructor
  const OcptBudgetCentreViewSelectedEvent({required this.view});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, view];
}

/// Toggles the header's simplified/detailed switch. Session-only, never persisted, mirroring the
/// schedule mode's own agenda mode.
class OcptBudgetSimplifiedToggledEvent extends OcptBudgetEvent {
  /// The switch's new value.
  final bool isSimplified;

  /// Class constructor
  const OcptBudgetSimplifiedToggledEvent({required this.isSimplified});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, isSimplified];
}

/// Switches the header's excluding/including-tax toggle — the **display** basis alone, never
/// written anywhere (`OcptBudgetTaxBasis`'s own doc comment). Session-only, never persisted.
class OcptBudgetTaxBasisChangedEvent extends OcptBudgetEvent {
  /// The basis to read every amount in from now on.
  final OcptBudgetTaxBasis basis;

  /// Class constructor
  const OcptBudgetTaxBasisChangedEvent({required this.basis});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, basis];
}

/// Selects poste [posteId] — a cost-tracking row, or a dashboard bar — opening the right dock on
/// the `Inspector` tab, mirroring `OcptScheduleShotSelectedEvent`'s own gesture. A [posteId] naming
/// no live poste is ignored.
class OcptBudgetPosteSelectedEvent extends OcptBudgetEvent {
  /// The id of the poste to select.
  final String posteId;

  /// Class constructor
  const OcptBudgetPosteSelectedEvent({required this.posteId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, posteId];
}

/// Creates a new, unnamed poste, appended at the end of the catalogue, and selects it — dispatched
/// by the cost-tracking table's own `+ Poste` footer. Mirrors `OcptResourcesElementCreationRequestedEvent`:
/// a fresh record is created empty, its own sheet's placeholder reading it as unnamed until
/// somebody types into it.
class OcptBudgetPosteCreatedEvent extends OcptBudgetEvent {
  /// Class constructor
  const OcptBudgetPosteCreatedEvent();
}

/// Moves poste [posteId] to [newPosition] (0-based) within the catalogue's flat order, dispatched
/// by a row's own `⋮` menu `▲`/`▼` entries.
class OcptBudgetPosteReorderedEvent extends OcptBudgetEvent {
  /// The id of the poste to reorder.
  final String posteId;

  /// The 0-based position the poste is moved to.
  final int newPosition;

  /// Class constructor
  const OcptBudgetPosteReorderedEvent({required this.posteId, required this.newPosition});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, posteId, newPosition];
}

/// Deletes poste [posteId] for good, along with every quote line it holds, dispatched by the mode
/// once its `OcptConfirmDialog` has already been answered.
class OcptBudgetPosteDeletionConfirmedEvent extends OcptBudgetEvent {
  /// The id of the poste to delete.
  final String posteId;

  /// Class constructor
  const OcptBudgetPosteDeletionConfirmedEvent({required this.posteId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, posteId];
}

/// Expands or collapses quote line [lineId]'s own card in the poste inspector — the already-expanded
/// line collapses back, any other one expands and replaces whichever was open, at most one line
/// ever expanded at a time.
class OcptBudgetLineExpandedEvent extends OcptBudgetEvent {
  /// The id of the line whose card was clicked.
  final String lineId;

  /// Class constructor
  const OcptBudgetLineExpandedEvent({required this.lineId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, lineId];
}

/// Creates a new, unnamed quote line inside poste [posteId], appended at the end of its own lines,
/// and expands it — dispatched by the poste inspector's own `+ Add` action, mirroring
/// `OcptBudgetPosteCreatedEvent`'s own "created empty" idiom.
class OcptBudgetLineCreatedEvent extends OcptBudgetEvent {
  /// The id of the poste the new line belongs to.
  final String posteId;

  /// Class constructor
  const OcptBudgetLineCreatedEvent({required this.posteId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, posteId];
}

/// Creates a new quote line inside poste [posteId] **from** breakdown element [elementId], and
/// expands it — dispatched by the poste inspector's own `+ From breakdown` action once
/// `OcptBudgetElementPickerDialog` returned an element, mirroring `OcptBudgetLineCreatedEvent`'s own
/// "written the moment it is dispatched" reading. See `OcptBudgetBloc._onLineCreatedFromElement`'s
/// own doc comment for what this writes onto the fresh line beyond its label.
class OcptBudgetLineCreatedFromElementEvent extends OcptBudgetEvent {
  /// The id of the poste the new line belongs to.
  final String posteId;

  /// The id of the breakdown element the new line prices.
  final String elementId;

  /// Class constructor
  const OcptBudgetLineCreatedFromElementEvent({required this.posteId, required this.elementId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, posteId, elementId];
}

/// Deletes quote line [lineId] for good, dispatched by the mode once its `OcptConfirmDialog` has
/// already been answered.
class OcptBudgetLineDeletionConfirmedEvent extends OcptBudgetEvent {
  /// The id of the line to delete.
  final String lineId;

  /// Class constructor
  const OcptBudgetLineDeletionConfirmedEvent({required this.lineId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, lineId];
}

/// Writes a new including/excluding-tax basis onto line [lineId]'s own unit price immediately,
/// dispatched by its expanded card's own radio — a pick, not typing, so it never rides the
/// field-edit debounce.
class OcptBudgetLineTaxInclusiveChangedEvent extends OcptBudgetEvent {
  /// The id of the line being edited.
  final String lineId;

  /// Whether the price just picked includes tax.
  final bool isTaxInclusive;

  /// Class constructor
  const OcptBudgetLineTaxInclusiveChangedEvent({required this.lineId, required this.isTaxInclusive});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, lineId, isTaxInclusive];
}

/// Puts line [lineId]'s own VAT rate back to inheriting the project's default, dispatched by its
/// expanded card's own `Inherit` action — the field's dedicated way back to null, exactly as the
/// project settings' own `No rate` button is for `defaultVatRateBasisPoints`
/// (`OcptBudgetField`'s own doc comment explains why an empty typed submission cannot mean this).
/// Written immediately, never through the field-edit debounce.
class OcptBudgetLineVatRateInheritedRequestedEvent extends OcptBudgetEvent {
  /// The id of the line being edited.
  final String lineId;

  /// Class constructor
  const OcptBudgetLineVatRateInheritedRequestedEvent({required this.lineId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, lineId];
}

/// Records the raw text just typed into [field] of entity [targetId] as a pending edit, dispatched
/// on every keystroke into a poste's or a line's own free-text field — rides `OcptBudgetBloc`'s own
/// 2 s field-edit debounce.
class OcptBudgetFieldChangedEvent extends OcptBudgetEvent {
  /// The id of the poste or line being edited, according to [field].
  final String targetId;

  /// Which field is being edited.
  final OcptBudgetField field;

  /// The field's raw text, as typed.
  final String rawValue;

  /// Class constructor
  const OcptBudgetFieldChangedEvent({
    required this.targetId,
    required this.field,
    required this.rawValue,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, targetId, field, rawValue];
}

/// Fired by the field-edit debounce timer once it elapses with no further typing: writes every
/// pending field edit. Not meant to be dispatched by a widget; the bloc dispatches it itself.
class OcptBudgetFieldEditFlushRequestedEvent extends OcptBudgetEvent {
  /// Class constructor
  const OcptBudgetFieldEditFlushRequestedEvent();
}

/// Re-reads the project's currency and default VAT rate after the project settings page changed
/// something — mirrors `OcptScheduleProjectSettingsChangedEvent` for the same reason: the settings
/// page is exactly where both are changed.
class OcptBudgetProjectSettingsChangedEvent extends OcptBudgetEvent {
  /// Class constructor
  const OcptBudgetProjectSettingsChangedEvent();
}

/// Creates a new cash-journal entry from [fields], dispatched by the mode once
/// `OcptBudgetEntryDialog` returned a result for a fresh entry — mirrors `OcptBudgetLineCreatedEvent`'s
/// own "written the moment it is dispatched" reading: none of this dialog's fields is typing, so
/// none of them rides the field-edit debounce.
class OcptBudgetEntryCreationConfirmedEvent extends OcptBudgetEvent {
  /// Every field the dialog collected.
  final OcptBudgetEntryFormFields fields;

  /// Class constructor
  const OcptBudgetEntryCreationConfirmedEvent({required this.fields});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, fields];
}

/// Writes [fields] onto entry [entryId], dispatched by the mode once `OcptBudgetEntryDialog`
/// returned a result for an existing entry it was opened to edit.
class OcptBudgetEntryUpdateConfirmedEvent extends OcptBudgetEvent {
  /// The id of the entry being edited.
  final String entryId;

  /// Every field the dialog collected.
  final OcptBudgetEntryFormFields fields;

  /// Class constructor
  const OcptBudgetEntryUpdateConfirmedEvent({required this.entryId, required this.fields});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, entryId, fields];
}

/// Deletes cash-journal entry [entryId] for good, dispatched by the mode once its own
/// `OcptConfirmDialog` has already been answered — mirrors `OcptBudgetLineDeletionConfirmedEvent`.
class OcptBudgetEntryDeletionConfirmedEvent extends OcptBudgetEvent {
  /// The id of the entry to delete.
  final String entryId;

  /// Class constructor
  const OcptBudgetEntryDeletionConfirmedEvent({required this.entryId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, entryId];
}

/// Narrows every view of the mode to poste [posteId], or clears the filter when it is null —
/// dispatched by the header's own poste filter, the only control that sets it.
///
/// **Not [OcptBudgetPosteSelectedEvent]'s inverse, and no longer the same field.** The filter used
/// to *be* `OcptBudgetState.selectedPosteId`, which meant clicking a row in the quote silently
/// narrowed the cash journal — a view the reader was not looking at, so they discovered it on
/// arriving there, with no obvious way back. Selecting and filtering are now two facts:
/// [OcptBudgetPosteSelectedEvent] says what the inspector reads,
/// `OcptBudgetState.filterPosteId` says what every view is narrowed to, and only a gesture
/// that says "filter" sets it.
class OcptBudgetPosteFilterSelectedEvent extends OcptBudgetEvent {
  /// The poste to narrow every view to, or null to go back to the whole project.
  final String? posteId;

  /// Class constructor
  const OcptBudgetPosteFilterSelectedEvent({required this.posteId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, posteId];
}

/// Creates a new commitment from [fields], dispatched by the mode once
/// `OcptBudgetCommitmentDialog` returned a result for a fresh commitment — mirrors
/// `OcptBudgetEntryCreationConfirmedEvent`'s own "written the moment it is dispatched" reading.
class OcptBudgetCommitmentCreationConfirmedEvent extends OcptBudgetEvent {
  /// Every field the dialog collected.
  final OcptBudgetCommitmentFormFields fields;

  /// The quote line this commitment was promoted from, or null when it was typed from scratch —
  /// the ordinary case, and the only one the `+ Commitment` button produces.
  ///
  /// **Not part of [fields], and deliberately.** The dialog collects what a user typed; this is
  /// where the movement came from, which the dialog neither knows nor asks about. Keeping it out
  /// also keeps the dialog usable, unchanged, for a commitment that has no line behind it.
  final String? lineId;

  /// Class constructor
  const OcptBudgetCommitmentCreationConfirmedEvent({required this.fields, this.lineId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, fields, lineId];
}

/// Writes [fields] onto commitment [commitmentId], dispatched by the mode once
/// `OcptBudgetCommitmentDialog` returned a result for an existing commitment it was opened to edit.
/// [fields]' own `posteId` is never sent on: `OcptBudgetJournalService.updateCommitment` carries no
/// such parameter, a commitment's own poste being fixed the moment it is created
/// (`OcptBudgetCommitmentFormFields.posteId`'s own doc comment).
class OcptBudgetCommitmentUpdateConfirmedEvent extends OcptBudgetEvent {
  /// The id of the commitment being edited.
  final String commitmentId;

  /// Every field the dialog collected.
  final OcptBudgetCommitmentFormFields fields;

  /// Class constructor
  const OcptBudgetCommitmentUpdateConfirmedEvent({required this.commitmentId, required this.fields});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, commitmentId, fields];
}

/// Deletes commitment [commitmentId] for good, dispatched by the mode once its own
/// `OcptConfirmDialog` has already been answered — mirrors
/// `OcptBudgetEntryDeletionConfirmedEvent`.
class OcptBudgetCommitmentDeletionConfirmedEvent extends OcptBudgetEvent {
  /// The id of the commitment to delete.
  final String commitmentId;

  /// Class constructor
  const OcptBudgetCommitmentDeletionConfirmedEvent({required this.commitmentId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, commitmentId];
}

/// Records commitment [commitmentId]'s own payment, dispatched by the mode once
/// `OcptBudgetEntryDialog` returned a result for the fresh entry it was opened pre-filled with, from
/// its row's own `Settle` action. The bloc creates the journal entry [fields] describes **and**
/// points the commitment's own `settledEntryId` at it, in the one handler this event reaches, then
/// reloads once — one dispatched event, two writes.
class OcptBudgetCommitmentSettlementConfirmedEvent extends OcptBudgetEvent {
  /// The id of the commitment being settled.
  final String commitmentId;

  /// Every field the entry dialog collected for the payment itself.
  final OcptBudgetEntryFormFields fields;

  /// Class constructor
  const OcptBudgetCommitmentSettlementConfirmedEvent({
    required this.commitmentId,
    required this.fields,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, commitmentId, fields];
}

/// Undoes commitment [commitmentId]'s own settlement, dispatched by its row's own `Undo settlement`
/// action — clears `settledEntryId` back to null alone. **The journal entry it named is never
/// touched**: it is a movement that either happened or did not, and the journal is where it is
/// deleted, if it should be — this event only forgets the link, not the payment.
class OcptBudgetCommitmentUnsettleRequestedEvent extends OcptBudgetEvent {
  /// The id of the commitment to unsettle.
  final String commitmentId;

  /// Class constructor
  const OcptBudgetCommitmentUnsettleRequestedEvent({required this.commitmentId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, commitmentId];
}

/// Selects financing resource [resourceId] — a row of the financing view — dispatched by its row's
/// own click. Draws as a plain highlight, never an inspector: see `OcptBudgetFinancing`'s own class
/// doc comment. A [resourceId] naming no live resource is ignored, mirroring
/// `OcptBudgetPosteSelectedEvent`.
class OcptBudgetResourceSelectedEvent extends OcptBudgetEvent {
  /// The id of the resource to select.
  final String resourceId;

  /// Class constructor
  const OcptBudgetResourceSelectedEvent({required this.resourceId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, resourceId];
}

/// Creates a new defrayal from [fields], dispatched by the mode once `OcptBudgetAllowanceDialog`
/// returned a result for a fresh one — mirrors `OcptBudgetResourceCreationConfirmedEvent`.
class OcptBudgetAllowanceCreationConfirmedEvent extends OcptBudgetEvent {
  /// Every field the dialog collected.
  final OcptBudgetAllowanceFormFields fields;

  /// Class constructor
  const OcptBudgetAllowanceCreationConfirmedEvent({required this.fields});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, fields];
}

/// Writes [fields] onto defrayal [allowanceId], dispatched by the mode once
/// `OcptBudgetAllowanceDialog` returned a result for an existing one it was opened to edit.
class OcptBudgetAllowanceUpdateConfirmedEvent extends OcptBudgetEvent {
  /// The id of the defrayal being edited.
  final String allowanceId;

  /// Every field the dialog collected.
  final OcptBudgetAllowanceFormFields fields;

  /// Class constructor
  const OcptBudgetAllowanceUpdateConfirmedEvent({required this.allowanceId, required this.fields});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, allowanceId, fields];
}

/// Deletes defrayal [allowanceId] for good, dispatched by the mode once its own `OcptConfirmDialog`
/// has already been answered.
class OcptBudgetAllowanceDeletionConfirmedEvent extends OcptBudgetEvent {
  /// The id of the defrayal to delete.
  final String allowanceId;

  /// Class constructor
  const OcptBudgetAllowanceDeletionConfirmedEvent({required this.allowanceId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, allowanceId];
}

/// Points the régie view's own provisioning at poste [posteId] — a selection, written to no
/// project and remembered for as long as the mode is open.
class OcptBudgetProvisionPosteSelectedEvent extends OcptBudgetEvent {
  /// The id of the poste just picked.
  final String posteId;

  /// Class constructor
  const OcptBudgetProvisionPosteSelectedEvent({required this.posteId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, posteId];
}

/// Carries out [entries] against poste [posteId], dispatched by the mode once its own
/// `OcptConfirmDialog` has put the plan's own counts in front of the user and they agreed.
///
/// **The plan travels with the event rather than being recomputed here**, and deliberately: it is
/// what the user was shown and said yes to, and a plan recomputed after the fact could differ from
/// the one they agreed to. Its wordings are resolved by the mode, no bloc of this app ever seeing a
/// `Tr`.
class OcptBudgetProvisionConfirmedEvent extends OcptBudgetEvent {
  /// The poste the lines are written onto.
  final String posteId;

  /// Everything the provisioning would do, exactly as the user was shown it.
  final List<OcptBudgetProvisionEntry> entries;

  /// Class constructor
  const OcptBudgetProvisionConfirmedEvent({required this.posteId, required this.entries});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, posteId, entries];
}

/// Creates a new financing resource from [fields], dispatched by the mode once
/// `OcptBudgetResourceDialog` returned a result for a fresh resource — mirrors
/// `OcptBudgetCommitmentCreationConfirmedEvent`'s own "written the moment it is dispatched"
/// reading.
class OcptBudgetResourceCreationConfirmedEvent extends OcptBudgetEvent {
  /// Every field the dialog collected.
  final OcptBudgetResourceFormFields fields;

  /// Class constructor
  const OcptBudgetResourceCreationConfirmedEvent({required this.fields});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, fields];
}

/// Writes [fields] onto resource [resourceId], dispatched by the mode once
/// `OcptBudgetResourceDialog` returned a result for an existing resource it was opened to edit.
class OcptBudgetResourceUpdateConfirmedEvent extends OcptBudgetEvent {
  /// The id of the resource being edited.
  final String resourceId;

  /// Every field the dialog collected.
  final OcptBudgetResourceFormFields fields;

  /// Class constructor
  const OcptBudgetResourceUpdateConfirmedEvent({required this.resourceId, required this.fields});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, resourceId, fields];
}

/// Deletes financing resource [resourceId] for good, dispatched by the mode once its own
/// `OcptConfirmDialog` has already been answered — mirrors
/// `OcptBudgetCommitmentDeletionConfirmedEvent`.
class OcptBudgetResourceDeletionConfirmedEvent extends OcptBudgetEvent {
  /// The id of the resource to delete.
  final String resourceId;

  /// Class constructor
  const OcptBudgetResourceDeletionConfirmedEvent({required this.resourceId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, resourceId];
}

/// Selects revenue sharing taking [revenueId] — a row of the sharing view's own left column —
/// dispatched by its row's own click. Draws as a plain highlight, never an inspector, mirroring
/// `OcptBudgetResourceSelectedEvent`. A [revenueId] naming no live revenue is ignored.
class OcptBudgetRevenueSelectedEvent extends OcptBudgetEvent {
  /// The id of the revenue to select.
  final String revenueId;

  /// Class constructor
  const OcptBudgetRevenueSelectedEvent({required this.revenueId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, revenueId];
}

/// Creates a new taking from [fields], dispatched by the mode once `OcptBudgetRevenueDialog`
/// returned a result for a fresh revenue — mirrors `OcptBudgetResourceCreationConfirmedEvent`'s own
/// "written the moment it is dispatched" reading.
class OcptBudgetRevenueCreationConfirmedEvent extends OcptBudgetEvent {
  /// Every field the dialog collected.
  final OcptBudgetRevenueFormFields fields;

  /// Class constructor
  const OcptBudgetRevenueCreationConfirmedEvent({required this.fields});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, fields];
}

/// Writes [fields] onto revenue [revenueId], dispatched by the mode once
/// `OcptBudgetRevenueDialog` returned a result for an existing revenue it was opened to edit.
class OcptBudgetRevenueUpdateConfirmedEvent extends OcptBudgetEvent {
  /// The id of the revenue being edited.
  final String revenueId;

  /// Every field the dialog collected.
  final OcptBudgetRevenueFormFields fields;

  /// Class constructor
  const OcptBudgetRevenueUpdateConfirmedEvent({required this.revenueId, required this.fields});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, revenueId, fields];
}

/// Moves revenue [revenueId] to [newPosition] (0-based) within the sharing view's own flat order,
/// dispatched by a row's own `⋮` menu `▲`/`▼` entries — mirrors `OcptBudgetPosteReorderedEvent`.
class OcptBudgetRevenueReorderedEvent extends OcptBudgetEvent {
  /// The id of the revenue to reorder.
  final String revenueId;

  /// The 0-based position the revenue is moved to.
  final int newPosition;

  /// Class constructor
  const OcptBudgetRevenueReorderedEvent({required this.revenueId, required this.newPosition});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, revenueId, newPosition];
}

/// Deletes taking [revenueId] for good, dispatched by the mode once its own `OcptConfirmDialog`
/// has already been answered — mirrors `OcptBudgetResourceDeletionConfirmedEvent`.
class OcptBudgetRevenueDeletionConfirmedEvent extends OcptBudgetEvent {
  /// The id of the revenue to delete.
  final String revenueId;

  /// Class constructor
  const OcptBudgetRevenueDeletionConfirmedEvent({required this.revenueId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, revenueId];
}

/// Selects share [shareId] — a row of the sharing view's own `Distribution` table — dispatched by
/// its row's own click. Draws as a plain highlight, never an inspector, mirroring
/// `OcptBudgetRevenueSelectedEvent`. A [shareId] naming no live share is ignored.
class OcptBudgetShareSelectedEvent extends OcptBudgetEvent {
  /// The id of the share to select.
  final String shareId;

  /// Class constructor
  const OcptBudgetShareSelectedEvent({required this.shareId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, shareId];
}

/// Creates a new share from [fields], dispatched by the mode once `OcptBudgetShareDialog` returned
/// a result for a fresh share — mirrors `OcptBudgetRevenueCreationConfirmedEvent`.
class OcptBudgetShareCreationConfirmedEvent extends OcptBudgetEvent {
  /// Every field the dialog collected.
  final OcptBudgetShareFormFields fields;

  /// Class constructor
  const OcptBudgetShareCreationConfirmedEvent({required this.fields});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, fields];
}

/// Writes [fields] onto share [shareId], dispatched by the mode once `OcptBudgetShareDialog`
/// returned a result for an existing share it was opened to edit.
class OcptBudgetShareUpdateConfirmedEvent extends OcptBudgetEvent {
  /// The id of the share being edited.
  final String shareId;

  /// Every field the dialog collected.
  final OcptBudgetShareFormFields fields;

  /// Class constructor
  const OcptBudgetShareUpdateConfirmedEvent({required this.shareId, required this.fields});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, shareId, fields];
}

/// Moves share [shareId] to [newPosition] (0-based) within the sharing view's own flat order,
/// dispatched by a row's own `⋮` menu `▲`/`▼` entries — mirrors `OcptBudgetRevenueReorderedEvent`.
class OcptBudgetShareReorderedEvent extends OcptBudgetEvent {
  /// The id of the share to reorder.
  final String shareId;

  /// The 0-based position the share is moved to.
  final int newPosition;

  /// Class constructor
  const OcptBudgetShareReorderedEvent({required this.shareId, required this.newPosition});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, shareId, newPosition];
}

/// Deletes share [shareId] for good, dispatched by the mode once its own `OcptConfirmDialog` has
/// already been answered — mirrors `OcptBudgetRevenueDeletionConfirmedEvent`.
class OcptBudgetShareDeletionConfirmedEvent extends OcptBudgetEvent {
  /// The id of the share to delete.
  final String shareId;

  /// Class constructor
  const OcptBudgetShareDeletionConfirmedEvent({required this.shareId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, shareId];
}

/// Requests exporting the quote as a single PDF, written through the native save dialog —
/// dispatched once `OcptBudgetQuoteExportDialog` returns its result.
class OcptBudgetQuoteExportRequestedEvent extends OcptBudgetEvent {
  /// The one-off options the export runs with (the page format/margins, the title page toggle and
  /// the tax basis every line and total is printed in).
  final OcptBudgetQuoteExportOptions options;

  /// Every localized string the exported document carries.
  final OcptBudgetQuoteLabels labels;

  /// Every breakdown element a live quote line prices, keyed by its own id — resolved by the mode,
  /// which has the whole catalogue on state; the bloc has no `Tr` of its own but does carry the
  /// catalogue, so this still travels on the event exactly as `labels` does, for the same reason
  /// nothing in this event ever needs a `BuildContext`.
  final Map<String, String> elementNameById;

  /// The localized label passed to the native save dialog's own type filter.
  final String fileTypeLabel;

  /// Class constructor
  const OcptBudgetQuoteExportRequestedEvent({
    required this.options,
    required this.labels,
    required this.elementNameById,
    required this.fileTypeLabel,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, options, labels, elementNameById, fileTypeLabel];
}

/// Requests exporting the financing plan as a single PDF, written through the native save dialog —
/// dispatched once `OcptBudgetFinancingPlanExportDialog` returns its result.
class OcptBudgetFinancingPlanExportRequestedEvent extends OcptBudgetEvent {
  /// The one-off options the export runs with (the page format/margins and the title page toggle).
  final OcptBudgetFinancingPlanExportOptions options;

  /// Every localized string the exported document carries.
  final OcptBudgetFinancingPlanLabels labels;

  /// The localized label passed to the native save dialog's own type filter.
  final String fileTypeLabel;

  /// Class constructor
  const OcptBudgetFinancingPlanExportRequestedEvent({
    required this.options,
    required this.labels,
    required this.fileTypeLabel,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, options, labels, fileTypeLabel];
}

/// Requests exporting the cash journal as a single XLSX workbook, written through the native save
/// dialog — dispatched the moment its own card is picked, this export taking no options dialog of
/// its own.
class OcptBudgetCashJournalExportRequestedEvent extends OcptBudgetEvent {
  /// Every localized string the exported workbook carries.
  final OcptBudgetCashJournalXlsxLabels labels;

  /// What each live entry settles, keyed by its own id — a resource, a taking or a share's own
  /// label, resolved by the mode: this service resolves nothing itself
  /// (`OcptBudgetCashJournalXlsxExportService`'s own doc comment).
  final Map<String, String> linkLabelByEntryId;

  /// The localized label passed to the native save dialog's own type filter.
  final String fileTypeLabel;

  /// Class constructor
  const OcptBudgetCashJournalExportRequestedEvent({
    required this.labels,
    required this.linkLabelByEntryId,
    required this.fileTypeLabel,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, labels, linkLabelByEntryId, fileTypeLabel];
}

/// Requests exporting the financial report as a single PDF, written through the native save
/// dialog — dispatched once `OcptBudgetFinancialReportExportDialog` returns its result.
class OcptBudgetFinancialReportExportRequestedEvent extends OcptBudgetEvent {
  /// The one-off options the export runs with (the page format/margins and the title page toggle).
  final OcptBudgetFinancialReportExportOptions options;

  /// Every localized string the exported document carries.
  final OcptBudgetFinancialReportLabels labels;

  /// The localized label passed to the native save dialog's own type filter.
  final String fileTypeLabel;

  /// Class constructor
  const OcptBudgetFinancialReportExportRequestedEvent({
    required this.options,
    required this.labels,
    required this.fileTypeLabel,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, options, labels, fileTypeLabel];
}

/// Clears the transient export notice currently shown, if any.
class OcptBudgetIoNoticeDismissedEvent extends OcptBudgetEvent {
  /// Class constructor
  const OcptBudgetIoNoticeDismissedEvent();
}
