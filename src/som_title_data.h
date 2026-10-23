#pragma once

/* Queue's title screen image restoration (from Secret of Mana Plus 2.1 by
 * Tomm): see som_title_data.c and SomApplyTitle in som_main.c. */

#include <stdint.h>

#define SOM_TITLE_JUMP_AT 0x014CF7u    /* C1:4CF7, operand of JML $7EAF0B */
#define SOM_TITLE_BLOCK_AT 0x2FC000u   /* EF:C000 */
#define SOM_TITLE_BLOCK_SIZE 0x38A0u   /* to EF:F89F */
#define SOM_TITLE_IMAGE_SIZE 0x300000u /* 3 MB */

extern const uint8_t kSomTitleJump[3];
extern const uint8_t kSomTitleBlock[SOM_TITLE_BLOCK_SIZE];
