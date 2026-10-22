#ifndef SOM_MSU1_H
#define SOM_MSU1_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

typedef struct SomMsu1 SomMsu1;

SomMsu1 *SomMsu1Open(const char *directory, char *error, size_t error_size);
void SomMsu1Close(SomMsu1 *player);
unsigned SomMsu1TrackNumber(unsigned song, unsigned variant);
bool SomMsu1Select(SomMsu1 *player, unsigned song, unsigned variant);
void SomMsu1Reset(SomMsu1 *player);
void SomMsu1SetGain(SomMsu1 *player, int percent);
void SomMsu1Mix(SomMsu1 *player, int16_t *samples, int frames, int channels, int output_rate);
unsigned SomMsu1CurrentTrack(const SomMsu1 *player);
const char *SomMsu1Directory(const SomMsu1 *player);

#endif /* SOM_MSU1_H */