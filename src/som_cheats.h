#pragma once

/* Pro Action Replay cheats as a mod: see som_cheats.c. */

#include <stddef.h>
#include <stdint.h>

/* Register the trusted plugin the package's manifest names. Call once at
 * startup, before the mod runtime validates the plan. */
void SomCheatsRegister(void);

/* Before SnesInit: apply the enabled ROM-data cheats to the in-memory image. */
int SomCheatsPatchRom(uint8_t *rom, size_t size, char *error, size_t error_cap);

/* som_main.c: nonzero when the Italian translation was applied to the image. */
int SomLanguageItalian(void);
