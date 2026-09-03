// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';
import 'dart:typed_data';

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:act_global_manager/act_global_manager.dart';
import 'package:act_platform_manager/act_platform_manager.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/managers/ocpt_diagnostics_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/managers/sync/ocpt_sync_manager.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_pairing_service.dart';
import 'package:open_cine_prod_tools/managers/sync/services/ocpt_relay_remote_storage.dart';
import 'package:open_cine_prod_tools/models/ocpt_diagnostics_entry.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_relay_invite.dart';
import 'package:open_cine_prod_tools/types/ocpt_route.dart';
import 'package:open_cine_prod_tools/ui/pages/joining/joining_event.dart';
import 'package:open_cine_prod_tools/ui/pages/joining/joining_state.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// This is the bloc class for the Rejoindre (joining) screen: pairing this replica to a project
/// already shared on a relay, by scanning the Partager screen's own QR code (tablet only) or by
/// typing its connection details by hand (`docs/plans/relay.md`, Phase C, commit 4).
///
/// Reachable with **no project open**: joining is how one comes to exist on this replica in the
/// first place, so [OcptRoute.joining] carries none of the workspace/project settings/sharing
/// routes' own open-project guard (`OcptRouterManager`).
///
/// A submission — manual or scanned — resolves to an [OcptRelayInvite], then, in order: picks
/// where the new `.ocpt` lands ([_resolveParentDirectoryPath], reported as
/// [OcptJoinStep.connecting]), fetches the relay's latest snapshot and materialises it there
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
  /// The manager driving the actual join: opening the relay transport and fetching/materialising
  /// its latest snapshot.
  final OcptSyncManager _syncManager;

  /// The manager used to open the freshly joined project once it has landed on disk.
  final OcptProjectsManager _projectsManager;

  /// The router manager used to navigate to the workspace once the joined project is open.
  final OcptRouterManager _routerManager;

  /// The manager used to show the native "save as" dialog a desktop platform picks the new
  /// project's own parent folder through — see [_resolveParentDirectoryPath].
  final FileSaverManager _fileSaverManager;

  /// The manager telling [_resolveParentDirectoryPath] whether a native save dialog exists on this
  /// platform at all.
  final PlatformManager _platformManager;

  /// Class constructor
  OcptJoiningBloc({
    OcptSyncManager? syncManager,
    OcptProjectsManager? projectsManager,
    OcptRouterManager? routerManager,
    FileSaverManager? fileSaverManager,
    PlatformManager? platformManager,
  }) : _syncManager = syncManager ?? globalGetIt().get<OcptSyncManager>(),
       _projectsManager = projectsManager ?? globalGetIt().get<OcptProjectsManager>(),
       _routerManager = routerManager ?? globalGetIt().get<OcptRouterManager>(),
       _fileSaverManager = fileSaverManager ?? globalGetIt().get<FileSaverManager>(),
       // Not resolved through globalGetIt() like the managers above: PlatformManager's own
       // constructor is a synchronous, side-effect-free read of the real platform, so building one
       // directly here is exactly as correct as the registered singleton would be, and it keeps
       // this bloc's own tests from having to register it — `OcptExportManager`'s own constructor
       // follows the same reasoning.
       _platformManager = platformManager ?? PlatformManager(),
       super(const OcptJoiningState.init());

  /// Set by [_onCancelled] and checked by [_join] after every `await` along the join path, to bail
  /// out — without navigating and without reporting success — the moment the user asks to cancel.
  ///
  /// This is a best-effort UI abandon only: `dart:io` gives no way to actually cancel an in-flight
  /// snapshot fetch or materialisation already under way, so a cancelled join may still finish
  /// writing a `.ocpt` to disk after this flag is set — that file is simply never opened or shown,
  /// which is an acceptable cost for how rarely a cancel lands mid-write.
  bool _cancelled = false;

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

  /// Parses the pasted invite link into an [OcptRelayInvite], then joins — or surfaces
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
  ) => _joinFromRawText(event.inviteLinkText, emitter);

  /// Parses the scanned QR text into an [OcptRelayInvite], then joins — or surfaces
  /// [OcptJoiningState.joinFailed] straight away when it isn't one at all (a QR aimed at some
  /// unrelated app).
  Future<void> _onInviteScanned(
    OcptJoiningInviteScannedEvent event,
    Emitter<OcptJoiningState> emitter,
  ) => _joinFromRawText(event.scannedText, emitter);

  /// Parses [rawText] — a pasted invite link or a scanned QR code's own decoded text, the manual
  /// and scan paths' shared destination — into an [OcptRelayInvite], then joins, or surfaces
  /// [OcptJoiningState.joinFailed] when it isn't one at all.
  Future<void> _joinFromRawText(String rawText, Emitter<OcptJoiningState> emitter) async {
    final invite = OcptRelayInvite.tryParse(rawText.trim());
    if (invite == null) {
      emitter(state.copyWith(joinFailed: true));
      return;
    }

    await _join(invite, emitter);
  }

  /// Runs the actual join against [invite]: picks a destination folder ([OcptJoinStep.connecting]),
  /// fetches and materialises the relay's latest snapshot there ([OcptJoinStep.downloading]), and
  /// opens the result ([OcptJoinStep.opening]) — leaving [OcptJoiningState.joinSucceeded] for the
  /// page's own success state to pick up; it, not this method, is what eventually navigates
  /// (see [_onOpenRequested]).
  ///
  /// [_cancelled] is checked after every `await`: once [_onCancelled] has set it, this bails out
  /// silently — no further state change, no navigation — rather than reporting either success or
  /// failure for a join the user has already walked away from.
  ///
  /// A cancelled destination picker is a silent no-op, exactly like every other import/export of
  /// this app treats one; any other failure — the relay unreachable, an invalid token, a corrupted
  /// snapshot, the freshly written project failing to open — surfaces as
  /// [OcptJoiningState.joinFailed].
  Future<void> _join(OcptRelayInvite invite, Emitter<OcptJoiningState> emitter) async {
    _cancelled = false;
    emitter(
      state.copyWith(
        isJoining: true,
        joinFailed: false,
        joinSucceeded: false,
        joinStep: OcptJoinStep.connecting,
      ),
    );
    OcptDiagnosticsManager.log(
      category: OcptDiagnosticsCategory.join,
      message: 'connecting: project=${invite.projectId} relay=${invite.relayBaseUri}',
    );

    try {
      final parentDirectoryPath = await _resolveParentDirectoryPath();
      if (_cancelled) {
        return;
      }
      if (parentDirectoryPath == null) {
        emitter(state.copyWith(isJoining: false, clearJoinStep: true));
        return;
      }

      final pairing = OcptProjectPairing(relayBaseUri: invite.relayBaseUri, token: invite.token);
      final storage = _syncManager.openRelayRemoteStorage(pairing, invite.projectId);
      final String projectFilePath;
      try {
        emitter(state.copyWith(joinStep: OcptJoinStep.downloading));
        OcptDiagnosticsManager.log(
          category: OcptDiagnosticsCategory.join,
          message: 'downloading: project=${invite.projectId}',
        );
        projectFilePath = await _syncManager.joinFromRelay(
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
      if (_cancelled) {
        return;
      }

      emitter(state.copyWith(joinStep: OcptJoinStep.opening));
      OcptDiagnosticsManager.log(
        category: OcptDiagnosticsCategory.join,
        message: 'opening: project=${invite.projectId}',
      );
      final result = await _projectsManager.openProject(filePath: projectFilePath);
      if (_cancelled) {
        return;
      }
      if (!result.status.isSuccess) {
        OcptDiagnosticsManager.log(
          category: OcptDiagnosticsCategory.join,
          level: OcptDiagnosticsLevel.error,
          message: 'failed to open joined project: project=${invite.projectId}',
        );
        emitter(state.copyWith(isJoining: false, joinFailed: true, clearJoinStep: true));
        return;
      }

      OcptDiagnosticsManager.log(
        category: OcptDiagnosticsCategory.join,
        message: 'succeeded: project=${invite.projectId}',
      );
      emitter(state.copyWith(isJoining: false, joinSucceeded: true, clearJoinStep: true));
    } catch (error) {
      if (_cancelled) {
        return;
      }
      OcptDiagnosticsManager.log(
        category: OcptDiagnosticsCategory.join,
        level: OcptDiagnosticsLevel.error,
        message: 'failed: project=${invite.projectId} $error',
      );
      emitter(state.copyWith(isJoining: false, joinFailed: true, clearJoinStep: true));
    }
  }

  /// Where the joined project's `.ocpt` lands: the parent of a native "save as" location on
  /// desktop (`FileSaverManager`, exactly as the Home page's own "New project" flow picks one —
  /// see `OcptHomeBloc._onCreateProjectRequested`), since `getSaveLocation` has no Android/iOS
  /// implementation (ADR 0009) — on mobile, the application's own documents directory instead,
  /// where there is no such dialog to show at all.
  ///
  /// The desktop picker's own placeholder file is discarded once its parent directory is read off
  /// it: only the folder was ever wanted, the joined project's actual file name coming from the
  /// relay's own snapshot manifest instead (`OcptSnapshotService.applySnapshot`).
  ///
  /// Returns null when the user cancelled the desktop dialog.
  Future<String?> _resolveParentDirectoryPath() async {
    if (_platformManager.isMobile) {
      final documentsDirectory = await getApplicationDocumentsDirectory();
      return documentsDirectory.path;
    }

    final suggestedFileName = "joined-project.${OcptProjectsManager.projectFileExtension}";
    final pickedPath = await _fileSaverManager.saveFileFromBytes(
      fileName: suggestedFileName,
      bytes: Uint8List(0),
    );
    if (pickedPath == null) {
      return null;
    }

    try {
      await File(pickedPath).delete();
    } catch (_) {
      // Best-effort cleanup only: a leftover empty placeholder file beside the real joined
      // project is a cosmetic annoyance, not a reason to fail the join.
    }

    return p.dirname(pickedPath);
  }

  /// Clears [OcptJoiningState.joinFailed] once the page has shown its own snack bar for it.
  Future<void> _onErrorDismissed(
    OcptJoiningErrorDismissedEvent event,
    Emitter<OcptJoiningState> emitter,
  ) async {
    emitter(state.copyWith(joinFailed: false));
  }

  /// Pushes the workspace on the user's explicit "Ouvrir", once [OcptJoiningState.joinSucceeded] is
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

  /// Marks the in-flight join as abandoned — see [_cancelled]'s own doc comment for what this can
  /// and cannot actually stop — and returns the page to its idle state.
  Future<void> _onCancelled(
    OcptJoiningCancelledEvent event,
    Emitter<OcptJoiningState> emitter,
  ) async {
    OcptDiagnosticsManager.log(category: OcptDiagnosticsCategory.join, message: 'cancelled');
    _cancelled = true;
    emitter(state.copyWith(isJoining: false, clearJoinStep: true));
  }
}
