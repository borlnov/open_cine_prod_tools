// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:act_platform_manager/act_platform_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart' as ocpt_theme;
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/ui/pages/joining/joining_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/joining/joining_event.dart';
import 'package:open_cine_prod_tools/ui/pages/joining/joining_state.dart';
import 'package:open_cine_prod_tools/ui/pages/joining/widgets/ocpt_joining_manual_view.dart';
import 'package:open_cine_prod_tools/ui/pages/joining/widgets/ocpt_joining_scan_status.dart';
import 'package:open_cine_prod_tools/ui/pages/joining/widgets/ocpt_joining_scanner_view.dart';
import 'package:open_cine_prod_tools/ui/pages/joining/widgets/ocpt_joining_status_overlay.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_readout_chip.dart';

/// The maximum width of the page's own column, matching the Partager screen's own ①/② forms.
const _maxContentWidth = 560.0;

/// The Rejoindre screen's own two tabs.
enum _OcptJoiningTab {
  /// The camera scan tab, real only on mobile — a fixed "camera unavailable" card everywhere else.
  scanner,

  /// The manual relay address/project id/token entry tab.
  manual,
}

/// The content of `OcptJoiningPage`, separated from it so `OcptJoiningPage` only wires the
/// [OcptJoiningBloc] up.
///
/// Public, like `OcptSharingView`, for the same reason: a widget test pumps it directly with a
/// `BlocProvider.value` wrapping an [OcptJoiningBloc] built over injected managers.
class OcptJoiningView extends StatefulWidget {
  /// Class constructor
  const OcptJoiningView({super.key});

  /// Create the [_OcptJoiningViewState] holding the state of the joining view.
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

  /// The scanner frame's own current status — see `OcptJoiningScanFrame`. Tracked here, rather
  /// than read off `OcptJoiningState` directly, since a manual-entry failure must not paint the
  /// camera frame red: only [_lastSubmissionFromScanner] tells the two apart.
  OcptJoiningScanStatus _scanStatus = OcptJoiningScanStatus.idle;

  /// Whether the last submission the bloc is currently acting on (or last reacted to a failure
  /// for) came from the scanner tab rather than the manual form — see [_scanStatus].
  bool _lastSubmissionFromScanner = false;

  /// Build the joining view as a [BlocConsumer].
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
            OcptReadoutChip(
              label: tr.joiningNoLocalCopyChip,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 16),
          ],
        ),
        body: Stack(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _maxContentWidth),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(tr.joiningIntro, style: theme.textTheme.bodyMedium),
                      const SizedBox(height: 18),
                      _OcptJoiningSegmentedControl(
                        selectedTab: _selectedTab,
                        onSelected: (tab) => setState(() => _selectedTab = tab),
                      ),
                      const SizedBox(height: 18),
                      _OcptJoiningSelectedTab(
                        selectedTab: _selectedTab,
                        isJoining: state.isJoining,
                        scanStatus: _scanStatus,
                        onManualJoinRequested: _onManualJoinRequested,
                        onScanned: _onScanned,
                      ),
                      const SizedBox(height: 16),
                      const _OcptJoiningNote(),
                    ],
                  ),
                ),
              ),
            ),
            if (state.isJoining || state.joinSucceeded)
              OcptJoiningStatusOverlay(
                step: state.joinStep,
                succeeded: state.joinSucceeded,
                onCancelRequested: () =>
                    context.read<OcptJoiningBloc>().add(const OcptJoiningCancelledEvent()),
                onOpenRequested: () =>
                    context.read<OcptJoiningBloc>().add(const OcptJoiningOpenRequestedEvent()),
              ),
          ],
        ),
      );
    },
  );

  /// Ask the bloc to join from the invite link typed on the manual tab.
  void _onManualJoinRequested(String inviteLinkText) {
    _lastSubmissionFromScanner = false;
    context.read<OcptJoiningBloc>().add(
      OcptJoiningManualSubmittedEvent(
        inviteLinkText: inviteLinkText,
        destinationConfirmButtonText: Tr.of(context).joiningDestinationConfirmAction,
      ),
    );
  }

  /// Ask the bloc to join from the invite the scanner decoded.
  void _onScanned(String scannedText) {
    // Optimistic: the code was successfully decoded, which is the whole of what "a valid
    // scan" means here — whether it turns out to be a valid invite at all is for the bloc to
    // decide, and [_onJoinFailed] corrects the colour to red if it wasn't.
    setState(() {
      _lastSubmissionFromScanner = true;
      _scanStatus = OcptJoiningScanStatus.success;
    });
    context.read<OcptJoiningBloc>().add(
      OcptJoiningInviteScannedEvent(
        scannedText,
        destinationConfirmButtonText: Tr.of(context).joiningDestinationConfirmAction,
      ),
    );
  }

  /// Show [OcptJoiningState.joinFailed]'s own snack bar, then dispatch the event that clears
  /// it, so a later rebuild doesn't show it again — `OcptSharingView`'s own `_onPairingFailed`.
  ///
  /// Also flashes the scanner frame red when the failed attempt came from a scan
  /// ([_lastSubmissionFromScanner]) — a manual-entry failure leaves it untouched.
  void _onJoinFailed(BuildContext context, OcptJoiningState state) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(Tr.of(context).joiningErrorMessage)));
    context.read<OcptJoiningBloc>().add(const OcptJoiningErrorDismissedEvent());

    if (_lastSubmissionFromScanner) {
      setState(() => _scanStatus = OcptJoiningScanStatus.error);
    }
  }
}

/// The segmented control switching between [_OcptJoiningTab.scanner] and
/// [_OcptJoiningTab.manual], drawn on every platform — matching the Rejoindre mock-up's own
/// always-visible two segments — even though only mobile ever shows a real camera behind the
/// first one.
class _OcptJoiningSegmentedControl extends StatelessWidget {
  /// The tab currently shown.
  final _OcptJoiningTab selectedTab;

  /// Called with the tab the user picked.
  final ValueChanged<_OcptJoiningTab> onSelected;

  /// Class constructor
  const _OcptJoiningSegmentedControl({required this.selectedTab, required this.onSelected});

  /// Build the joining segmented control as a [SegmentedButton].
  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return SegmentedButton<_OcptJoiningTab>(
      segments: [
        ButtonSegment(value: _OcptJoiningTab.scanner, label: Text(tr.joiningTabScanner)),
        ButtonSegment(value: _OcptJoiningTab.manual, label: Text(tr.joiningTabManual)),
      ],
      selected: {selectedTab},
      showSelectedIcon: false,
      onSelectionChanged: (selection) => onSelected(selection.first),
    );
  }
}

/// The content under the segmented control: the real scanner on mobile, a fixed "camera
/// unavailable" card on every other platform, or the manual entry form.
class _OcptJoiningSelectedTab extends StatelessWidget {
  /// The tab currently shown.
  final _OcptJoiningTab selectedTab;

  /// Whether the bloc is joining right now.
  final bool isJoining;

  /// The scanner frame's current status.
  final OcptJoiningScanStatus scanStatus;

  /// Called with the invite link typed on the manual tab.
  final ValueChanged<String> onManualJoinRequested;

  /// Called with the text the scanner decoded.
  final ValueChanged<String> onScanned;

  /// Class constructor
  const _OcptJoiningSelectedTab({
    required this.selectedTab,
    required this.isJoining,
    required this.scanStatus,
    required this.onManualJoinRequested,
    required this.onScanned,
  });

  /// Build the joining selected tab.
  @override
  Widget build(BuildContext context) {
    if (selectedTab == _OcptJoiningTab.manual) {
      return OcptJoiningManualView(isJoining: isJoining, onJoinRequested: onManualJoinRequested);
    }

    if (globalGetIt().get<PlatformManager>().isMobile) {
      return OcptJoiningScannerView(status: scanStatus, onScanned: onScanned);
    }

    return const _OcptJoiningScannerUnavailableCard();
  }
}

/// The camera-scan tab's own content on a platform with no camera at all.
class _OcptJoiningScannerUnavailableCard extends StatelessWidget {
  /// Class constructor
  const _OcptJoiningScannerUnavailableCard();

  /// Build the joining scanner unavailable card as a [Card].
  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            Icon(Icons.videocam_off_outlined, size: 40, color: theme.colorScheme.onSurfaceVariant),
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
}

/// The note explaining that joining downloads a full local copy of the project — the mock-up's
/// own callout, shown under both tabs.
class _OcptJoiningNote extends StatelessWidget {
  /// Class constructor
  const _OcptJoiningNote();

  /// Build the joining note as a [Container].
  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: ocpt_theme.ocptSelectedStateAlpha),
        borderRadius: BorderRadius.circular(ocpt_theme.ocptRadiusMedium),
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
  }
}
