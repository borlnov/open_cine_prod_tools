// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/sharing/hosting_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/sharing/sharing_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/sharing/sharing_state.dart';
import 'package:open_cine_prod_tools/ui/pages/sharing/sharing_view.dart';

/// The "Partager" (sharing) screen for the currently open project: pairing it to a relay so a team
/// can join it, and inviting them once it is.
///
/// One screen, two states, told apart by [OcptSharingState.invite]: ① Configure — a relay address
/// and an enrolment secret, and the button that pairs the project and creates it on the relay — and
/// ② Invite — the QR code and the connection details a teammate's own Rejoindre screen reads
/// instead, and the way to stop sharing.
///
/// Reachable only while a project is open (`OcptRouterManager`'s guard, mirroring the workspace and
/// project settings routes' own).
class OcptSharingPage extends StatelessWidget {
  /// Class constructor
  const OcptSharingPage({super.key});

  /// Build the sharing page as a [MultiBlocProvider].
  @override
  Widget build(BuildContext context) => MultiBlocProvider(
    providers: [
      BlocProvider(create: (context) => OcptSharingBloc()),
      BlocProvider(create: (context) => OcptHostingBloc()),
    ],
    child: const OcptSharingView(),
  );
}
