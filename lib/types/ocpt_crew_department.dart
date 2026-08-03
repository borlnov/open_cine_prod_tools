// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// The department a crew position belongs to, for grouping the catalogue `ocptCrewPositions`
/// prints and for the call sheet sections a production's crew list is organised into.
enum OcptCrewDepartment {
  /// Directing the film: the director, the assistant director(s), the script supervisor.
  direction,

  /// The camera department: the director of photography, camera operators, camera assistants,
  /// electricians and grips.
  image,

  /// The sound department: the sound engineer, the boom operator.
  sound,

  /// The art department: the set decorator, the props master, set dressers.
  artDepartment,

  /// Hair, make-up and costume (HMC): the make-up artist, the hairstylist, the costume designer.
  hmc,

  /// Production: the production manager, production assistants, the line producer.
  production,
}
