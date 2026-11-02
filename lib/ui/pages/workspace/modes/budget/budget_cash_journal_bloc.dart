// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:drift/drift.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_budget_financing_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_budget_journal_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_budget_quote_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_budget_sharing_service.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_open_project_model.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_journal.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_projection.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_reload_scope.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/abs_ocpt_view_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_cash_journal_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_form_writes.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_state.dart';

/// This is the bloc class for the budget mode's cash journal: the entries, the commitments, and
/// the ways a spend is reconciled with the quote.
///
/// The entries and the commitments are the mode's data, in `OcptBudgetState.snapshot`, and which
/// row is selected is the mode's too. This bloc owns every write the view triggers: the service
/// (several in a row for a payment that settles a commitment, a promotion into the quote or an
/// entry that names a resource, a taking or a share still to be made), then
/// `await modeBloc.reload(…)`. Nothing here is typed into a debounce, so it registers nothing to
/// flush and reacts to nothing the mode does; and none of its handlers selects the row it wrote.
///
/// **A write that fails is not caught.** The service's error stops the handler, so the writes that
/// came before it stay in the database and the snapshot is not read again — a payment whose entry
/// could not be written leaves the commitment it was recorded against behind.
class OcptBudgetCashJournalBloc
    extends AbsOcptViewBloc<OcptBudgetCashJournalState, OcptBudgetState, OcptBudgetBloc> {
  /// The manager used to access the project currently open.
  final OcptProjectsManager _projectsManager;

  /// The service used to read and write the cash journal: the entries, the commitments and the
  /// vouchers.
  final OcptBudgetJournalService _budgetJournalService;

  /// The service used to write the quote lines a promotion into the quote mints.
  final OcptBudgetQuoteService _budgetQuoteService;

  /// The service used to write the financing resource an entry's dialog offers to create.
  final OcptBudgetFinancingService _budgetFinancingService;

  /// The service used to write the taking and the share an entry's dialog offers to create.
  final OcptBudgetSharingService _budgetSharingService;

  /// Class constructor
  ///
  /// Every dependency but [modeBloc] can be overridden, which is what the tests do; in the app they
  /// all resolve through [globalGetIt].
  OcptBudgetCashJournalBloc({
    required super.modeBloc,
    OcptProjectsManager? projectsManager,
    OcptBudgetJournalService? budgetJournalService,
    OcptBudgetQuoteService? budgetQuoteService,
    OcptBudgetFinancingService? budgetFinancingService,
    OcptBudgetSharingService? budgetSharingService,
  }) : _projectsManager = projectsManager ?? globalGetIt().get<OcptProjectsManager>(),
       _budgetJournalService =
           budgetJournalService ??
           (projectsManager ?? globalGetIt().get<OcptProjectsManager>()).budgetJournalService,
       _budgetQuoteService =
           budgetQuoteService ??
           (projectsManager ?? globalGetIt().get<OcptProjectsManager>()).budgetQuoteService,
       _budgetFinancingService =
           budgetFinancingService ??
           (projectsManager ?? globalGetIt().get<OcptProjectsManager>()).budgetFinancingService,
       _budgetSharingService =
           budgetSharingService ??
           (projectsManager ?? globalGetIt().get<OcptProjectsManager>()).budgetSharingService,
       super(const OcptBudgetCashJournalState.init());

  /// {@macro act_flutter_utility.BlocForMixin.registerMixinEvents}
  @override
  void registerMixinEvents() {
    super.registerMixinEvents();
    on<OcptBudgetEntryCreationConfirmedEvent>(_onEntryCreationConfirmed);
    on<OcptBudgetEntryUpdateConfirmedEvent>(_onEntryUpdateConfirmed);
    on<OcptBudgetEntryDeletionConfirmedEvent>(_onEntryDeletionConfirmed);
    on<OcptBudgetEntryPromotedToQuoteEvent>(_onEntryPromotedToQuote);
    on<OcptBudgetEntryMovedOffQuoteEvent>(_onEntryMovedOffQuote);
    on<OcptBudgetCommitmentCreationConfirmedEvent>(_onCommitmentCreationConfirmed);
    on<OcptBudgetCommitmentUpdateConfirmedEvent>(_onCommitmentUpdateConfirmed);
    on<OcptBudgetCommitmentDeletionConfirmedEvent>(_onCommitmentDeletionConfirmed);
    on<OcptBudgetCommitmentSettlementConfirmedEvent>(_onCommitmentSettlementConfirmed);
    on<OcptBudgetCommitmentPromotedToQuoteEvent>(_onCommitmentPromotedToQuote);
    on<OcptBudgetCommitmentUnsettleRequestedEvent>(_onCommitmentUnsettleRequested);
  }

  /// Create a new cash-journal entry from `event.fields`, writing its typed amount onto whichever
  /// of `debitCents`/`creditCents` [OcptBudgetEntryFormFields.isDebit] names and zero onto the
  /// other — the one reading no single database column mirrors, see that model's own doc comment.
  ///
  /// Writes whatever `event.fields` collected about the fresh entry's own voucher
  /// (`OcptBudgetJournalFormWrites.writeEntryReceiptChange`) once it exists, in this very handler,
  /// before the one reload at its end.
  Future<void> _onEntryCreationConfirmed(
    OcptBudgetEntryCreationConfirmedEvent event,
    Emitter<OcptBudgetCashJournalState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final fields = event.fields;
    final resourceId = await _createNewResourceOf(project, fields);
    final revenueId = await _createNewRevenueOf(project, fields);
    final shareId = await _createNewShareOf(project, fields);
    final entryId = await _budgetJournalService.createEntry(
      database: project.database,
      date: fields.date,
      label: fields.label,
      accountId: fields.accountId,
      resourceId: resourceId ?? fields.resourceId,
      revenueId: revenueId ?? fields.revenueId,
      shareId: shareId ?? fields.shareId,
      commitmentId: fields.commitmentId,
      personId: fields.personId,
      debitCents: fields.isDebit ? fields.amountCents : 0,
      creditCents: fields.isDebit ? 0 : fields.amountCents,
      isTaxInclusive: fields.isTaxInclusive,
      vatRateBasisPoints: fields.vatRateBasisPoints,
    );
    if (entryId != null) {
      await _budgetJournalService.writeEntryReceiptChange(
        database: project.database,
        entryId: entryId,
        fields: fields,
      );
    }

    await modeBloc.reload({OcptBudgetReloadScope.snapshot});
  }

  /// Write `event.fields` onto entry `event.entryId`, including its own voucher number — see
  /// [OcptBudgetEntryFormFields.voucherNumber]'s own doc comment for why it is always set here, an
  /// entry dialog only ever being opened to edit with one already loaded.
  ///
  /// **[OcptBudgetEntryFormFields.commitmentId] and [OcptBudgetEntryFormFields.personId] are
  /// written only while non-null, mirroring `voucherNumber`'s own guard rather than
  /// `accountId`/`resourceId`/`revenueId`/`shareId`'s.** `OcptBudgetEntryDialog` carries no field
  /// for either yet, so `event.fields` never actually names one; reading a null here as "clear the
  /// link" the way the four ordinary link fields do would silently un-settle a commitment, or drop
  /// a reimbursement's own person, the very next time somebody edited that entry through the
  /// ordinary `Edit` gesture. Undoing a settlement already has its own dedicated event
  /// ([OcptBudgetCommitmentUnsettleRequestedEvent]); this handler must not duplicate it by
  /// accident.
  ///
  /// Writes whatever `event.fields` collected about the entry's own voucher
  /// (`OcptBudgetJournalFormWrites.writeEntryReceiptChange`) in this very handler too, before the
  /// one reload at its end.
  Future<void> _onEntryUpdateConfirmed(
    OcptBudgetEntryUpdateConfirmedEvent event,
    Emitter<OcptBudgetCashJournalState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final fields = event.fields;
    final voucherNumber = fields.voucherNumber;
    final commitmentId = fields.commitmentId;
    final personId = fields.personId;
    final resourceId = await _createNewResourceOf(project, fields);
    final revenueId = await _createNewRevenueOf(project, fields);
    final shareId = await _createNewShareOf(project, fields);
    await _budgetJournalService.updateEntry(
      database: project.database,
      entryId: event.entryId,
      date: Value(fields.date),
      label: Value(fields.label),
      accountId: Value(fields.accountId),
      resourceId: Value(resourceId ?? fields.resourceId),
      revenueId: Value(revenueId ?? fields.revenueId),
      shareId: Value(shareId ?? fields.shareId),
      commitmentId: commitmentId == null ? const Value.absent() : Value(commitmentId),
      personId: personId == null ? const Value.absent() : Value(personId),
      debitCents: Value(fields.isDebit ? fields.amountCents : 0),
      creditCents: Value(fields.isDebit ? 0 : fields.amountCents),
      isTaxInclusive: Value(fields.isTaxInclusive),
      vatRateBasisPoints: Value(fields.vatRateBasisPoints),
      voucherNumber: voucherNumber == null ? const Value.absent() : Value(voucherNumber),
    );
    await _budgetJournalService.writeEntryReceiptChange(
      database: project.database,
      entryId: event.entryId,
      fields: fields,
    );

    await modeBloc.reload({OcptBudgetReloadScope.snapshot});
  }

  /// Create the taking `fields` carries as still-to-be-made
  /// ([OcptBudgetEntryFormFields.newRevenue]) and answer its fresh id, or null while it carries
  /// none — which is the ordinary case.
  ///
  /// **Written exactly the way `OcptBudgetSharingBloc` writes one**, through the same two
  /// calls, so a taking born in the journal is indistinguishable from one born in the sharing
  /// view: the door differs, never the row.
  Future<String?> _createNewRevenueOf(
    OcptOpenProjectModel project,
    OcptBudgetEntryFormFields fields,
  ) async {
    final newRevenue = fields.newRevenue;
    if (newRevenue == null) {
      return null;
    }

    return _budgetSharingService.createRevenueWithFields(
      database: project.database,
      fields: newRevenue,
    );
  }

  /// Create the financing resource `fields` carries as still-to-be-made
  /// ([OcptBudgetEntryFormFields.newResource]) and answer its fresh id, or null while it carries
  /// none — mirrors [_createNewRevenueOf] exactly, written the way `OcptBudgetFinancingBloc`
  /// writes one, so a resource born in the journal is indistinguishable from one born in the
  /// financing plan.
  Future<String?> _createNewResourceOf(
    OcptOpenProjectModel project,
    OcptBudgetEntryFormFields fields,
  ) async {
    final newResource = fields.newResource;
    if (newResource == null) {
      return null;
    }

    return _budgetFinancingService.createResourceWithFields(
      database: project.database,
      fields: newResource,
    );
  }

  /// Create the revenue-sharing participant `fields` carries as still-to-be-made
  /// ([OcptBudgetEntryFormFields.newShare]) and answer its fresh id, or null while it carries none
  /// — mirrors [_createNewRevenueOf] exactly, written the way `OcptBudgetSharingBloc` writes
  /// one.
  Future<String?> _createNewShareOf(
    OcptOpenProjectModel project,
    OcptBudgetEntryFormFields fields,
  ) async {
    final newShare = fields.newShare;
    if (newShare == null) {
      return null;
    }

    return _budgetSharingService.createShareWithFields(
      database: project.database,
      fields: newShare,
    );
  }

  /// Delete cash-journal entry `event.entryId` for good, confirmed by the mode's own
  /// `OcptConfirmDialog`.
  Future<void> _onEntryDeletionConfirmed(
    OcptBudgetEntryDeletionConfirmedEvent event,
    Emitter<OcptBudgetCashJournalState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _budgetJournalService.deleteEntry(database: project.database, entryId: event.entryId);
    await modeBloc.reload({OcptBudgetReloadScope.snapshot});
  }

  /// Create a new commitment from `event.fields`.
  Future<void> _onCommitmentCreationConfirmed(
    OcptBudgetCommitmentCreationConfirmedEvent event,
    Emitter<OcptBudgetCashJournalState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final fields = event.fields;
    await _budgetJournalService.createCommitment(
      database: project.database,
      accountId: fields.accountId,
      label: fields.label,
      dueDate: fields.dueDate,
      amountCents: fields.amountCents,
      isTaxInclusive: fields.isTaxInclusive,
      vatRateBasisPoints: fields.vatRateBasisPoints,
      status: fields.status,
      lineId: event.lineId,
    );

    await modeBloc.reload({OcptBudgetReloadScope.snapshot});
  }

  /// Write `event.fields` onto commitment `event.commitmentId` — `fields.accountId` is never sent
  /// on, see `OcptBudgetCommitmentUpdateConfirmedEvent`'s own doc comment.
  Future<void> _onCommitmentUpdateConfirmed(
    OcptBudgetCommitmentUpdateConfirmedEvent event,
    Emitter<OcptBudgetCashJournalState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final fields = event.fields;
    await _budgetJournalService.updateCommitment(
      database: project.database,
      commitmentId: event.commitmentId,
      dueDate: Value(fields.dueDate),
      label: Value(fields.label),
      accountId: Value(fields.accountId),
      amountCents: Value(fields.amountCents),
      isTaxInclusive: Value(fields.isTaxInclusive),
      vatRateBasisPoints: Value(fields.vatRateBasisPoints),
      status: Value(fields.status),
    );

    await modeBloc.reload({OcptBudgetReloadScope.snapshot});
  }

  /// Delete commitment `event.commitmentId` for good, confirmed by the mode's own
  /// `OcptConfirmDialog`.
  Future<void> _onCommitmentDeletionConfirmed(
    OcptBudgetCommitmentDeletionConfirmedEvent event,
    Emitter<OcptBudgetCashJournalState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _budgetJournalService.deleteCommitment(
      database: project.database,
      commitmentId: event.commitmentId,
    );
    await modeBloc.reload({OcptBudgetReloadScope.snapshot});
  }

  /// Record commitment `event.commitmentId`'s own payment: creates the journal entry
  /// `event.fields` describes, naming this commitment through `commitmentId` — one dispatched
  /// event, one write, then one reload. Settlement is read back off that link
  /// (`ocptBudgetCommitmentIsSettledOf`), never written a second time onto the commitment itself.
  Future<void> _onCommitmentSettlementConfirmed(
    OcptBudgetCommitmentSettlementConfirmedEvent event,
    Emitter<OcptBudgetCashJournalState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final fields = event.fields;
    final entryId = await _budgetJournalService.createEntry(
      database: project.database,
      date: fields.date,
      label: fields.label,
      accountId: fields.accountId,
      resourceId: fields.resourceId,
      revenueId: fields.revenueId,
      shareId: fields.shareId,
      commitmentId: event.commitmentId,
      debitCents: fields.isDebit ? fields.amountCents : 0,
      creditCents: fields.isDebit ? 0 : fields.amountCents,
      isTaxInclusive: fields.isTaxInclusive,
      vatRateBasisPoints: fields.vatRateBasisPoints,
    );

    if (entryId != null) {
      await _budgetJournalService.writeEntryReceiptChange(
        database: project.database,
        entryId: entryId,
        fields: fields,
      );
    }

    await modeBloc.reload({OcptBudgetReloadScope.snapshot});
  }

  /// Promote off-line debit entry `event.entryId` into the quote — the detail panel's own banner
  /// and its `Add to the quote` action, offered on a debit that names an account but no commitment
  /// ([OcptBudgetEntryPromotedToQuoteEvent]'s own doc comment has the whole mechanism). Creates a
  /// quote line from the entry first (`createLine`, quantity `1.0`, the entry's own label and tax
  /// basis), then a commitment from that line exactly as `OcptBudgetExpensesBloc` does for a line
  /// paid directly (`createCommitment`, naming it through `lineId`) — and finally **re-points the
  /// entry itself at that fresh commitment** (`updateEntry`, `commitmentId` alone) rather than
  /// creating a second entry: the debit that settles the commitment is the very one already on the
  /// ledger. Skipping the relink would leave the commitment unsettled, adding to the account's
  /// committed total on top of what is already paid — the exact double-count this whole mode
  /// refuses everywhere else.
  Future<void> _onEntryPromotedToQuote(
    OcptBudgetEntryPromotedToQuoteEvent event,
    Emitter<OcptBudgetCashJournalState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final entry = modeBloc.state.entries.where((entry) => entry.id == event.entryId).firstOrNull;
    final accountId = entry?.accountId;
    if (entry == null || accountId == null || !ocptBudgetEntryIsOffLineDebit(entry)) {
      return;
    }

    final lineId = await _budgetQuoteService.createLine(
      database: project.database,
      accountId: accountId,
      label: entry.label,
      quantityMilli: const Value(1000),
      unitAmountCents: Value(entry.debitCents),
      isTaxInclusive: Value(entry.isTaxInclusive),
      vatRateBasisPoints: Value(entry.vatRateBasisPoints),
    );
    if (lineId == null) {
      return;
    }

    final commitmentId = await _budgetJournalService.createCommitment(
      database: project.database,
      accountId: accountId,
      label: entry.label,
      amountCents: entry.debitCents,
      isTaxInclusive: entry.isTaxInclusive,
      vatRateBasisPoints: entry.vatRateBasisPoints,
      lineId: lineId,
    );
    if (commitmentId == null) {
      return;
    }

    await _budgetJournalService.updateEntry(
      database: project.database,
      entryId: entry.id,
      commitmentId: Value(commitmentId),
    );

    await modeBloc.reload({OcptBudgetReloadScope.snapshot});
  }

  /// Detach off-line debit entry `event.entryId` from its account — the detail panel's own banner
  /// and its `Move off-quote` action, the other way to reconcile the very entry
  /// [_onEntryPromotedToQuote] promotes: rather than folding the spend into the quote, this admits
  /// it was never quoted at all. Clears `accountId` back to null and nothing else, so the entry
  /// reads as an honest off-quote spend from then on ([OcptBudgetEntryMovedOffQuoteEvent]'s own doc
  /// comment).
  Future<void> _onEntryMovedOffQuote(
    OcptBudgetEntryMovedOffQuoteEvent event,
    Emitter<OcptBudgetCashJournalState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final entry = modeBloc.state.entries.where((entry) => entry.id == event.entryId).firstOrNull;
    if (entry == null || !ocptBudgetEntryIsOffLineDebit(entry)) {
      return;
    }

    await _budgetJournalService.updateEntry(
      database: project.database,
      entryId: entry.id,
      accountId: const Value(null),
    );

    await modeBloc.reload({OcptBudgetReloadScope.snapshot});
  }

  /// Promote off-line commitment `event.commitmentId` into the quote — the detail panel's own
  /// banner and its `Add to the quote` action, offered on a commitment that names an account but no
  /// quote line ([OcptBudgetCommitmentPromotedToQuoteEvent]'s own doc comment has the whole
  /// mechanism). Creates a quote line from the commitment (`createLine`, quantity `1.0`, its own
  /// label, amount and tax basis), then **re-points the commitment itself at that fresh line**
  /// (`updateCommitment`, `lineId` alone). The entry that settles the commitment is left untouched
  /// — it already names the commitment — so the chain gains only the quote line it lacked, and the
  /// account's quote grows by the amount that made it overrun.
  Future<void> _onCommitmentPromotedToQuote(
    OcptBudgetCommitmentPromotedToQuoteEvent event,
    Emitter<OcptBudgetCashJournalState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final commitment = modeBloc.state.commitments
        .where((commitment) => commitment.id == event.commitmentId)
        .firstOrNull;
    if (commitment == null || !ocptBudgetCommitmentIsOffLine(commitment)) {
      return;
    }

    final lineId = await _budgetQuoteService.createLine(
      database: project.database,
      accountId: commitment.accountId,
      label: commitment.label,
      quantityMilli: const Value(1000),
      unitAmountCents: Value(commitment.amount.amountCents),
      isTaxInclusive: Value(commitment.amount.isTaxInclusive),
      vatRateBasisPoints: Value(commitment.amount.vatRateBasisPoints),
    );
    if (lineId == null) {
      return;
    }

    await _budgetJournalService.updateCommitment(
      database: project.database,
      commitmentId: commitment.id,
      lineId: Value(lineId),
    );

    await modeBloc.reload({OcptBudgetReloadScope.snapshot});
  }

  /// Undo commitment `event.commitmentId`'s own settlement: clears `commitmentId` back to null on
  /// **every** live entry that names it, each entry itself left untouched otherwise — see
  /// `OcptBudgetCommitmentUnsettleRequestedEvent`'s own doc comment. The wizard is what makes
  /// several payments against one commitment possible (`OcptBudgetEntryFormFields.commitmentId`'s
  /// own doc comment), so `Undo settlement` clearing only the first one found would leave the
  /// commitment reading unsettled while some of its instalments still counted as paid against it —
  /// exactly the double-count this whole mode refuses everywhere else. Unlinking a single
  /// instalment among several is not something this handler does.
  Future<void> _onCommitmentUnsettleRequested(
    OcptBudgetCommitmentUnsettleRequestedEvent event,
    Emitter<OcptBudgetCashJournalState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final settlingEntries = modeBloc.state.entries.where(
      (entry) => entry.commitmentId == event.commitmentId,
    );
    for (final settlingEntry in settlingEntries) {
      await _budgetJournalService.updateEntry(
        database: project.database,
        entryId: settlingEntry.id,
        commitmentId: const Value(null),
      );
    }

    await modeBloc.reload({OcptBudgetReloadScope.snapshot});
  }
}
