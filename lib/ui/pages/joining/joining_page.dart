// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/joining/joining_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/joining/joining_view.dart';

/// The "Rejoindre un projet partagé" full-screen route: pairing this replica to a project already
/// shared on a relay, by scanning the Partager screen's own QR code (tablet only) or by typing its
/// connection details by hand.
///
/// Reachable with **no project open** — joining is how one comes to exist on this replica in the
/// first place, so `OcptRoute.joining` carries none of the workspace/project settings/sharing
/// routes' own open-project guard.
class OcptJoiningPage extends StatelessWidget {
  /// Class constructor
  const OcptJoiningPage({super.key});

  /// Build the joining page as a [BlocProvider].
  @override
  Widget build(BuildContext context) =>
      BlocProvider(create: (context) => OcptJoiningBloc(), child: const OcptJoiningView());
}
