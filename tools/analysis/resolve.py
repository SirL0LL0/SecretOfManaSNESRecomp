"""resolve.py <file> <choices>  choices per conflict: u=upstream(HEAD) l=local b=upstream+local B=local+upstream"""
import sys, re
path, choices = sys.argv[1], sys.argv[2]
text = open(path, encoding='utf-8', newline='').read()
pat = re.compile(r'<<<<<<< [^\n]*\n(.*?)=======\n(.*?)>>>>>>> [^\n]*\n', re.S)
hunks = pat.findall(text)
if len(hunks) != len(choices):
    sys.exit('file has %d conflicts, %d choices given' % (len(hunks), len(choices)))
it = iter(choices)
def rep(m):
    c = next(it); u, l = m.group(1), m.group(2)
    return {'u': u, 'l': l, 'b': u + l, 'B': l + u}[c]
out = pat.sub(rep, text)
open(path, 'w', encoding='utf-8', newline='').write(out)
print(path, 'resolved', len(hunks))
