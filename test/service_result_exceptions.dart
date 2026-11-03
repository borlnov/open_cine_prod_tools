// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// What the rules of `service_result_rules.dart` let through on purpose, each with its reason.
library;

/// The methods whose `guardResult` or `guardOutcome` body may wrap a call in `valueOrAbort` or
/// `okOrAbort` without a transaction of their own, each with the reason: the guard catches the
/// abort and answers its failure, and that is only wanted where the caller turns the answer back
/// into a throw inside a transaction of its own.
const abortInGuardBodyMethods = <String, String>{
  "mergeIncomingFountainText":
      "its caller's transaction wraps it and throws on the failure it answers",
};

/// The helpers declared in another file that take a closure answering a result, and so may be
/// handed one that returns a converted call. None yet.
const helpersTakingAResult = <String>{};

/// The receivers that reach a participant of the same name as a converted method of another
/// service, so that a call on them is not a call of the converted one.
const homonymReceivers = <String, Set<String>>{
  "reconcile": {"roleIndexService", "_roleIndexService"},
};
