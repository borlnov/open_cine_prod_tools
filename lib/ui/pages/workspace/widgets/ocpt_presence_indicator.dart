// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/sync/ocpt_sync_manager.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_presence_frame.dart';
import 'package:open_cine_prod_tools/models/sync/ocpt_presence_roster.dart';
import 'package:open_cine_prod_tools/types/ocpt_workspace_mode.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_mode_switcher.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_presence_color.dart';

/// The diameter of one avatar disc, in the cluster and in the popover alike.
const double _clusterAvatarSize = 22;

/// The diameter of a popover row's own avatar, slightly larger since it stands alone rather than
/// overlapping its neighbours.
const double _rowAvatarSize = 24;

/// How much of each cluster avatar the next one overlaps, in logical pixels.
const double _clusterOverlap = 8;

/// The width of [_OcptPresencePopover].
const double _popoverWidth = 260;

/// The maximum number of avatars the cluster draws before folding the rest into a `+N` disc.
const int _maxClusterAvatars = 3;

/// The width of the ring drawn around the self avatar, both in the cluster and in the popover.
const double _selfRingWidth = 2;

/// The workspace toolbar's presence indicator, from `docs/plans/presence.md` (M5, Phase C): an
/// overlapping avatar cluster naming every replica that currently has this project open, and a
/// `MenuAnchor` popover — the exact mechanism `OcptWorkspaceToolbar`'s own sync indicator
/// (`OcptSyncStatusIndicator`) already uses — detailing each one's platform, a short id fragment
/// and its current mode.
///
/// Renders nothing at all — [SizedBox.shrink] — whenever there is no [OcptSyncManager] registered
/// (an app-wide manager environment that never registered one, or a widget test that built a bare
/// mode page with no reason to) or [OcptSyncManager.presenceRoster] is null (an unpaired project,
/// or a paired one whose session has not started a presence service yet): the very same "nothing
/// to show" `OcptSyncStatusIndicator` already renders for the very same reasons, so a mode's own
/// widget test that never registers a sync manager renders nothing here rather than crashing on a
/// lookup nobody asked it to satisfy.
///
/// Seeds from [OcptSyncManager.presenceRoster] and then listens to
/// [OcptSyncManager.presenceRosterChanges] — the lifecycle-spanning stream, not the per-session
/// [OcptSyncManager.presenceRosterStream] — for the same reason `OcptSyncStatusIndicator` listens
/// to `syncStatusChanges`: the presence service starts only after this indicator has been built, so
/// the cluster appears the moment presence goes live and clears when the session ends.
///
/// Identity is entirely automatic (`docs/adr/0009` §6): a peer's avatar colour is derived
/// deterministically from its `deviceId` ([ocptPresenceColor]), never chosen or typed, and its
/// label is `platform · <id fragment>` — a neutral, disposable identity, never a name. The self
/// avatar is the one exception, ringed in the app's own accent colour
/// ([ColorScheme.primary]) and marked `Vous` in the popover, and — per
/// [OcptPresenceRoster]'s own contract — always the first participant.
///
/// No write action lives here: a peer's presence is a report, exactly like `OcptSyncStatus`, so
/// nothing is ever withheld under a read-only preview.
class OcptPresenceIndicator extends StatelessWidget {
  /// Class constructor
  ///
  /// [syncManager] is the injectable seam over `globalGetIt()` a widget test hands in instead —
  /// see [_sync]'s own doc comment.
  const OcptPresenceIndicator({super.key, OcptSyncManager? syncManager})
    : _syncManager = syncManager;

  final OcptSyncManager? _syncManager;

  /// [_syncManager], or the one `globalGetIt()` holds when there is an app-wide manager
  /// environment that actually registered one, or null otherwise — see
  /// `OcptSyncStatusIndicator._sync`'s own doc comment for why this is the harmless case rather
  /// than a crash.
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

  @override
  Widget build(BuildContext context) {
    final manager = _sync;
    if (manager == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<OcptPresenceRoster?>(
      initialData: manager.presenceRoster,
      stream: manager.presenceRosterChanges,
      builder: (context, snapshot) {
        final roster = snapshot.data;
        if (roster == null) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.only(left: 8),
          child: _OcptPresenceCluster(roster: roster),
        );
      },
    );
  }
}

/// The avatar cluster itself, and the [MenuAnchor] trigger opening [_OcptPresencePopover] on tap —
/// mirrors `OcptSyncStatusIndicator`'s own `_OcptSyncStatusBadge` and its `MenuAnchor`/`builder`
/// idiom.
class _OcptPresenceCluster extends StatelessWidget {
  /// Class constructor
  const _OcptPresenceCluster({required this.roster});

  /// The roster this cluster draws.
  final OcptPresenceRoster roster;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final participants = roster.participants;
    final visibleCount = participants.length > _maxClusterAvatars
        ? _maxClusterAvatars
        : participants.length;
    final overflowCount = participants.length - visibleCount;
    final step = _clusterAvatarSize - _clusterOverlap;
    final clusterWidth = _clusterAvatarSize + (visibleCount - 1 + (overflowCount > 0 ? 1 : 0)) * step;

    return MenuAnchor(
      menuChildren: [_OcptPresencePopover(roster: roster)],
      builder: (context, controller, child) => InkWell(
        mouseCursor: ocptClickableCursor,
        borderRadius: BorderRadius.circular(ocptRadiusLarge),
        onTap: () => controller.isOpen ? controller.close() : controller.open(),
        child: SizedBox(
          height: _clusterAvatarSize,
          width: clusterWidth,
          child: Stack(
            children: [
              for (var i = 0; i < visibleCount; i++)
                Positioned(
                  left: i * step,
                  child: _OcptPresenceAvatarTooltip(
                    frame: participants[i],
                    isSelf: roster.isSelf(participants[i]),
                  ),
                ),
              if (overflowCount > 0)
                Positioned(
                  left: visibleCount * step,
                  child: _OcptPresenceOverflowDisc(count: overflowCount, theme: theme),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One cluster avatar, wrapped in the [Tooltip] naming [frame]'s own label and current mode.
class _OcptPresenceAvatarTooltip extends StatelessWidget {
  /// Class constructor
  const _OcptPresenceAvatarTooltip({required this.frame, required this.isSelf});

  /// The frame this avatar represents.
  final OcptPresenceFrame frame;

  /// Whether [frame] is this replica's own — draws the accent ring when true.
  final bool isSelf;

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final label = _participantLabel(frame);
    final modeLabel = _modeLabelFor(tr, frame.modeKey);

    return Tooltip(
      message: modeLabel == null ? label : "$label · $modeLabel",
      child: _OcptPresenceAvatar(
        frame: frame,
        isSelf: isSelf,
        diameter: _clusterAvatarSize,
        // The cluster avatars sit on the dark toolbar band, so their own outline matches it: the
        // studio look's overlapping-disc convention (Frame.io/Resolve's own participant clusters),
        // cutting each disc out from the one behind it.
        outlineColor: Theme.of(context).colorScheme.surfaceContainerLow,
      ),
    );
  }
}

/// The `+N` disc closing the cluster once the roster holds more participants than
/// [_maxClusterAvatars] can show.
class _OcptPresenceOverflowDisc extends StatelessWidget {
  /// Class constructor
  const _OcptPresenceOverflowDisc({required this.count, required this.theme});

  /// How many participants are folded into this disc.
  final int count;

  /// The ambient theme, resolved once by the caller.
  final ThemeData theme;

  @override
  Widget build(BuildContext context) => Container(
    width: _clusterAvatarSize,
    height: _clusterAvatarSize,
    decoration: BoxDecoration(
      color: theme.colorScheme.surfaceContainerHighest,
      shape: BoxShape.circle,
      border: Border.all(color: theme.colorScheme.surfaceContainerLow, width: 1.5),
    ),
    alignment: Alignment.center,
    child: Text(
      "+$count",
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

/// One coloured disc: `frame.platform`'s own first letter, uppercased, over
/// [ocptPresenceColor]'s deterministic fill — the one glyph shared by the cluster and the popover
/// row alike, only their `diameter` and `outlineColor` differ.
class _OcptPresenceAvatar extends StatelessWidget {
  /// Class constructor
  const _OcptPresenceAvatar({
    required this.frame,
    required this.isSelf,
    required this.diameter,
    this.outlineColor,
  });

  /// The frame this disc represents.
  final OcptPresenceFrame frame;

  /// Whether [frame] is this replica's own — draws the accent ring when true.
  final bool isSelf;

  /// This disc's diameter.
  final double diameter;

  /// The colour drawn as a thin outline around a non-self disc, cutting it out from whatever sits
  /// behind it, or null for no outline at all (the popover row, which stands on its own).
  final Color? outlineColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fill = ocptPresenceColor(frame.deviceId);
    final initial = frame.platform.isEmpty ? "?" : frame.platform[0].toUpperCase();

    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        border: isSelf
            ? Border.all(color: theme.colorScheme.primary, width: _selfRingWidth)
            : (outlineColor == null ? null : Border.all(color: outlineColor!, width: 1.5)),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: theme.textTheme.labelSmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// The panel [_OcptPresenceCluster] opens on tap: a header naming the project and how many
/// replicas currently have it open, then one row per [roster] participant, in roster order (self
/// first, per [OcptPresenceRoster]'s own contract).
class _OcptPresencePopover extends StatelessWidget {
  /// Class constructor
  const _OcptPresencePopover({required this.roster});

  /// The roster this popover describes.
  final OcptPresenceRoster roster;

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);
    final participants = roster.participants;

    return SizedBox(
      width: _popoverWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr.workspacePresencePopoverHeader, style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  tr.workspacePresenceOnlineCount(participants.length),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          for (final frame in participants)
            _OcptPresencePopoverRow(frame: frame, isSelf: roster.isSelf(frame)),
        ],
      ),
    );
  }
}

/// One row of `_OcptPresencePopover`: [frame]'s own avatar, its `platform · <id fragment>` label
/// (with the `Vous` badge beside it while [isSelf]), and its current mode's label underneath, or
/// nothing there while `frame.modeKey` is null or names no known [OcptWorkspaceMode].
class _OcptPresencePopoverRow extends StatelessWidget {
  /// Class constructor
  const _OcptPresencePopoverRow({required this.frame, required this.isSelf});

  /// The frame this row describes.
  final OcptPresenceFrame frame;

  /// Whether [frame] is this replica's own.
  final bool isSelf;

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);
    final modeLabel = _modeLabelFor(tr, frame.modeKey);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          _OcptPresenceAvatar(frame: frame, isSelf: isSelf, diameter: _rowAvatarSize),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        _participantLabel(frame),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    if (isSelf) ...[
                      const SizedBox(width: 6),
                      _OcptPresenceSelfBadge(label: tr.workspacePresenceSelfBadge),
                    ],
                  ],
                ),
                if (modeLabel != null)
                  Text(
                    modeLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The small `Vous` pill marking the popover's self row, tinted with the app's own accent colour.
class _OcptPresenceSelfBadge extends StatelessWidget {
  /// Class constructor
  const _OcptPresenceSelfBadge({required this.label});

  /// The badge's own text.
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: ocptSelectedStateAlpha),
        borderRadius: BorderRadius.circular(ocptRadiusSmall),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// [frame]'s own neutral label: its platform, capitalised, then a short, stable slice of its
/// `deviceId` (the last three characters, or the whole id when it is shorter than that) — e.g.
/// `Windows · a3f`. Never a name: identity here is entirely automatic (`docs/adr/0009` §6).
String _participantLabel(OcptPresenceFrame frame) {
  final platform = frame.platform;
  final capitalised = platform.isEmpty
      ? platform
      : platform[0].toUpperCase() + platform.substring(1);
  final id = frame.deviceId;
  final fragment = id.length <= 3 ? id : id.substring(id.length - 3);

  return "$capitalised · $fragment";
}

/// [modeKey]'s own label from [ocptWorkspaceModeLabel], or null when [modeKey] is null or names no
/// known [OcptWorkspaceMode] — a peer that hasn't chosen a mode yet, or one running a build ahead
/// of this one that added a mode this replica doesn't know about, both read as "nothing to show"
/// rather than a throw. A plain search rather than `OcptWorkspaceMode.values.byName` precisely so
/// an unknown key is a null result, not a thrown [ArgumentError] this widget would have to guard.
String? _modeLabelFor(Tr tr, String? modeKey) {
  if (modeKey == null) {
    return null;
  }

  for (final mode in OcptWorkspaceMode.values) {
    if (mode.name == modeKey) {
      return ocptWorkspaceModeLabel(tr, mode);
    }
  }

  return null;
}
