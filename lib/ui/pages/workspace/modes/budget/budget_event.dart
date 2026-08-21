// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry_form_fields.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_centre_view.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_tax_basis.dart';

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
/// left-side counterpart: this mode has no left dock (`docs/plans/budget-mode.md` §5, M1).
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

/// Clears the cash journal view's own poste filter, dispatched by its top band's own `Remove
/// filter` action.
///
/// The filter **is** `OcptBudgetState.selectedPosteId` — there is no filter state of this view's
/// own — so clearing it here is exactly [OcptBudgetPosteSelectedEvent]'s own inverse, and carries
/// the very same, single meaning "no poste is selected" already carries everywhere else in this
/// mode: the `Inspector` tab, reading the very same field, empties out alongside the journal's own
/// filter, one fact read by two views rather than two facts that happen to agree.
class OcptBudgetCashJournalFilterClearedEvent extends OcptBudgetEvent {
  /// Class constructor
  const OcptBudgetCashJournalFilterClearedEvent();
}
