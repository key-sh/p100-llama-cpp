import struct, sys
f = open(sys.argv[1], 'rb')
assert f.read(4) == b'GGUF', 'not a gguf file'
ver, = struct.unpack('<I', f.read(4))
nt,  = struct.unpack('<Q', f.read(8))
nk,  = struct.unpack('<Q', f.read(8))
SZ = {0:1,1:1,2:2,3:2,4:4,5:4,6:4,7:1,10:8,11:8,12:2}
def rs():
    n, = struct.unpack('<Q', f.read(8))
    return f.read(n)
def rv(t):
    if t in SZ:
        return f.read(SZ[t])
    if t == 8:
        return rs()
    if t == 9:
        et, = struct.unpack('<I', f.read(4))
        n, = struct.unpack('<Q', f.read(8))
        for _ in range(n):
            rv(et)
        return None
    raise Exception('unknown kv type %d' % t)
for _ in range(nk):
    rs(); t, = struct.unpack('<I', f.read(4)); rv(t)
print('gguf v%d tensors=%d kv=%d' % (ver, nt, nk))
for _ in range(nt):
    name = rs().decode('utf-8', 'replace')
    nd,  = struct.unpack('<I', f.read(4))
    dims = struct.unpack('%dq' % nd, f.read(8 * nd))
    t,   = struct.unpack('<I', f.read(4))
    off, = struct.unpack('<Q', f.read(8))
    if t not in (0, 8, 14):
        print('type %-3d %-44s %s' % (t, name, 'x'.join(str(d) for d in dims)))
print('done')
