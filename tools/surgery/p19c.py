# -*- coding: utf-8 -*-
import shutil, sys

path = r"D:\temp\p19b_spike.cu"
bak  = r"D:\temp\p19b_spike.cu.bak_topo"

with open(path, "r", encoding="ascii", newline="") as f:
    lines = f.readlines()
nl = "\r\n" if lines and lines[0].endswith("\r\n") else "\n"

# edit 1: move the e0 create/record block BEFORE the dev0 kernel launch
ks = [i for i, ln in enumerate(lines) if "ar_kernel<<<1, 256, 0, s[0]>>>" in ln]
if len(ks) != 1:
    print("PATCH ABORT: dev0 launch anchor x%d" % len(ks)); sys.exit(1)
k = ks[0]
if lines[k - 1].strip() != "if (cap_ok) {":
    print("PATCH ABORT: unexpected line before dev0 launch: %r" % lines[k - 1]); sys.exit(1)

es = [i for i, ln in enumerate(lines)
      if ln.strip() == "cudaEvent_t e0 = nullptr, eb[MAXD] = {};"]
if len(es) != 1:
    print("PATCH ABORT: event decl anchor x%d" % len(es)); sys.exit(1)
e = es[0]
if e <= k:
    print("PATCH ABORT: unexpected layout"); sys.exit(1)

blk = lines[e:e + 6]
st = [ln.strip() for ln in blk]
if not (st[0] == "cudaEvent_t e0 = nullptr, eb[MAXD] = {};"
        and st[1] == "if (cap_ok) {"
        and "cudaEventCreateWithFlags(&e0" in st[2]
        and "cudaEventRecord(e0, s[0])" in st[3]
        and "record e0" in st[4]
        and st[5] == "}"):
    print("PATCH ABORT: event block shape mismatch:")
    for j, ln in enumerate(blk):
        print("  +%d: %r" % (j, ln))
    sys.exit(1)

rest = lines[:e] + lines[e + 6:]
kk = [i for i, ln in enumerate(rest)
      if ln.strip() == "if (cap_ok) {" and i + 1 < len(rest)
      and "ar_kernel<<<1, 256, 0, s[0]>>>" in rest[i + 1]]
if len(kk) != 1:
    print("PATCH ABORT: kernel block lost after removal"); sys.exit(1)
newlines = rest[:kk[0]] + blk + rest[kk[0]:]

# edit 2: wrap COUNT define in #ifndef so -DCOUNT=256 can override
cs = [i for i, ln in enumerate(newlines) if "#define COUNT 4096" in ln]
if len(cs) != 1:
    print("PATCH ABORT: COUNT anchor x%d" % len(cs)); sys.exit(1)
c = cs[0]
newlines[c:c + 1] = ["#ifndef COUNT" + nl, newlines[c], "#endif" + nl]

shutil.copyfile(path, bak)
with open(path, "w", encoding="ascii", newline="") as f:
    f.writelines(newlines)

txt = "".join(newlines)
if not (0 <= txt.find("cudaEventRecord(e0, s[0])") < txt.find("ar_kernel<<<1, 256, 0, s[0]>>>")):
    print("PATCH ABORT: post-write verify failed"); sys.exit(1)
print("PATCH OK: e0 record moved before dev0 kernel (4 sibling kernels per round)")
print("PATCH OK: COUNT wrapped in #ifndef (-DCOUNT=256 overridable)")
print("backup:", bak)
