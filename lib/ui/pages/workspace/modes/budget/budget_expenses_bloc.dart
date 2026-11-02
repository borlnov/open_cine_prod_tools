// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:act_logger_manager/act_logger_manager.dart';
import 'package:drift/drift.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/managers/logging/ocpt_logs_helper_builder.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_budget_journal_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_budget_quote_service.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_account.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_line.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_selection.dart';
import 'package:open_cine_prod_tools/models/ocpt_element.dart';
import 'package:open_cine_prod_tools/models/ocpt_open_project_model.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_totals.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_vat.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_cost_amount.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_pending_edits.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_reload_scope.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_selection_cause.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/abs_ocpt_view_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_view_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_expenses_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_journal_form_writes.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_state.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_budget_labels.dart';

/// This is the bloc class for the budget mode's expenses view: the accounts and the quote lines,
/// the free-text fields typed into them and the `Pay` action of a line.
///
/// The quote is the mode's data, in `OcptBudgetState.snapshot`, and which row is selected is the
/// mode's too. This bloc owns what the expenses view does with them: every write (the service, then
/// `await modeBloc.reload(…)`, then, for an account or a line it created, the mode's selection of
/// it) and the edits typed and not yet written ([OcptBudgetExpensesState.pendingFieldEdits]), which
/// it writes [OcptBudgetBloc.defaultFieldEditDebounce] after the last keystroke, on a timer of its
/// own; the mode flushes them ahead of anything that needs the database to be up to date.
///
/// **Reacting.** A row being selected clears nothing here, and an ordinary re-read after a write
/// leaves the typed edits alone: an edit typed into a row that was deleted meanwhile is written
/// like any other, as it always was. When the mode reads everything again (entry, a version
/// preview, a restore) every pending edit is dropped, since the database underneath may be another
/// one.
///
/// **A write that fails is not caught.** The service's error stops the handler, the edit stays
/// pending and on screen, the database is unchanged, and the debounce is gone until the next
/// keystroke, which writes everything again. A flush that fails reports it to the mode, which then
/// does not carry out the selection, the preview or the export it flushed for.
class OcptBudgetExpensesBloc
    extends AbsOcptViewBloc<OcptBudgetExpensesState, OcptBudgetState, OcptBudgetBloc> {
  /// The logger category linked to this BLoC.
  static const _loggerCategory = "budget_expenses_bloc";

  /// The logger this BLoC writes to.
  final LogsHelper _logger;

  /// The manager used to access the project currently open.
  final OcptProjectsManager _projectsManager;

  /// The service used to write the quote: the accounts and their lines.
  final OcptBudgetQuoteService _budgetQuoteService;

  /// The service used to write the commitment and the entry a line paid directly leaves behind.
  final OcptBudgetJournalService _budgetJournalService;

  /// The delay between the last field edit and its autosave write.
  final Duration _fieldEditDebounce;

  /// Class constructor
  ///
  /// Every dependency but [modeBloc] can be overridden, which is what the tests do; in the app they
  /// all resolve through [globalGetIt]. [fieldEditDebounce] is only meant to be overridden by
  /// tests, to keep it fast and deterministic.
  OcptBudgetExpensesBloc({
    required super.modeBloc,
    OcptProjectsManager? projectsManager,
    OcptBudgetQuoteService? budgetQuoteService,
    OcptBudgetJournalService? budgetJournalService,
    Duration fieldEditDebounce = OcptBudgetBloc.defaultFieldEditDebounce,
  }) : _logger = buildOcptLogsHelper(_loggerCategory),
       _projectsManager = projectsManager ?? globalGetIt().get<OcptProjectsManager>(),
       _budgetQuoteService =
           budgetQuoteService ??
           (projectsManager ?? globalGetIt().get<OcptProjectsManager>()).budgetQuoteService,
       _budgetJournalService =
           budgetJournalService ??
           (projectsManager ?? globalGetIt().get<OcptProjectsManager>()).budgetJournalService,
       _fieldEditDebounce = fieldEditDebounce,
       super(const OcptBudgetExpensesState.init());

  /// {@macro act_flutter_utility.BlocForMixin.registerMixinEvents}
  @override
  void registerMixinEvents() {
    super.registerMixinEvents();
    on<OcptBudgetAccountCreatedEvent>(_onAccountCreated);
    on<OcptBudgetAccountReorderedEvent>(_onAccountReordered);
    on<OcptBudgetAccountDeletionConfirmedEvent>(_onAccountDeletionConfirmed);
    on<OcptBudgetAccountEstimateToCompleteDerivedRequestedEvent>(
      _onAccountEstimateToCompleteDerivedRequested,
    );
    on<OcptBudgetLineCreatedEvent>(_onLineCreated);
    on<OcptBudgetLineCreatedFromElementEvent>(_onLineCreatedFromElement);
    on<OcptBudgetLineDeletionConfirmedEvent>(_onLineDeletionConfirmed);
    on<OcptBudgetLineTaxInclusiveChangedEvent>(_onLineTaxInclusiveChanged);
    on<OcptBudgetLineVatRateInheritedRequestedEvent>(_onLineVatRateInheritedRequested);
    on<OcptBudgetLinePaidDirectlyEvent>(_onLinePaidDirectly);
    on<OcptBudgetFieldChangedEvent>(_onFieldChanged);
    on<OcptBudgetFieldEditFlushRequestedEvent>(_onFieldEditFlushRequested);
  }

  /// Drop the edits the mode's fresh read makes meaningless.
  ///
  /// When the mode read everything again (`OcptBudgetSelectionCause.load`: entry, a version preview
  /// or a restore) every pending edit goes, whichever row it was typed into: the database
  /// underneath may be another one, and the mode flushed first whenever losing an edit would
  /// matter. Nothing else clears anything here: a selection move leaves the edits alone, and an
  /// ordinary re-read after a write only brings newer rows.
  ///
  /// Reads the cause from the state that moved the epoch (`event.modeState`). Waits for nothing:
  /// the mode's change and this reaction must land in the same turn of the event loop.
  @override
  Future<void> onModeStateChanged(
    OcptViewModeStateChangedEvent<OcptBudgetState> event,
    Emitter<OcptBudgetExpensesState> emitter,
  ) async {
    final isLoaded =
        event.hasSelectionMoved && event.modeState.selectionCause == OcptBudgetSelectionCause.load;
    if (!isLoaded) {
      return;
    }

    cancelDebounce();
    if (state.pendingFieldEdits.isNotEmpty) {
      emitter(state.copyWithFieldEditsCleared());
    }
  }

  /// Write every pending field edit immediately: cancels the debounce timer (a no-op if it already
  /// fired or there was none), writes each one, then has the mode read the snapshot again — which
  /// also reconciles the selection and refreshes the working-copy card if the `Versions` tab is
  /// open — and only then forgets what it wrote, so what a field shows never falls back to a stale
  /// stored value between the two. A no-op while nothing is pending. Answers whether there was
  /// anything pending.
  ///
  /// A failed write throws, and the edit stays pending. When the mode could not read the snapshot
  /// again the edits stay pending too: they were written, but what is on screen is still the older
  /// data.
  ///
  /// Called by the debounce firing, and by the mode ahead of every action that needs the database
  /// to be up to date.
  @override
  Future<bool> onFlushRequested(Emitter<OcptBudgetExpensesState> emitter) async {
    cancelDebounce();

    final pending = state.pendingFieldEdits;
    if (pending.isEmpty) {
      return false;
    }

    final project = _projectsManager.currentProject;
    if (project == null) {
      emitter(state.copyWithFieldEditsCleared());
      return true;
    }

    await _writeAllPendingFieldEdits(project, pending);
    if (!await modeBloc.reload({OcptBudgetReloadScope.snapshot})) {
      // The write landed but the mode could not read it back, which the old handler let escape
      // and so stopped the action behind the flush: answering that all went well would let a
      // preview, an export or a restore run on the snapshot from before the write. The edit stays
      // pending, and the next flush writes it again.
      throw StateError("The data could not be read again after the pending edits were written");
    }

    emitter(
      state.copyWithFieldEditsWritten(
        pendingFieldEdits: ocptPendingEditsAfterWrite(
          current: state.pendingFieldEdits,
          written: pending,
        ),
      ),
    );
    return true;
  }

  /// Write every pending field edit directly to the database, bypassing both the debounce timer
  /// and the bloc's own event queue.
  ///
  /// Called by the mode's own `deactivate()` (through the flushers it registered): `deactivate()`
  /// runs before `dispose()` for every removal from the tree, so triggering the write here — rather
  /// than dispatching an event, which would only be processed on a later microtask this widget
  /// might not survive to see — is what guarantees the last [_fieldEditDebounce] worth of typing
  /// isn't lost. Unlike [onFlushRequested], this never touches [state]: `emit` may only be called
  /// from inside a registered `on<Event>` handler, and by the time this runs the widget tree that
  /// would show a fresh state is already gone anyway. A failure here is only logged.
  @override
  Future<void> flushPendingWritesWithoutState() async {
    cancelDebounce();

    final edits = state.pendingFieldEdits;
    if (edits.isEmpty) {
      return;
    }

    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    try {
      await flushEditsWithoutState(
        edits,
        (unwritten) => _writeAllPendingFieldEdits(project, unwritten),
      );
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to flush a pending budget field edit of project "
        "${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
    }
  }

  /// Create a new, unnamed account, appended at the end of the catalogue, and select it.
  Future<void> _onAccountCreated(
    OcptBudgetAccountCreatedEvent event,
    Emitter<OcptBudgetExpensesState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final accountId = await _budgetQuoteService.createAccount(
      database: project.database,
      label: "",
    );

    if (!await modeBloc.reload({OcptBudgetReloadScope.snapshot})) {
      return;
    }

    if (accountId != null) {
      await addToModeAndWait(
        OcptBudgetSelectionCreatedEvent(
          selection: OcptBudgetAccountSelection(accountId),
          opensInspector: true,
        ),
      );
    }
  }

  /// Move account `event.accountId` to `event.newPosition` within the catalogue's flat order.
  Future<void> _onAccountReordered(
    OcptBudgetAccountReorderedEvent event,
    Emitter<OcptBudgetExpensesState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _budgetQuoteService.reorderAccount(
      database: project.database,
      accountId: event.accountId,
      newPosition: event.newPosition,
    );
    await modeBloc.reload({OcptBudgetReloadScope.snapshot});
  }

  /// Delete account `event.accountId` for good, along with every quote line it holds, confirmed by
  /// the mode's own `OcptConfirmDialog`.
  Future<void> _onAccountDeletionConfirmed(
    OcptBudgetAccountDeletionConfirmedEvent event,
    Emitter<OcptBudgetExpensesState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _budgetQuoteService.deleteAccount(database: project.database, accountId: event.accountId);
    await modeBloc.reload({OcptBudgetReloadScope.snapshot});
  }

  /// Put account `event.accountId`'s own estimate to complete back to being derived, immediately —
  /// see `OcptBudgetAccountEstimateToCompleteDerivedRequestedEvent`'s own doc comment.
  Future<void> _onAccountEstimateToCompleteDerivedRequested(
    OcptBudgetAccountEstimateToCompleteDerivedRequestedEvent event,
    Emitter<OcptBudgetExpensesState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _budgetQuoteService.updateAccount(
      database: project.database,
      accountId: event.accountId,
      estimateToCompleteCents: const Value(null),
    );
    await modeBloc.reload({OcptBudgetReloadScope.snapshot});
  }

  /// Create a new quote line inside account `event.accountId`, appended at the end of its own
  /// lines, and select it, opening the right dock on the `Inspector` tab — a line is now selected
  /// rather than expanded, mirroring `OcptBudgetBloc`'s own selection of a line.
  ///
  /// **`event.fields` null keeps this handler's own original write**: an unnamed line, every other
  /// figure left at `OcptBudgetLinesTable`'s own defaults, for the tree's own inline editor to fill
  /// in — see `OcptBudgetLineCreatedEvent`'s own doc comment. Non-null writes the line born filled,
  /// in the one `createLine` call this handler has always made.
  Future<void> _onLineCreated(
    OcptBudgetLineCreatedEvent event,
    Emitter<OcptBudgetExpensesState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final fields = event.fields;
    final lineId = await _budgetQuoteService.createLine(
      database: project.database,
      accountId: event.accountId,
      label: fields?.label ?? "",
      quantityMilli: fields == null ? const Value.absent() : Value(fields.quantityMilli),
      unit: fields == null ? const Value.absent() : Value(fields.unit),
      unitAmountCents: fields == null ? const Value.absent() : Value(fields.unitAmountCents),
    );

    if (!await modeBloc.reload({OcptBudgetReloadScope.snapshot})) {
      return;
    }

    if (lineId != null) {
      await addToModeAndWait(
        OcptBudgetSelectionCreatedEvent(
          selection: OcptBudgetLineSelection(lineId),
          opensInspector: true,
        ),
      );
    }
  }

  /// Create a new quote line inside account `event.accountId` **from** breakdown element
  /// `event.elementId`, and select it — dispatched by the capture wizard's own breakdown selector,
  /// once per row created. An element id naming no live element of [OcptBudgetState.elements] is
  /// ignored: the selector only ever offers a live one, so this should not happen outside a stale
  /// dialog result.
  ///
  /// Mints the line with `OcptElement.name` as its own label and `elementId` naming the element —
  /// **never a price**, whatever `OcptElement.cost` happens to hold: "the breakdown says what, not
  /// how much" (`docs/architecture/budget.md`) is the whole reason this event's only caller
  /// is a selector, not a form. `event.quantityMilli` seeds `quantityMilli`, passed on as
  /// [Value.absent] rather than defaulted while it is null.
  Future<void> _onLineCreatedFromElement(
    OcptBudgetLineCreatedFromElementEvent event,
    Emitter<OcptBudgetExpensesState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    OcptElement? element;
    for (final candidate in modeBloc.state.elements) {
      if (candidate.id == event.elementId) {
        element = candidate;
        break;
      }
    }
    if (element == null) {
      return;
    }

    final quantityMilli = event.quantityMilli;
    final lineId = await _budgetQuoteService.createLine(
      database: project.database,
      accountId: event.accountId,
      label: element.name,
      elementId: Value(element.id),
      quantityMilli: quantityMilli == null ? const Value.absent() : Value(quantityMilli),
    );

    if (!await modeBloc.reload({OcptBudgetReloadScope.snapshot})) {
      return;
    }

    if (lineId != null) {
      await addToModeAndWait(
        OcptBudgetSelectionCreatedEvent(
          selection: OcptBudgetLineSelection(lineId),
          opensInspector: true,
        ),
      );
    }
  }

  /// Delete quote line `event.lineId` for good, confirmed by the mode's own `OcptConfirmDialog`.
  Future<void> _onLineDeletionConfirmed(
    OcptBudgetLineDeletionConfirmedEvent event,
    Emitter<OcptBudgetExpensesState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _budgetQuoteService.deleteLine(database: project.database, lineId: event.lineId);
    await modeBloc.reload({OcptBudgetReloadScope.snapshot});
  }

  /// Write a new including/excluding-tax basis onto line `event.lineId`'s own unit price
  /// immediately — a pick, not typing.
  Future<void> _onLineTaxInclusiveChanged(
    OcptBudgetLineTaxInclusiveChangedEvent event,
    Emitter<OcptBudgetExpensesState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _budgetQuoteService.updateLine(
      database: project.database,
      lineId: event.lineId,
      isTaxInclusive: Value(event.isTaxInclusive),
    );
    await modeBloc.reload({OcptBudgetReloadScope.snapshot});
  }

  /// Put line `event.lineId`'s own VAT rate back to inheriting the project's default, immediately
  /// — see `OcptBudgetLineVatRateInheritedRequestedEvent`'s own doc comment for why this is a
  /// dedicated event rather than something an empty field submission could trigger.
  Future<void> _onLineVatRateInheritedRequested(
    OcptBudgetLineVatRateInheritedRequestedEvent event,
    Emitter<OcptBudgetExpensesState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _budgetQuoteService.updateLine(
      database: project.database,
      lineId: event.lineId,
      vatRateBasisPoints: const Value(null),
    );
    await modeBloc.reload({OcptBudgetReloadScope.snapshot});
  }

  /// Pay quote line `event.lineId` directly, promoting it into a commitment in the same gesture —
  /// the line's own `Pay` action (`OcptBudgetLinePaidDirectlyEvent`). Creates the commitment from
  /// the line first — its full quoted total, in the line's own tax basis and rate, naming the line
  /// — then records `event.fields` as the debit that settles it, naming that fresh commitment: the
  /// two writes `_onCommitmentCreationConfirmed` and `_onCommitmentSettlementConfirmed` do apart,
  /// done here as one so the engagement stays transparent to a reader who only quoted and paid. A
  /// partial payment leaves the commitment standing with its own outstanding, read back off the
  /// link like any other.
  Future<void> _onLinePaidDirectly(
    OcptBudgetLinePaidDirectlyEvent event,
    Emitter<OcptBudgetExpensesState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    OcptBudgetAccount? account;
    OcptBudgetLine? line;
    for (final candidate in modeBloc.state.accounts) {
      final match = candidate.lines.where((candidate) => candidate.id == event.lineId).firstOrNull;
      if (match != null) {
        account = candidate;
        line = match;
        break;
      }
    }
    if (account == null || line == null) {
      return;
    }

    final commitmentId = await _budgetJournalService.createCommitment(
      database: project.database,
      accountId: account.id,
      label: line.label,
      amountCents: ocptBudgetLineTotalCents(line),
      isTaxInclusive: line.unitPrice.isTaxInclusive,
      vatRateBasisPoints: line.unitPrice.vatRateBasisPoints,
      // createCommitment already defaults status to quoteAccepted — a line just quoted, nothing yet
      // signed.
      lineId: line.id,
    );
    if (commitmentId == null) {
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
      commitmentId: commitmentId,
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

  /// Record the raw text just typed into a field as a pending edit, visible immediately, and
  /// (re)starts the field-edit debounce.
  Future<void> _onFieldChanged(
    OcptBudgetFieldChangedEvent event,
    Emitter<OcptBudgetExpensesState> emitter,
  ) async {
    final pending = Map<OcptBudgetPendingFieldKey, String>.of(state.pendingFieldEdits)
      ..[(event.targetId, event.field)] = event.rawValue;
    emitter(state.copyWithFieldEditTyped(pendingFieldEdits: pending));

    restartDebounce(_fieldEditDebounce, const OcptBudgetFieldEditFlushRequestedEvent());
  }

  /// Write every pending field edit once the field-edit debounce timer fires.
  Future<void> _onFieldEditFlushRequested(
    OcptBudgetFieldEditFlushRequestedEvent event,
    Emitter<OcptBudgetExpensesState> emitter,
  ) async {
    await onFlushRequested(emitter);
  }

  /// Tell whether [field] targets a quote line that is an in-kind counterpart line (its
  /// `inKindResourceId` is set) — such a line's fields follow the contribution it balances and are
  /// never a direct edit's to write (`docs/architecture/budget.md`, "A balanced in-kind
  /// contribution"). Defensive only: `OcptBudgetDetail` already withholds a counterpart line's
  /// editable fields, so this guards against a future edit path reaching one.
  bool _isInKindCounterpartLineField(OcptBudgetField field, String targetId) {
    const lineFields = {
      OcptBudgetField.lineLabel,
      OcptBudgetField.lineQuantity,
      OcptBudgetField.lineUnit,
      OcptBudgetField.lineUnitAmount,
      OcptBudgetField.lineVatRateOverride,
    };
    if (!lineFields.contains(field)) {
      return false;
    }

    for (final account in modeBloc.state.accounts) {
      for (final line in account.lines) {
        if (line.id == targetId) {
          return line.inKindResourceId != null;
        }
      }
    }
    return false;
  }

  /// Write every one of [edits] to [project]'s database, one write per entry — the shared write
  /// loop [onFlushRequested] and [flushPendingWritesWithoutState] both run, so the switch over
  /// [OcptBudgetField] is written once.
  ///
  /// The four numeric fields ([OcptBudgetField.accountEstimateToComplete],
  /// [OcptBudgetField.lineQuantity], [OcptBudgetField.lineUnitAmount],
  /// [OcptBudgetField.lineVatRateOverride]) are parsed here, and a submission that doesn't parse is
  /// **skipped** rather than written: `quantityMilli` and `unitAmountCents` are never nullable, so
  /// there is no null they could legitimately become, and an estimate's or an override's own
  /// empty/unparseable reading is deliberately not "clear it" (`OcptBudgetField`'s own doc comment)
  /// — the field simply reverts to whatever the database already holds on the next read.
  Future<void> _writeAllPendingFieldEdits(
    OcptOpenProjectModel project,
    Map<OcptBudgetPendingFieldKey, String> edits,
  ) async {
    for (final entry in edits.entries) {
      final (targetId, field) = entry.key;
      final value = entry.value;

      // A counterpart line's own fields follow the in-kind contribution it balances, never a direct
      // edit's — the detail panel withholds them, so reaching here would be a bug; skip rather than
      // let a line drift away from the resource it must equal.
      if (_isInKindCounterpartLineField(field, targetId)) {
        continue;
      }

      switch (field) {
        case OcptBudgetField.accountLabel:
          await _budgetQuoteService.updateAccount(
            database: project.database,
            accountId: targetId,
            label: Value(value),
          );
        case OcptBudgetField.accountCode:
          await _budgetQuoteService.updateAccount(
            database: project.database,
            accountId: targetId,
            code: Value(value),
          );
        case OcptBudgetField.accountSimpleLabel:
          await _budgetQuoteService.updateAccount(
            database: project.database,
            accountId: targetId,
            simpleLabel: Value(value.isEmpty ? null : value),
          );
        case OcptBudgetField.accountEstimateToComplete:
          final amountCents = ocptCostCentsOf(value);
          if (amountCents != null) {
            await _budgetQuoteService.updateAccount(
              database: project.database,
              accountId: targetId,
              estimateToCompleteCents: Value(amountCents),
            );
          }
        case OcptBudgetField.lineLabel:
          await _budgetQuoteService.updateLine(
            database: project.database,
            lineId: targetId,
            label: Value(value),
          );
        case OcptBudgetField.lineQuantity:
          final quantityMilli = ocptBudgetQuantityMilliOf(value);
          if (quantityMilli != null) {
            await _budgetQuoteService.updateLine(
              database: project.database,
              lineId: targetId,
              quantityMilli: Value(quantityMilli),
            );
          }
        case OcptBudgetField.lineUnit:
          await _budgetQuoteService.updateLine(
            database: project.database,
            lineId: targetId,
            unit: Value(value),
          );
        case OcptBudgetField.lineUnitAmount:
          final amountCents = ocptCostCentsOf(value);
          if (amountCents != null) {
            await _budgetQuoteService.updateLine(
              database: project.database,
              lineId: targetId,
              unitAmountCents: Value(amountCents),
            );
          }
        case OcptBudgetField.lineVatRateOverride:
          final basisPoints = ocptVatRateBasisPointsOf(value);
          if (basisPoints != null) {
            await _budgetQuoteService.updateLine(
              database: project.database,
              lineId: targetId,
              vatRateBasisPoints: Value(basisPoints),
            );
          }
        case OcptBudgetField.lineNotes:
          await _budgetQuoteService.updateLine(
            database: project.database,
            lineId: targetId,
            notes: Value(value),
          );
      }
    }
  }
}
