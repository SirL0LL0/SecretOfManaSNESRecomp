#ifndef SOM_MUSIC_H
#define SOM_MUSIC_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

struct Apu;

void SomMusicInitialize(void);
bool SomMusicLoad(const char *directory);
void SomMusicSetEnabled(bool enabled);
bool SomMusicEnabled(void);
void SomMusicSetGain(int percent);
int SomMusicGain(void);
const char *SomMusicDirectory(void);
const char *SomMusicStatus(void);
bool SomMusicSaveSettings(void);
void SomMusicFrame(struct Apu *apu, uint8_t *rom, size_t size, const uint8_t *ram);
void SomMusicCommand(uint16_t song, uint16_t command);
void SomMusicStateLoaded(struct Apu *apu, const uint8_t *ram);
void SomMusicMix(int16_t *samples, int frames, int rate);

#ifdef __cplusplus
}
#endif

#endif /* SOM_MUSIC_H */