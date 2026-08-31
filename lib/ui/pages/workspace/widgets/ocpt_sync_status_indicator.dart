// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/managers/sync/ocpt_sync_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_specific_colors.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_sync_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_route.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_warning_color.dart';

/// The workspace status bar's sync indicator, straight from the mock-up (`docs/plans/relay.md`,
/// Phase C, commit 5): the one on-screen entry point into a project's own sync session.
///
/// Renders nothing at all while [OcptSyncManager.syncStatus] is null — no session is running,
/// either because the project isn't paired or because the workspace hasn't started one yet — the
/// mock-up's own "absent" case for an unpaired project: the primary sharing entry stays the Home
/// card's own menu (a later wiring commit), never this indicator.
///
/// Seeds its very first frame from [OcptSyncManager.syncStatus] (the getter) rather than waiting on
/// [OcptSyncManager.syncStatusStream], which — like every ACT manager stream — never replays its
/// current value to a late listener (`CLAUDE.md`'s own pitfalls list): [StreamBuilder]'s own
/// `initialData` is exactly that seed, so the badge never flashes empty before the stream's first
/// event.
///
/// A tap opens a small panel naming the current state — the offline count or the relay's own error
/// message, whichever applies — with four actions: `Synchroniser maintenant`
/// ([OcptSyncManager.syncNow]); `Afficher le QR d'invitation` / `Ré-appairer…`, which both simply
/// open the Partager screen ([OcptRoute.sharing]) already showing the invite QR and the way to
/// replace a pairing; and `Changer de relais…`, which opens the repointing screen
/// ([OcptRoute.repointing]) to move the project's ongoing sync onto a different relay
/// (`docs/plans/on-set-server.md`, Phase E). Under a read-only preview (`isReadOnly`) all four are
/// withheld — a null callback, never merely a disabled one, exactly as every other affordance that
/// writes does.
class OcptSyncStatusIndicator extends StatelessWidget {
  /// Class constructor
  ///
  /// [syncManager] and [routerManager] are the injectable seams over `globalGetIt()` a widget test
  /// hands in instead. [isReadOnly] defaults to reading
  /// [OcptProjectsManager.currentProject]'s own `isReadOnly` through `globalGetIt()`, so a test can
  /// simply pass the boolean it wants rather than fake the whole projects manager for it.
  const OcptSyncStatusIndicator({
    super.key,
    OcptSyncManager? syncManager,
    OcptRouterManager? routerManager,
    bool? isReadOnly,
  }) : _syncManager = syncManager,
       _routerManager = routerManager,
       _isReadOnly = isReadOnly;

  final OcptSyncManager? _syncManager;
  final OcptRouterManager? _routerManager;
  final bool? _isReadOnly;

  /// [_syncManager], or the one `globalGetIt()` holds when there is an app-wide manager
  /// environment that actually registered one, or null otherwise.
  ///
  /// Null is not an edge case this indicator merely tolerates: it is exactly the "no session
  /// running" case [OcptSyncManager.syncStatus] itself would report for an unpaired project, so a
  /// mode's own widget test — most of which build a bare mode page with no reason to ever register
  /// a sync manager of their own, this feature being no part of what they test — renders the very
  /// same "nothing to show" this indicator already gives an unpaired project, rather than crashing
  /// on a `globalGetIt()` lookup nobody asked it to satisfy.
  OcptSyncManager? get _sync {
    final override = _syncManager;
    if (override != null) {
      return override;
    }
    if (AbsGlobalManager.instance == null) {
      return null;
    }

    final managers = globalGetIt();
    return managers.isRegistered<OcptSyncManager>() ? managers.get<OcptSyncManager>() : null;
  }

  OcptRouterManager get _router => _routerManager ?? globalGetIt().get<OcptRouterManager>();

  /// [_isReadOnly], or [OcptProjectsManager.currentProject]'s own `isReadOnly` when an app-wide
  /// manager environment registered one, or false otherwise — see [_sync]'s own doc comment for
  /// why a missing registration reads as the harmless case rather than a crash.
  bool get _readOnly {
    final override = _isReadOnly;
    if (override != null) {
      return override;
    }
    if (AbsGlobalManager.instance == null) {
      return false;
    }

    final managers = globalGetIt();
    if (!managers.isRegistered<OcptProjectsManager>()) {
      return false;
    }

    return managers.get<OcptProjectsManager>().currentProject?.isReadOnly ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final manager = _sync;
    if (manager == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<OcptSyncStatus>(
      initialData: manager.syncStatus,
      stream: manager.syncStatusStream,
      builder: (context, snapshot) {
        final status = snapshot.data;
        if (status == null) {
          return const SizedBox.shrink();
        }

        final isReadOnly = _readOnly;

        return Padding(
          padding: const EdgeInsets.only(left: 8),
          child: _OcptSyncStatusBadge(
            status: status,
            onSyncNowRequested: isReadOnly ? null : () => unawaited(manager.syncNow()),
            onSharingRequested: isReadOnly
                ? null
                : () => unawaited(_router.push(OcptRoute.sharing)),
            onSwitchRelayRequested: isReadOnly
                ? null
                : () => unawaited(_router.push(OcptRoute.repointing)),
          ),
        );
      },
    );
  }
}

/// The compact badge shown in the status bar: [_labelFor]'s text, tinted by [_colorFor], with a
/// small spinner in place of the leading dot while [OcptSyncStatusSyncing]. Opens
/// [_OcptSyncStatusPanel] on tap, over the exact `MenuAnchor`/`builder` idiom
/// `OcptLocationSheetHeader`'s own colour bar already uses for a popover triggered by a badge.
class _OcptSyncStatusBadge extends StatelessWidget {
  /// Class constructor
  const _OcptSyncStatusBadge({
    required this.status,
    required this.onSyncNowRequested,
    required this.onSharingRequested,
    required this.onSwitchRelayRequested,
  });

  /// The status this badge (and the panel it opens) renders.
  final OcptSyncStatus status;

  /// Called when the panel's `Synchroniser maintenant` action is chosen, or null while the badge
  /// must withhold it (a read-only preview).
  final VoidCallback? onSyncNowRequested;

  /// Called when either of the panel's `Afficher le QR d'invitation` / `Ré-appairer…` actions is
  /// chosen, or null while the badge must withhold them (a read-only preview).
  final VoidCallback? onSharingRequested;

  /// Called when the panel's `Changer de relais…` action is chosen, or null while the badge must
  /// withhold it (a read-only preview).
  final VoidCallback? onSwitchRelayRequested;

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);
    final color = _colorFor(context, status);

    return MenuAnchor(
      menuChildren: [
        _OcptSyncStatusPanel(
          status: status,
          onSyncNowRequested: onSyncNowRequested,
          onSharingRequested: onSharingRequested,
          onSwitchRelayRequested: onSwitchRelayRequested,
        ),
      ],
      builder: (context, controller, child) => InkWell(
        mouseCursor: ocptClickableCursor,
        borderRadius: BorderRadius.circular(ocptRadiusLarge),
        onTap: () => controller.isOpen ? controller.close() : controller.open(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: ocptSelectedStateAlpha),
            borderRadius: BorderRadius.circular(ocptRadiusLarge),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _OcptSyncStatusGlyph(status: status, color: color),
              const SizedBox(width: 4),
              Text(
                _labelFor(tr, status),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The badge's leading glyph: a small spinner while [OcptSyncStatusSyncing], a static dot
/// otherwise — the mock-up's own "small spinner" for the one state actually in flight.
class _OcptSyncStatusGlyph extends StatelessWidget {
  /// Class constructor
  const _OcptSyncStatusGlyph({required this.status, required this.color});

  /// The status deciding whether this glyph spins.
  final OcptSyncStatus status;

  /// The colour tinting the glyph, matching the badge's own text.
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (status is OcptSyncStatusSyncing) {
      return SizedBox.square(
        dimension: 10,
        child: CircularProgressIndicator(strokeWidth: 1.5, color: color),
      );
    }

    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// The panel [_OcptSyncStatusBadge] opens on tap: the current state (plus the relay's own error
/// message, when there is one) and the three actions the mock-up gives the indicator.
class _OcptSyncStatusPanel extends StatelessWidget {
  /// Class constructor
  const _OcptSyncStatusPanel({
    required this.status,
    required this.onSyncNowRequested,
    required this.onSharingRequested,
    required this.onSwitchRelayRequested,
  });

  /// The status this panel describes.
  final OcptSyncStatus status;

  /// Forwarded from [_OcptSyncStatusBadge], see its own doc comment.
  final VoidCallback? onSyncNowRequested;

  /// Forwarded from [_OcptSyncStatusBadge], see its own doc comment.
  final VoidCallback? onSharingRequested;

  /// Forwarded from [_OcptSyncStatusBadge], see its own doc comment.
  final VoidCallback? onSwitchRelayRequested;

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);
    final status = this.status;

    return SizedBox(
      width: 260,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_labelFor(tr, status), style: theme.textTheme.titleSmall),
                if (status is OcptSyncStatusError) ...[
                  const SizedBox(height: 4),
                  Text(
                    tr.workspaceSyncPanelErrorDetail(status.message),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          MenuItemButton(
            onPressed: onSyncNowRequested,
            child: Text(tr.workspaceSyncActionSyncNow),
          ),
          MenuItemButton(
            onPressed: onSharingRequested,
            child: Text(tr.workspaceSyncActionShowQr),
          ),
          MenuItemButton(
            onPressed: onSharingRequested,
            child: Text(tr.workspaceSyncActionRepair),
          ),
          MenuItemButton(
            onPressed: onSwitchRelayRequested,
            child: Text(tr.workspaceSyncActionSwitchRelay),
          ),
        ],
      ),
    );
  }
}

/// [status]'s own label, shared by the badge and the panel's header so the two never say something
/// different about the very same status.
String _labelFor(Tr tr, OcptSyncStatus status) => switch (status) {
  OcptSyncStatusInSync() => tr.workspaceSyncStatusInSync,
  OcptSyncStatusSyncing() => tr.workspaceSyncStatusSyncing,
  OcptSyncStatusOffline(pendingEditCount: final count) => count == null
      ? tr.workspaceSyncStatusOfflineUnknown
      : tr.workspaceSyncStatusOfflinePending(count),
  OcptSyncStatusError() => tr.workspaceSyncStatusError,
};

/// [status]'s own colour: the calm green of a shot already accepted for
/// [OcptSyncStatusInSync] (reused generically here, exactly as the breakdown/schedule/resources
/// labels already do), the app's one violet accent while [OcptSyncStatusSyncing], the app's amber
/// "needs attention" colour for [OcptSyncStatusOffline], and `error` for [OcptSyncStatusError].
Color _colorFor(BuildContext context, OcptSyncStatus status) {
  final theme = Theme.of(context);

  return switch (status) {
    OcptSyncStatusInSync() =>
      theme.extension<OcptSpecificColors>()?.shotStatusShot ?? theme.colorScheme.primary,
    OcptSyncStatusSyncing() => theme.colorScheme.primary,
    OcptSyncStatusOffline() => ocptWarningColor(context),
    OcptSyncStatusError() => theme.colorScheme.error,
  };
}
