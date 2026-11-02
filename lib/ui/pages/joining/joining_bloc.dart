// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_dart_result/act_dart_result.dart';
import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:act_global_manager/act_global_manager.dart';
import 'package:act_logger_manager/act_logger_manager.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/logging/ocpt_logs_helper_builder.dart';
import 'package:open_cine_prod_tools/managers/ocpt_diagnostics_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/managers/sync/ocpt_sync_manager.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_project_pairing.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_relay_remote_storage.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_uri_query.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_relay_invite.dart';
import 'package:open_cine_prod_tools/types/ocpt_diagnostics_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_diagnostics_level.dart';
import 'package:open_cine_prod_tools/types/ocpt_route.dart';
import 'package:open_cine_prod_tools/types/ocpt_sync_flow_status.dart';
import 'package:open_cine_prod_tools/ui/pages/joining/join_step.dart';
import 'package:open_cine_prod_tools/ui/pages/joining/joining_event.dart';
import 'package:open_cine_prod_tools/ui/pages/joining/joining_state.dart';

/// This is the bloc class for the Rejoindre (joining) screen: pairing this replica to a project
/// already shared on a relay, by scanning the Partager screen's own QR code (tablet only) or by
/// typing its connection details by hand.
///
/// Reachable with **no project open**: joining is how one comes to exist on this replica in the
/// first place, so [OcptRoute.joining] carries none of the workspace/project settings/sharing
/// routes' own open-project guard (`OcptRouterManager`).
///
/// A submission — manual or scanned — resolves to an [OcptRelayInvite], then, in order: picks
/// where the new `.ocpt` lands ([_resolveParentDirectoryPath], reported as
/// [OcptJoinStep.connecting] — the native folder-picker dialog on desktop, cancelling which cancels
/// the join with no further state change; [OcptProjectsManager.newProjectsDirectory] with no dialog
/// at all on mobile), fetches the relay's latest snapshot and materialises it there
/// ([OcptSyncManager.joinFromRelay], reported as [OcptJoinStep.downloading]), and opens the
/// freshly written project ([OcptProjectsManager.openProject], reported as
/// [OcptJoinStep.opening]). Any failure along that path — a malformed submission, an unreachable
/// relay, a corrupted snapshot, a project that fails to open — is surfaced as
/// [OcptJoiningState.joinFailed] rather than propagated: exactly `OcptSharingBloc.pairingFailed`'s
/// own reasoning, this bloc has no `Tr` to word a specific message with, and the page reads the
/// flag to show its own, generic, localized one.
///
/// A successful join only sets [OcptJoiningState.joinSucceeded] — it does **not** navigate to the
/// workspace on its own. The page shows a success state for the user to confirm, and only
/// [OcptJoiningOpenRequestedEvent] pushes the workspace, through `OcptRouterManager.replace` so the
/// Rejoindre screen is replaced rather than left underneath it: pushing on top of it (as this bloc
/// used to) meant the workspace's own Home/back returned to Rejoindre instead of the real home.
class OcptJoiningBloc extends BlocForMixin<OcptJoiningState> {
  /// The logger category linked to this BLoC.
  static const _loggerCategory = "joining_bloc";

  /// The logger this BLoC writes to.
  final LogsHelper _logger;

  /// The manager driving the actual join: opening the relay transport and fetching/materialising
  /// its latest snapshot.
  final OcptSyncManager _syncManager;

  /// The manager used to open the freshly joined project once it has landed on disk.
  final OcptProjectsManager _projectsManager;

  /// The router manager used to navigate to the workspace once the joined project is open.
  final OcptRouterManager _routerManager;

  /// The manager used to show the native folder picker [_resolveParentDirectoryPath] picks the
  /// joined project's own parent folder through on desktop, and to tell desktop from mobile
  /// ([OcptExportManager.isMobile]) — the same manager `OcptHomeBloc` reaches for the very same
  /// reason.
  final OcptExportManager _exportManager;

  /// Class constructor
  OcptJoiningBloc({
    OcptSyncManager? syncManager,
    OcptProjectsManager? projectsManager,
    OcptRouterManager? routerManager,
    OcptExportManager? exportManager,
  }) : _logger = buildOcptLogsHelper(_loggerCategory),
       _syncManager = syncManager ?? globalGetIt().get<OcptSyncManager>(),
       _projectsManager = projectsManager ?? globalGetIt().get<OcptProjectsManager>(),
       _routerManager = routerManager ?? globalGetIt().get<OcptRouterManager>(),
       _exportManager = exportManager ?? globalGetIt().get<OcptExportManager>(),
       super(const OcptJoiningState.init());

  /// {@macro act_flutter_utility.BlocForMixin.registerMixinEvents}
  @override
  void registerMixinEvents() {
    super.registerMixinEvents();
    on<OcptJoiningManualSubmittedEvent>(_onManualSubmitted);
    on<OcptJoiningInviteScannedEvent>(_onInviteScanned);
    on<OcptJoiningErrorDismissedEvent>(_onErrorDismissed);
    on<OcptJoiningOpenRequestedEvent>(_onOpenRequested);
    on<OcptJoiningCancelledEvent>(_onCancelled);
  }

  /// Parse the pasted invite link into an [OcptRelayInvite], then join — or surface
  /// [OcptJoiningState.joinFailed] straight away when it isn't one at all (an empty field or some
  /// other, unrelated text).
  ///
  /// Validation happens here, not in the page: none of it needs a `Tr` (a malformed link is worded
  /// once, generically, by [OcptJoiningState.joinFailed]'s own page-side message), and keeping it
  /// here is what lets this bloc's own tests exercise "a malformed manual entry" with no widget
  /// involved at all. Delegates to [_onInviteScanned]'s own shared [_joinFromRawText]: both paths
  /// end at the exact same place, a raw string that may or may not be an [OcptRelayInvite].
  Future<void> _onManualSubmitted(
    OcptJoiningManualSubmittedEvent event,
    Emitter<OcptJoiningState> emitter,
  ) => _joinFromRawText(event.inviteLinkText, event.destinationConfirmButtonText, emitter);

  /// Parse the scanned QR text into an [OcptRelayInvite], then join — or surface
  /// [OcptJoiningState.joinFailed] straight away when it isn't one at all (a QR aimed at some
  /// unrelated app).
  Future<void> _onInviteScanned(
    OcptJoiningInviteScannedEvent event,
    Emitter<OcptJoiningState> emitter,
  ) => _joinFromRawText(event.scannedText, event.destinationConfirmButtonText, emitter);

  /// Parse [rawText] — a pasted invite link or a scanned QR code's own decoded text, the manual and
  /// scan paths' shared destination — into an [OcptRelayInvite], then join, or surface
  /// [OcptJoiningState.joinFailed] when it isn't one at all.
  Future<void> _joinFromRawText(
    String rawText,
    String destinationConfirmButtonText,
    Emitter<OcptJoiningState> emitter,
  ) async {
    final invite = OcptRelayInvite.parse(rawText.trim()).value;
    if (invite == null) {
      OcptDiagnosticsManager.log(
        category: OcptDiagnosticsCategory.join,
        level: OcptDiagnosticsLevel.warning,
        message: 'scanned code is not a valid join invite — ${_describeScannedText(rawText)}',
        // The description names the host of whatever was scanned, which is not logged.
        logMessage: 'scanned code is not a valid join invite',
      );
      emitter(state.copyWithInviteRejected());
      return;
    }

    await _join(invite, destinationConfirmButtonText, emitter);
  }

  /// Get a token-free description of what a rejected scan/paste actually held, for the diagnostics
  /// log:
  /// the URI scheme and host, and which of the invite's own `r`/`p`/`t` query parameters were
  /// present (never their values — a token must never reach the log). This is what tells a rejected
  /// `ocpt://relay` enrolment QR (scanned in the wrong screen) apart from a genuinely malformed
  /// `ocpt://join` invite or a QR aimed at some unrelated app.
  String _describeScannedText(String rawText) {
    final uri = Uri.tryParse(rawText.trim());
    if (uri == null) {
      return 'not a URI (${rawText.trim().length} chars)';
    }
    final query = ocptQueryParametersOrNull(uri);
    if (query == null) {
      // A percent-escape that is not valid UTF-8 parses as a URI but throws on this read.
      return 'scheme=${uri.scheme} host=${uri.host} params=[unreadable]';
    }
    final present = [
      if ((query['r'] ?? '').isNotEmpty) 'r',
      if ((query['p'] ?? '').isNotEmpty) 'p',
      if ((query['t'] ?? '').isNotEmpty) 't',
    ].join(',');
    return 'scheme=${uri.scheme} host=${uri.host} params=[$present]';
  }

  /// Run the actual join against [invite]: picks a destination folder ([OcptJoinStep.connecting]),
  /// fetches and materialises the relay's latest snapshot there ([OcptJoinStep.downloading]), and
  /// opens the result ([OcptJoinStep.opening]) — leaving [OcptJoiningState.joinSucceeded] for the
  /// page's own success state to pick up; it, not this method, is what eventually navigates
  /// (see [_onOpenRequested]).
  ///
  /// [OcptJoiningState.isCancelled] is checked after every `await`: once [_onCancelled] has set it,
  /// this bails out silently — no further state change, no navigation — rather than reporting
  /// either success or failure for a join the user has already walked away from.
  ///
  /// A cancelled destination picker is a silent no-op, exactly like every other import/export of
  /// this app treats one; any other failure — the relay unreachable, an invalid token, a corrupted
  /// snapshot, the freshly written project failing to open — surfaces as
  /// [OcptJoiningState.joinFailed].
  Future<void> _join(
    OcptRelayInvite invite,
    String destinationConfirmButtonText,
    Emitter<OcptJoiningState> emitter,
  ) async {
    emitter(state.copyWithJoinStarted());
    OcptDiagnosticsManager.log(
      category: OcptDiagnosticsCategory.join,
      message: 'connecting: project=${invite.projectId} relay=${invite.relayBaseUri}',
      // The relay's address is not logged.
      logMessage: 'connecting: project=${invite.projectId}',
    );

    try {
      await _runJoin(invite, destinationConfirmButtonText, emitter);
    } catch (error, stackTrace) {
      if (!state.isCancelled) {
        // The error can name the relay's address or a folder, so only its type is logged.
        _logger.e('Joining a project failed: ${error.runtimeType}', null, stackTrace);
        OcptDiagnosticsManager.log(
          category: OcptDiagnosticsCategory.join,
          level: OcptDiagnosticsLevel.error,
          message: 'failed: project=${invite.projectId} $error',
          logMessage: 'failed: project=${invite.projectId} ${error.runtimeType}',
        );
        emitter(state.copyWithJoinFailed());
      }
    }
  }

  /// Run the steps of [_join], whose exceptions [_join] turns into [OcptJoiningState.joinFailed].
  /// Stops
  /// silently at the first step that finds [OcptJoiningState.isCancelled] set.
  Future<void> _runJoin(
    OcptRelayInvite invite,
    String destinationConfirmButtonText,
    Emitter<OcptJoiningState> emitter,
  ) async {
    final parentDirectoryPath = await _resolveParentDirectoryPath(destinationConfirmButtonText);
    if (state.isCancelled) {
      return;
    }
    if (parentDirectoryPath == null) {
      // The user cancelled the desktop folder picker.
      emitter(state.copyToIdle());
      return;
    }

    final pairing = OcptProjectPairing(relayBaseUri: invite.relayBaseUri, token: invite.token);
    final storage = _syncManager.openRelayRemoteStorage(pairing, invite.projectId);
    final ResultWithStatus<OcptSyncFlowStatus, String> joined;
    try {
      emitter(state.copyWithDownloading());
      OcptDiagnosticsManager.log(
        category: OcptDiagnosticsCategory.join,
        message: 'downloading: project=${invite.projectId}',
      );
      joined = await _syncManager.joinFromRelay(
        storage: storage,
        parentDirectoryPath: parentDirectoryPath,
        pairingService: _syncManager.pairingService,
        relayBaseUri: invite.relayBaseUri,
        token: invite.token,
      );
    } finally {
      if (storage is OcptRelayRemoteStorage) {
        storage.dispose();
      }
    }
    if (state.isCancelled) {
      return;
    }
    final projectFilePath = joined.value;
    if (!joined.status.isSuccess || projectFilePath == null) {
      // The relay's answer can name its address, so only the status is logged.
      _logger.e('Joining a project failed: ${joined.status.name}');
      OcptDiagnosticsManager.log(
        category: OcptDiagnosticsCategory.join,
        level: OcptDiagnosticsLevel.error,
        message: 'failed: project=${invite.projectId} ${joined.extraInfo ?? joined.status}',
        logMessage: 'failed: project=${invite.projectId} ${joined.status.name}',
      );
      emitter(state.copyWithJoinFailed());
      return;
    }

    emitter(state.copyWithOpening());
    OcptDiagnosticsManager.log(
      category: OcptDiagnosticsCategory.join,
      message: 'opening: project=${invite.projectId}',
    );
    final result = await _projectsManager.openProject(filePath: projectFilePath);
    if (state.isCancelled) {
      return;
    }
    if (!result.status.isSuccess) {
      OcptDiagnosticsManager.log(
        category: OcptDiagnosticsCategory.join,
        level: OcptDiagnosticsLevel.error,
        message: 'failed to open joined project: project=${invite.projectId}',
      );
      emitter(state.copyWithJoinFailed());
      return;
    }

    if (!_exportManager.isMobile) {
      await _projectsManager.rememberProjectsDirectory(parentDirectoryPath);
    }

    OcptDiagnosticsManager.log(
      category: OcptDiagnosticsCategory.join,
      message: 'succeeded: project=${invite.projectId}',
    );
    emitter(state.copyWithJoinSucceeded());
  }

  /// Tell where the joined project's `.ocpt` lands: the folder picked in the native folder-picker
  /// dialog
  /// on desktop (mirroring `OcptHomeBloc`'s own save-file dialog, suggested inside
  /// [OcptProjectsManager.suggestedProjectsDirectory] and labelled [confirmButtonText]'s own
  /// confirm button), or [OcptProjectsManager.newProjectsDirectory] with no dialog at all on
  /// mobile, where `file_selector`'s `getDirectoryPath` has no Android/iOS implementation (ADR
  /// 0009) — the application's own documents directory then.
  ///
  /// Nothing is written here: the joined project's own folder is created by the package import,
  /// which refuses to replace one already there. Returns null when the user cancelled the desktop
  /// dialog.
  Future<String?> _resolveParentDirectoryPath(String confirmButtonText) async {
    if (_exportManager.isMobile) {
      final directory = await _projectsManager.newProjectsDirectory();
      return directory.path;
    }

    final suggestedDirectory = await _projectsManager.suggestedProjectsDirectory();
    return _exportManager.saveLocationService.pickDirectory(
      confirmButtonText: confirmButtonText,
      initialDirectory: suggestedDirectory,
    );
  }

  /// Clear [OcptJoiningState.joinFailed] once the page has shown its own snack bar for it.
  Future<void> _onErrorDismissed(
    OcptJoiningErrorDismissedEvent event,
    Emitter<OcptJoiningState> emitter,
  ) async {
    emitter(state.copyWithFailureDismissed());
  }

  /// Push the workspace on the user's explicit "Ouvrir", once [OcptJoiningState.joinSucceeded] is
  /// true — through [OcptRouterManager.replace] rather than [OcptRouterManager.push], so the
  /// Rejoindre screen is replaced on the navigation stack instead of left underneath the workspace:
  /// a push there would mean the workspace's own Home/back returned to Rejoindre instead of the
  /// real home.
  Future<void> _onOpenRequested(
    OcptJoiningOpenRequestedEvent event,
    Emitter<OcptJoiningState> emitter,
  ) async {
    await _routerManager.replace(OcptRoute.workspace);
  }

  /// Mark the in-flight join as abandoned — see [OcptJoiningState.isCancelled]'s own doc comment
  /// for what this can and cannot actually stop — and return the page to its idle state.
  Future<void> _onCancelled(
    OcptJoiningCancelledEvent event,
    Emitter<OcptJoiningState> emitter,
  ) async {
    OcptDiagnosticsManager.log(category: OcptDiagnosticsCategory.join, message: 'cancelled');
    emitter(state.copyToCancelled());
  }
}
