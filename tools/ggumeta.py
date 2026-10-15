# ggumeta.py - dump the GGUF metadata KV section (incremental reads, stdlib only)
# usage: python ggumeta.py <model.gguf> [-a]   (-a prints tokenizer.* keys too)
import struct, sys, time

TYPENAME = {0:'u8',1:'i8',2:'u16',3:'i16',4:'u32',5:'i32',6:'f32',7:'bool',8:'str',9:'arr',10:'u64',11:'i64',12:'f64'}

class R:
    def __init__(self, f):
        self.f = f
    def rd(self, n):
        b = self.f.read(n)
        if len(b) != n:
            raise EOFError('unexpected EOF at 0x%x' % self.f.tell())
        return b

def val(r, t):
    if t == 0: return r.rd(1)[0]
    if t == 1: return struct.unpack('<b', r.rd(1))[0]
    if t == 2: return struct.unpack('<H', r.rd(2))[0]
    if t == 3: return struct.unpack('<h', r.rd(2))[0]
    if t == 4: return struct.unpack('<I', r.rd(4))[0]
    if t == 5: return struct.unpack('<i', r.rd(4))[0]
    if t == 6: return struct.unpack('<f', r.rd(4))[0]
    if t == 7: return r.rd(1)[0]
    if t == 8:
        n = struct.unpack('<Q', r.rd(8))[0]
        return r.rd(n).decode('utf-8', 'replace')
    if t == 9:
        at = struct.unpack('<I', r.rd(4))[0]
        n = struct.unpack('<Q', r.rd(8))[0]
        if at == 8:
            for _ in range(n):
                m = struct.unpack('<Q', r.rd(8))[0]
                r.rd(m)
            return '<str[%d]>' % n
        if at == 9:
            raise ValueError('nested array not supported')
        head = [val(r, at) for _ in range(min(n, 6))]
        for _ in range(n - len(head)):
            val(r, at)
        return '%s[%d] head=%s' % (TYPENAME.get(at, at), n, head)
    if t == 10: return struct.unpack('<Q', r.rd(8))[0]
    if t == 11: return struct.unpack('<q', r.rd(8))[0]
    if t == 12: return struct.unpack('<d', r.rd(8))[0]
    raise ValueError('unknown gguf value type %d at 0x%x' % (t, r.f.tell()))

def main(path, all_keys):
    with open(path, 'rb') as f:
        r = R(f)
        magic = r.rd(4)
        if magic != b'GGUF':
            sys.exit('not a gguf file (magic=%r)' % magic)
        version = struct.unpack('<I', r.rd(4))[0]
        tensor_count = struct.unpack('<Q', r.rd(8))[0]
        kv_count = struct.unpack('<Q', r.rd(8))[0]
        print('gguf_version=%d tensor_count=%d kv_count=%d' % (version, tensor_count, kv_count))
        t0 = time.time()
        for _ in range(kv_count):
            k = val(r, 8)
            t = struct.unpack('<I', r.rd(4))[0]
            v = val(r, t)
            if all_keys or not (k.startswith('tokenizer.') or k == 'chat_template'):
                print('%s = %s' % (k, v))
        print('[kv_section_bytes=%d elapsed=%.2fs]' % (f.tell(), time.time() - t0))

if __name__ == '__main__':
    args = [a for a in sys.argv[1:] if a != '-a']
    if not args:
        sys.exit('usage: python ggumeta.py <model.gguf> [-a]')
    main(args[0], '-a' in sys.argv)
