"""Write src/som_title_data.c from a SoMPlus 2.1 image (US + any difficulty patch)."""
import hashlib
import sys

img = open(sys.argv[1], 'rb').read()
out = sys.argv[2]
jump = img[0x014CF7:0x014CFA]
block = img[0x2FC000:0x2FF8A0]
assert jump == bytes([0x00, 0xF8, 0xEF]), jump.hex()
digest = hashlib.sha256(jump + block).hexdigest()
assert digest == '84dd9f0ddfef1176331709117f6b768cb43a69007766e8e671ade27bebbbd9a2', digest
lines = []
for i in range(0, len(block), 16):
    lines.append('    ' + ', '.join(f'0x{b:02X}' for b in block[i:i + 16]) + ',')
src = f'''/* Title screen image restoration by Queue, as shipped in Secret of Mana Plus
 * 2.1 by Tomm (hackofmana.com, romhacking.net hack 8491), from which these
 * bytes are taken unchanged. See src/som_main.c (SomApplyTitle).
 *
 * kSomTitleBlock is EF:C000-EF:F89F of that image: the compressed Japanese
 * title image (EF:C000) and Queue's routine (EF:F800) that points the intro's
 * WRAM code at it. SHA-256 of jump operand + block: {digest}. */
#include "som_title_data.h"

const uint8_t kSomTitleJump[3] = {{0x{jump[0]:02X}, 0x{jump[1]:02X}, 0x{jump[2]:02X}}};

const uint8_t kSomTitleBlock[{len(block)}] = {{
{chr(10).join(lines)}
}};
'''
open(out, 'w', newline='\n').write(src)
print(out, len(block), digest)
