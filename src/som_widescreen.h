#pragma once

/* Widescreen for Secret of Mana as a mod (Mods → Display → Widescreen): see
 * som_widescreen.c. */

#include <stddef.h>
#include <stdint.h>

#include "desktop/display_aspect.h"

/* Register the trusted plugin the package names (and its reset hook). Call
 * once at startup, before the mod runtime validates the plan. */
void SomWidescreenRegister(void);

/* Desktop host presenter hooks (SnesDesktopHostGame). */
void SomWidescreenPrepareFrame(int drawable_w, int drawable_h, int *frame_w, int *frame_h);
void SomWidescreenEndFrame(const uint8_t *field, unsigned number);
int SomWidescreenDrawFrame(uint8_t *dst, size_t pitch, const uint8_t *field,
                           int frame_w, int frame_h, double alpha);
void SomWidescreenViewport(int frame_w, int frame_h, int drawable_w, int drawable_h,
                           SnesDisplayViewport *viewport);
int SomWidescreenWindowWidth(int frame_w);
