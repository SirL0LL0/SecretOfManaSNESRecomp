#include "som_spc_player.h"

#include "spc_player.h"
#include "snes/apu.h"
#include "snes/dsp.h"
#include <string.h>
#include <stdlib.h>

typedef struct SomSpcPlayer {
    SpcPlayer base;
    bool initialized;
} SomSpcPlayer;

static void SomSpcPlayer_Initialize(SpcPlayer *base) {
    SomSpcPlayer *self = (SomSpcPlayer *)base;
    if (self->initialized) return;
    self->initialized = true;
    /* Nothing special needed for initialization */
}

static void SomSpcPlayer_Upload(SpcPlayer *base, const uint8_t *data) {
    /* The framework calls this when the game uploads new SPC data to the APU.
     * We could intercept and patch the SPC data here if needed.
     * For now, just let the normal upload happen. */
    (void)data;
}

struct SpcPlayer *SomSpcPlayer_Create(void) {
    SomSpcPlayer *self = calloc(1, sizeof(SomSpcPlayer));
    if (!self) return NULL;
    self->base.initialize = SomSpcPlayer_Initialize;
    self->base.upload = SomSpcPlayer_Upload;
    self->base.dsp = NULL;  /* Will be set by framework */
    self->base.input_ports[0] = self->base.input_ports[1] = 
    self->base.input_ports[2] = self->base.input_ports[3] = 0;
    self->base.port_to_snes[0] = self->base.port_to_snes[1] = 
    self->base.port_to_snes[2] = self->base.port_to_snes[3] = 0;
    return &self->base;
}

void SomSpcPlayer_Destroy(struct SpcPlayer *base) {
    if (base) free(base);
}