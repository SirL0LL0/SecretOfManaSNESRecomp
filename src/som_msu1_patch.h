#pragma once

/* DarkShock's Secret of Mana MSU-1 hack (v1.0), as a mod: see som_msu1_patch.c. */

#include <stddef.h>

/* Before SnesInit: when the "som.msu1" feature is enabled, point the
 * framework's MSU-1 chip at the selected music pack folder. Returns 0 (with
 * `error`) when the feature is on but its folder cannot be used. */
int SomMsu1PatchPrepare(char *error, size_t error_cap);

/* Register the trusted plugin the package's manifest names. Call once at
 * startup, before the mod runtime validates the plan. */
void SomMsu1PatchRegister(void);

/* The guest timeline jumped (save-state load, rewind): restart the track the
 * game believes is playing, since MSU-1 playback is not part of a state. */
void SomMsu1PatchTimelineJumped(void);
