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

/// Reports that the user committed a new default VAT rate, in basis points, or cleared it —
/// whether by submitting the field empty, submitting it negative, or tapping the card's own
/// `No rate` button; [basisPoints] null meaning "not recorded", a real gesture as much as recording
/// `0` (an explicit exemption) is.
class OcptProjectSettingsDefaultVatRateBasisPointsChangedEvent extends OcptProjectSettingsEvent {
  /// The newly committed rate, in basis points, or null to clear it.
  final int? basisPoints;

  /// Class constructor
  const OcptProjectSettingsDefaultVatRateBasisPointsChangedEvent({required this.basisPoints});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, basisPoints];
}

/// Reports that the user committed a new meal price, in cents, or cleared it — [cents] null meaning
/// the field was submitted empty, a real gesture as much as typing a figure is.
class OcptProjectSettingsMealPriceCentsChangedEvent extends OcptProjectSettingsEvent {
  /// The newly committed price, in cents, or null to clear it.
  final int? cents;

  /// Class constructor
  const OcptProjectSettingsMealPriceCentsChangedEvent({required this.cents});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, cents];
}

/// Reports that the user committed a new snack price, in cents, or cleared it —
/// [OcptProjectSettingsMealPriceCentsChangedEvent]'s sibling.
class OcptProjectSettingsSnackPriceCentsChangedEvent extends OcptProjectSettingsEvent {
  /// The newly committed price, in cents, or null to clear it.
  final int? cents;

  /// Class constructor
  const OcptProjectSettingsSnackPriceCentsChangedEvent({required this.cents});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, cents];
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

/// Reports the words `OcptProjectDictionaryDialog` added and removed from its working copy —
/// that dialog only reports, so this event is what actually applies the diff to the project's
/// dictionary, through `OcptProjectDictionaryService` (`docs/architecture/foundations.md`).
class OcptProjectSettingsDictionaryEditedEvent extends OcptProjectSettingsEvent {
  /// The words the dialog's working copy gained that the project's dictionary didn't already
  /// hold.
  final List<String> addedWords;

  /// The words the project's dictionary held that the dialog's working copy no longer does.
  final List<String> removedWords;

  /// Class constructor
  const OcptProjectSettingsDictionaryEditedEvent({
    required this.addedWords,
    required this.removedWords,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, addedWords, removedWords];
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

/// Reports that the `Mileage rates` card's `Add a rate` action was tapped, appending a new,
/// blank rate.
class OcptProjectSettingsMileageRateAddedEvent extends OcptProjectSettingsEvent {
  /// Class constructor
  const OcptProjectSettingsMileageRateAddedEvent();
}

/// Reports that the user committed a new label for mileage rate [rateId] — the empty string is a
/// legal label, exactly as an episode's title is.
class OcptProjectSettingsMileageRateLabelChangedEvent extends OcptProjectSettingsEvent {
  /// The id of the mileage rate whose label was committed.
  final String rateId;

  /// The newly committed label, or the empty string.
  final String label;

  /// Class constructor
  const OcptProjectSettingsMileageRateLabelChangedEvent({required this.rateId, required this.label});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, rateId, label];
}

/// Reports that the user committed a new per-kilometre rate for mileage rate [rateId], in
/// thousandths of a cent.
class OcptProjectSettingsMileageRateAmountChangedEvent extends OcptProjectSettingsEvent {
  /// The id of the mileage rate whose amount was committed.
  final String rateId;

  /// The newly committed rate, in thousandths of a cent.
  final int ratePerKmMilliCents;

  /// Class constructor
  const OcptProjectSettingsMileageRateAmountChangedEvent({
    required this.rateId,
    required this.ratePerKmMilliCents,
  });

  /// Object properties
  @override
  List<Object?> get props => [...super.props, rateId, ratePerKmMilliCents];
}

/// Reports that the user confirmed, through `OcptConfirmDialog` (opened by the page, never by the
/// card), deleting mileage rate [rateId].
///
/// This tombstones the row (`OcptBudgetFinancingService.deleteMileageRate`, ADR 0010) rather than
/// erasing it: a live person may still name it through `people.mileageRateId`, and the FK stays
/// satisfied either way — the travel reading of such a person then finds no live rate and reads
/// "no rate", exactly the honest state a person who never named one reads as.
class OcptProjectSettingsMileageRateDeletionConfirmedEvent extends OcptProjectSettingsEvent {
  /// The id of the mileage rate to delete.
  final String rateId;

  /// Class constructor
  const OcptProjectSettingsMileageRateDeletionConfirmedEvent({required this.rateId});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, rateId];
}
