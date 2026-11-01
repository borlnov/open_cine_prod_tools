// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';

/// What `OcptRelayHostManager.reconcileWithUpstream` reports of one push-then-pull between the
/// hosted relay and an upstream relay named by an `ocpt://join` invite — a value, never a thrown
/// exception across the UI boundary.
sealed class OcptReconcileOutcome extends Equatable {
  /// Class constructor
  const OcptReconcileOutcome();
}

/// The reconcile ran to completion. [pushed] and [pulled] are the counts a "Réconcilier amont…"
/// action shows as "pushed N, pulled M" — see `OcptRelayReconciler.reconcileProject`'s own doc
/// comment for exactly what each counts.
final class OcptReconcileSucceeded extends OcptReconcileOutcome {
  /// How many changesets this run sent to the upstream relay.
  final int pushed;

  /// How many changesets this run received from the upstream relay.
  final int pulled;

  /// Class constructor
  const OcptReconcileSucceeded({required this.pushed, required this.pulled});

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() => "OcptReconcileSucceeded(pushed: $pushed, pulled: $pulled)";

  /// Object properties
  @override
  List<Object?> get props => [pushed, pulled];
}

/// The reconcile did not run, or did not complete. [message] is a human-readable detail meant for
/// a log or a snackbar — never parsed.
final class OcptReconcileFailed extends OcptReconcileOutcome {
  /// A human-readable detail of what went wrong, meant for a log or a panel — never parsed.
  final String message;

  /// Class constructor
  const OcptReconcileFailed(this.message);

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() => "OcptReconcileFailed(message: $message)";

  /// Object properties
  @override
  List<Object?> get props => [message];
}
