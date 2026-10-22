#ifndef SOM_CONFIG_H
#define SOM_CONFIG_H

/* Secret of Mana port configuration header.
 * Provided as a stub for framework headers that expect it.
 * Runtime policy flags are passed as compile definitions instead. */

#ifndef SNESRECOMP_TRACE
#define SNESRECOMP_TRACE 0
#endif
#ifndef SNESRECOMP_FRAME_FINGERPRINTS
#define SNESRECOMP_FRAME_FINGERPRINTS 0
#endif
#ifndef SNESRECOMP_PPU_DMA_HISTORY
#define SNESRECOMP_PPU_DMA_HISTORY 0
#endif
#ifndef SNESRECOMP_DISPATCH_HISTORY
#define SNESRECOMP_DISPATCH_HISTORY 0
#endif
#ifndef SNESRECOMP_EXPOSE_COVERAGE_MOD
#define SNESRECOMP_EXPOSE_COVERAGE_MOD 0
#endif
#ifndef SNESRECOMP_ENABLE_MODS
#define SNESRECOMP_ENABLE_MODS 0
#endif

#endif /* SOM_CONFIG_H */
