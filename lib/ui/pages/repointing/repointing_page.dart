// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/repointing/repointing_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/repointing/repointing_state.dart';
import 'package:open_cine_prod_tools/ui/pages/repointing/repointing_view.dart';

/// The "Changer de relais" screen for the currently open project: moving its ongoing sync from the
/// relay it is paired to onto another one.
///
/// One screen, two states, told apart by [OcptRepointingState.enrolment]: ① Configure — a relay
/// address and an enrolment secret, typed or scanned off another relay's own enrolment QR, and the
/// button that moves the project there — and ② QR code — the enrolment QR the next crew member
/// scans to do the very same thing, on the exact model of the Partager screen's own
/// Configure→Invite shape (`lib/ui/pages/sharing/`), except this screen always opens on ①, even
/// for a project already paired: re-pointing is a repeatable action, not a one-time setup.
///
/// Reachable only while a project is open (`OcptRouterManager`'s guard, mirroring the sharing
/// route's own).
class OcptRepointingPage extends StatelessWidget {
  /// Class constructor
  const OcptRepointingPage({super.key});

  /// Build the repointing page as a [BlocProvider].
  @override
  Widget build(BuildContext context) =>
      BlocProvider(create: (context) => OcptRepointingBloc(), child: const OcptRepointingView());
}
