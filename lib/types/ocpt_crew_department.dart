// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// The department a crew position belongs to, for grouping the catalogue `ocptCrewPositions`
/// prints and for the call sheet sections a production's crew list is organised into.
///
/// Derived from a position, never stored of its own: `person_positions` and
/// `shooting_slot_crew` carry a `positionId`, never a department, so this enum can be reshaped
/// freely as the catalogue grows. **Declaration order is the printed/grouping order everywhere
/// [OcptCrewDepartment.values] is walked** — the catalogue itself, the person sheet's positions
/// picker, the schedule's own crew section and the contact list.
enum OcptCrewDepartment {
  /// Directing the film: the director, the assistant directors, the script supervisor and the
  /// second unit's own director.
  direction,

  /// Production: the production manager, the line producer, the production administration and
  /// the production assistants.
  production,

  /// Unit management and locations: the unit manager and their assistants, the location manager.
  unit,

  /// Casting and extras: the casting director and their assistant, the extras coordination, the
  /// child wrangler.
  castingAndExtras,

  /// The camera department: the director of photography, the camera operators and their
  /// assistants, the video assist and remote camera technicians, the stills photographer.
  image,

  /// Electric and grip: the gaffer and the electricians, the key grip and the grips.
  electricAndGrip,

  /// The sound department: the sound engineer, the boom operator.
  sound,

  /// The art department (decoration): the production designer, the assistant art directors, the
  /// set decorator and dressers, the props, the set illustrator and graphic designer, the model
  /// maker.
  artDepartment,

  /// Construction, summarised rather than split into its own sub-trades (carpentry, plastering,
  /// painting, locksmithing…): a construction manager and a generic construction crew position.
  construction,

  /// Costume: the costume designer, the costume workshop, the dressers and the costume makers.
  costume,

  /// Hair and make-up: the key and assistant make-up artists, the key and assistant hair
  /// stylists.
  hairAndMakeUp,

  /// Special effects (physical, on-set effects — not post-production visual effects, which this
  /// catalogue does not cover): the supervisor, the assistant, the animatronics technician.
  specialEffects,

  /// Editing and post-production: picture editing, sound editing and mixing, Foley.
  postProduction,
}
