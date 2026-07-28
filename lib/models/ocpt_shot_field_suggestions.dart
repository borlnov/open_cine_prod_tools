// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';

/// The project-wide suggestion lists the shot inspector's free-text fields with suggestions offer
/// (decision 6 of the shot list plan): every distinct, non-empty value already entered for that
/// field elsewhere in the project, sorted alphabetically, exactly as
/// `OcptShotListService.distinctShotSizes` and its five siblings return them.
///
/// Shooting day and the two multi-line fields (director's notes, location scouting) have no
/// suggestion list of their own: the service has no `distinct` query for shooting day, and a
/// multi-line note is never a closed vocabulary in the first place.
class OcptShotFieldSuggestions extends Equatable {
  /// The project's distinct shot sizes.
  final List<String> shotSizes;

  /// The project's distinct framings and compositions.
  final List<String> framings;

  /// The project's distinct camera moves.
  final List<String> cameraMoves;

  /// The project's distinct lenses.
  final List<String> lenses;

  /// The project's distinct recording formats.
  final List<String> recordingFormats;

  /// The project's distinct sound notes.
  final List<String> sounds;

  /// Class constructor
  const OcptShotFieldSuggestions({
    required this.shotSizes,
    required this.framings,
    required this.cameraMoves,
    required this.lenses,
    required this.recordingFormats,
    required this.sounds,
  });

  /// An [OcptShotFieldSuggestions] with every list empty, the shot list bloc's state before its
  /// first load resolves.
  const OcptShotFieldSuggestions.empty()
    : shotSizes = const [],
      framings = const [],
      cameraMoves = const [],
      lenses = const [],
      recordingFormats = const [],
      sounds = const [];

  /// Object properties
  @override
  List<Object?> get props => [shotSizes, framings, cameraMoves, lenses, recordingFormats, sounds];
}
