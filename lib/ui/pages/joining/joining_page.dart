// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:act_platform_manager/act_platform_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/ui/pages/joining/joining_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/joining/joining_event.dart';
import 'package:open_cine_prod_tools/ui/pages/joining/joining_state.dart';
import 'package:open_cine_prod_tools/ui/pages/joining/widgets/ocpt_joining_manual_view.dart';
import 'package:open_cine_prod_tools/ui/pages/joining/widgets/ocpt_joining_progress_card.dart';
import 'package:open_cine_prod_tools/ui/pages/joining/widgets/ocpt_joining_scanner_view.dart';

/// The maximum width of the page's own column, matching the Partager screen's own ①/② forms.
const _maxContentWidth = 560.0;

/// The Rejoindre screen's own two tabs.
enum _OcptJoiningTab {
  /// The camera scan tab, real only on mobile — a fixed "camera unavailable" card everywhere else.
  scanner,

  /// The manual relay address/project id/token entry tab.
  manual,
}

/// The "Rejoindre un projet partagé" full-screen route: pairing this replica to a project already
/// shared on a relay, by scanning the Partager screen's own QR code (tablet only) or by typing its
/// connection details by hand (`docs/plans/relay.md`, Phase C, commit 4).
///
/// Reachable with **no project open** — joining is how one comes to exist on this replica in the
/// first place, so `OcptRoute.joining` carries none of the workspace/project settings/sharing
/// routes' own open-project guard.
class OcptJoiningPage extends StatelessWidget {
  /// Class constructor
  const OcptJoiningPage({super.key});

  @override
  Widget build(BuildContext context) =>
      BlocProvider(create: (context) => OcptJoiningBloc(), child: const OcptJoiningView());
}

/// The content of [OcptJoiningPage], separated from it so [OcptJoiningPage] only wires the
/// [OcptJoiningBloc] up (RFL3).
///
/// Public, like `OcptSharingView`, for the same reason: a widget test pumps it directly with a
/// `BlocProvider.value` wrapping an [OcptJoiningBloc] built over injected managers.
class OcptJoiningView extends StatefulWidget {
  /// Class constructor
  const OcptJoiningView({super.key});

  @override
  State<OcptJoiningView> createState() => _OcptJoiningViewState();
}

/// The state of [OcptJoiningView]: which of the two tabs is shown — pure UI navigation with no
/// project data behind it, so it lives here rather than in [OcptJoiningState], exactly the
/// reasoning `OcptSharingConfigureView`'s own text controllers already follow.
class _OcptJoiningViewState extends State<OcptJoiningView> {
  /// The tab currently shown — the scanner tab first on mobile (there being a real camera to show),
  /// the manual tab first everywhere else.
  late _OcptJoiningTab _selectedTab = globalGetIt().get<PlatformManager>().isMobile
      ? _OcptJoiningTab.scanner
      : _OcptJoiningTab.manual;

  @override
  Widget build(BuildContext context) => BlocConsumer<OcptJoiningBloc, OcptJoiningState>(
    listenWhen: (previous, current) => current.joinFailed && !previous.joinFailed,
    listener: _onJoinFailed,
    builder: (context, state) {
      final tr = Tr.of(context);
      final theme = Theme.of(context);

      return Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: () => globalGetIt().get<OcptRouterManager>().pop()),
          title: Text(tr.joiningPageTitle),
          actions: [
            _OcptJoiningChip(
              label: tr.joiningNoLocalCopyChip,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 16),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxContentWidth),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(tr.joiningIntro, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 18),
                  _buildSegmentedControl(tr, theme),
                  const SizedBox(height: 18),
                  _buildSelectedTab(state),
                  const SizedBox(height: 16),
                  _buildNote(tr, theme),
                  if (state.isJoining) ...[
                    const SizedBox(height: 16),
                    const OcptJoiningProgressCard(),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    },
  );

  /// The segmented control switching between [_OcptJoiningTab.scanner] and
  /// [_OcptJoiningTab.manual], drawn on every platform — matching the Rejoindre mock-up's own
  /// always-visible two segments — even though only mobile ever shows a real camera behind the
  /// first one.
  Widget _buildSegmentedControl(Tr tr, ThemeData theme) => SegmentedButton<_OcptJoiningTab>(
    segments: [
      ButtonSegment(value: _OcptJoiningTab.scanner, label: Text(tr.joiningTabScanner)),
      ButtonSegment(value: _OcptJoiningTab.manual, label: Text(tr.joiningTabManual)),
    ],
    selected: {_selectedTab},
    showSelectedIcon: false,
    onSelectionChanged: (selection) => setState(() => _selectedTab = selection.first),
  );

  /// The content under the segmented control: the real scanner on mobile, a fixed "camera
  /// unavailable" card on every other platform, or the manual entry form.
  Widget _buildSelectedTab(OcptJoiningState state) {
    if (_selectedTab == _OcptJoiningTab.manual) {
      return OcptJoiningManualView(
        isJoining: state.isJoining,
        onJoinRequested: (inviteLinkText) => context
            .read<OcptJoiningBloc>()
            .add(OcptJoiningManualSubmittedEvent(inviteLinkText: inviteLinkText)),
      );
    }

    if (globalGetIt().get<PlatformManager>().isMobile) {
      return OcptJoiningScannerView(
        onScanned: (scannedText) =>
            context.read<OcptJoiningBloc>().add(OcptJoiningInviteScannedEvent(scannedText)),
      );
    }

    return _buildScannerUnavailableCard();
  }

  /// The camera-scan tab's own content on a platform with no camera at all.
  Widget _buildScannerUnavailableCard() {
    final tr = Tr.of(context);
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            Icon(
              Icons.videocam_off_outlined,
              size: 40,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              tr.joiningScannerUnavailableTitle,
              style: theme.textTheme.titleSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              tr.joiningScannerUnavailableMessage,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// The note explaining that joining downloads a full local copy of the project — the mock-up's
  /// own callout, shown under both tabs.
  Widget _buildNote(Tr tr, ThemeData theme) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: theme.colorScheme.primary.withValues(alpha: ocptSelectedStateAlpha),
      borderRadius: BorderRadius.circular(ocptRadiusMedium),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            tr.joiningNoteText,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary),
          ),
        ),
      ],
    ),
  );

  /// Shows [OcptJoiningState.joinFailed]'s own snack bar, then dispatches the event that clears
  /// it, so a later rebuild doesn't show it again — `OcptSharingView`'s own `_onPairingFailed`.
  void _onJoinFailed(BuildContext context, OcptJoiningState state) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(Tr.of(context).joiningErrorMessage)));
    context.read<OcptJoiningBloc>().add(const OcptJoiningErrorDismissedEvent());
  }
}

/// A small read-out pill, tinted with [color] — the Rejoindre screen's own top-bar chip ("No local
/// copy yet"), on the exact model of `OcptSharingChip`. Kept private to this page rather than
/// shared with the sharing page's own widget of the same shape: each page owns its own widgets.
class _OcptJoiningChip extends StatelessWidget {
  /// The text shown inside the chip.
  final String label;

  /// The colour tinting both the chip's background wash and its own text.
  final Color color;

  /// Class constructor
  const _OcptJoiningChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: ocptSelectedStateAlpha),
        borderRadius: BorderRadius.circular(ocptRadiusLarge),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
