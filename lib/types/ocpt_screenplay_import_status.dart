// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_dart_result/act_dart_result.dart';

/// The outcome of picking a screenplay file and reading it as Fountain text.
///
/// This is used as the [ResultWithStatus] status of `OcptExportManager.pickAndReadScreenplay`,
/// which is what the two import gestures — the home page's `A screenplay` card and the editor's
/// `Import and replace…` — both go through. A cancelled dialog is one of these rather than a null
/// result: once a foreign file can be refused for being unreadable, "nothing came back" no longer
/// tells the two apart.
enum OcptScreenplayImportStatus with MixinResultStatus {
  /// The file was picked and read: its Fountain text is the result's value.
  ok(isSuccess: true, canBeRetried: false),

  /// The user cancelled the open dialog, or the selection failed.
  ///
  /// A silent no-op for every caller: the OS dialog itself already reported a failed selection, and
  /// a cancellation is not something to state back to the user.
  cancelled(isSuccess: false, canBeRetried: false),

  /// The picked file could not be read as a screenplay at all: it is not the format its extension
  /// claims, its container is broken, or it holds no script document. Retryable because picking
  /// another file is all it takes.
  unreadableFile(isSuccess: false, canBeRetried: true),

  /// The picked file's bytes could not be read (it went away, a permission denied it).
  ioError(isSuccess: false, canBeRetried: true);

  /// {@macro act_dart_result.MixinResultStatus.isSuccess}
  @override
  final bool isSuccess;

  /// {@macro act_dart_result.MixinResultStatus.canBeRetried}
  @override
  final bool canBeRetried;

  /// Class constructor
  const OcptScreenplayImportStatus({required this.isSuccess, required this.canBeRetried});
}
