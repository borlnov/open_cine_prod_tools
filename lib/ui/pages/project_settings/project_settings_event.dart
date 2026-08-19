// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/types/ocpt_screenplay_language.dart';

/// The events handled by `OcptProjectSettingsBloc`.
sealed class OcptProjectSettingsEvent extends BlocEventForMixin {
  /// Class constructor
  const OcptProjectSettingsEvent();
}

/// Requests loading the current project's currency and page format into the page.
///
/// This is dispatched once by the bloc's own constructor; it isn't meant to be sent by widgets.
class OcptProjectSettingsLoadRequestedEvent extends OcptProjectSettingsEvent {
  /// Class constructor
  const OcptProjectSettingsLoadRequestedEvent();
}

/// Reports that the user picked a different currency in the picker.
class OcptProjectSettingsCurrencyChangedEvent extends OcptProjectSettingsEvent {
  /// The ISO 4217 code the user picked.
  final String currencyCode;

  /// Class constructor
  const OcptProjectSettingsCurrencyChangedEvent({required this.currencyCode});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, currencyCode];
}

/// Reports that the user picked a different page format in the dropdown.
class OcptProjectSettingsPageFormatChangedEvent extends OcptProjectSettingsEvent {
  /// The page format the user picked.
  final OcptPageFormat pageFormat;

  /// Class constructor
  const OcptProjectSettingsPageFormatChangedEvent({required this.pageFormat});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, pageFormat];
}

/// Reports that the user committed a new minimum rest, in minutes, or cleared it — [minutes] null
/// meaning the field was submitted empty, a real gesture as much as typing a figure is.
class OcptProjectSettingsMinimumRestMinutesChangedEvent extends OcptProjectSettingsEvent {
  /// The newly committed minimum, in minutes, or null to clear it.
  final int? minutes;

  /// Class constructor
  const OcptProjectSettingsMinimumRestMinutesChangedEvent({required this.minutes});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, minutes];
}

/// Reports that the user picked a different screenplay language in the dropdown, including "None"
/// (null) — a real gesture, turning the checker off for this screenplay, as much as picking one of
/// the two bundled languages is.
class OcptProjectSettingsScreenplayLanguageChangedEvent extends OcptProjectSettingsEvent {
  /// The screenplay language the user picked, or null for "None".
  final OcptScreenplayLanguage? screenplayLanguage;

  /// Class constructor
  const OcptProjectSettingsScreenplayLanguageChangedEvent({required this.screenplayLanguage});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, screenplayLanguage];
}

/// Reports that the `Episodes` card's `+ Add` action was tapped, appending a new episode.
class OcptProjectSettingsEpisodeAddedEvent extends OcptProjectSettingsEvent {
  /// Class constructor
  const OcptProjectSettingsEpisodeAddedEvent();
}

/// Reports that the user committed a new title for episode [screenplayId] — the empty string is a
/// legal title, read as "untitled" (`OcptEpisode.title`'s own doc comment), not a reversion.
class OcptProjectSettingsEpisodeTitleChangedEvent extends OcptProjectSettingsEvent {
  /// The id of the episode (a `screenplays` row) whose title was committed.
  final String screenplayId;

  /// The newly committed title, or the empty string.
  final String title;

  /// Class constructor
  const OcptProjectSettingsEpisodeTitleChangedEvent({required this.screenplayId, required this.title});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, screenplayId, title];
}

/// Reports that the user committed a new printed number for episode [screenplayId]. Carries no
/// uniqueness guarantee of its own — two episodes sharing a number is a state the user reaches by
/// hand and repairs by hand (`docs/adr/0019-one-project-several-episodes.md`).
class OcptProjectSettingsEpisodeNumberChangedEvent extends OcptProjectSettingsEvent {
  /// The id of the episode (a `screenplays` row) whose number was committed.
  final String screenplayId;

  /// The newly committed number.
  final int number;

  /// Class constructor
  const OcptProjectSettingsEpisodeNumberChangedEvent({
    required this.screenplayId,
    required this.number,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, screenplayId, number];
}

/// Reports that episode [screenplayId] was moved to [newPosition] (0-based, among the project's
/// live episodes) through the card's own `▲`/`▼` controls. Only `sortKey` is affected — the
/// printed `number` is never renumbered by a reorder.
class OcptProjectSettingsEpisodeMovedEvent extends OcptProjectSettingsEvent {
  /// The id of the episode (a `screenplays` row) being moved.
  final String screenplayId;

  /// The 0-based position it is moved to among the project's live episodes.
  final int newPosition;

  /// Class constructor
  const OcptProjectSettingsEpisodeMovedEvent({required this.screenplayId, required this.newPosition});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, screenplayId, newPosition];
}

/// Reports that the user confirmed, through `OcptConfirmDialog` (opened by the page, never by the
/// card), deleting episode [screenplayId].
class OcptProjectSettingsEpisodeDeletionConfirmedEvent extends OcptProjectSettingsEvent {
  /// The id of the episode (a `screenplays` row) to delete.
  final String screenplayId;

  /// Class constructor
  const OcptProjectSettingsEpisodeDeletionConfirmedEvent({required this.screenplayId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, screenplayId];
}
