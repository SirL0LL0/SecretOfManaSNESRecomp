#ifndef SOM_SPC_PLAYER_H
#define SOM_SPC_PLAYER_H

#include "spc_player.h"

#ifdef __cplusplus
extern "C" {
#endif

struct SpcPlayer *SomSpcPlayer_Create(void);
void SomSpcPlayer_Destroy(struct SpcPlayer *base);

#ifdef __cplusplus
}
#endif

#endif /* SOM_SPC_PLAYER_H */