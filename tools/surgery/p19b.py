# -*- coding: utf-8 -*-
import shutil, sys

path = r"D:\p100-llama-cpp\llama.cpp\ggml\src\ggml-cuda\allreduce.cu"
bak  = r"D:\temp\allreduce.cu.bak_p19a"

with open(path, "r", encoding="utf-8", newline="") as f:
    lines = f.readlines()

idx = [i for i, ln in enumerate(lines) if ln.strip() == "if (pool_lapped) {"]
if len(idx) != 1:
    print("PATCH ABORT: 'if (pool_lapped) {' found %d times (expected 1). File unchanged." % len(idx))
    for i, ln in enumerate(lines):
        if "pool_lapped" in ln:
            print("  line %d: %r" % (i + 1, ln))
    sys.exit(1)
i = idx[0]

window = lines[i:i + 6]
sync_hits = [k for k, ln in enumerate(window) if "cudaEventSynchronize(p->ev_pool[i][slot].ker)" in ln]
if len(sync_hits) != 1:
    print("PATCH ABORT: sync line not found near pool_lapped. File unchanged.")
    for k, ln in enumerate(window):
        print("  +%d: %r" % (k, ln))
    sys.exit(1)

if not any("ggml_cuda_ar_env_u64" in ln for ln in lines):
    print("PATCH ABORT: ggml_cuda_ar_env_u64 helper not present. File unchanged.")
    sys.exit(1)

crlf = sum(1 for ln in lines if ln.endswith("\r\n"))
lf   = sum(1 for ln in lines if ln.endswith("\n") and not ln.endswith("\r\n"))
newline = "\r\n" if crlf >= lf else "\n"
indent = lines[i][: len(lines[i]) - len(lines[i].lstrip())]

comment = (
    "// P19-A: host-side sync skipped by default (GGML_CUDA_AR_ASYNC, default 1).\n"
    "// Slot-reuse safety is already guaranteed device-side by the arrival-token\n"
    "// handshake: kernel N on device i passes Phase 2 only after every peer\n"
    "// reached Phase 2 of kernel N, and a peer reaches Phase 2 of kernel N-1\n"
    "// only after fully completing kernel N-2 (per-device stream order), whose\n"
    "// Phase 3 is the last reader of the slot kernel N is about to overwrite.\n"
    "// The AR call sequence is collective (one host call drives all devices),\n"
    "// so this lockstep ordering holds for every chunk. The legacy sync forced\n"
    "// a blocking host round trip per AR (and a WDDM submit flush on Windows),\n"
    "// serializing launch submission on the token-generation path.\n"
    "// GGML_CUDA_AR_ASYNC=0 restores the legacy behavior.\n"
)
replacement = (
    comment
    + indent + "static const bool ar_async = ggml_cuda_ar_env_u64(\"GGML_CUDA_AR_ASYNC\", 1) != 0;\n"
    + indent + "if (pool_lapped && !ar_async) {\n"
)
replacement = replacement.replace("\n", newline)

shutil.copyfile(path, bak)
lines[i] = replacement
with open(path, "w", encoding="utf-8", newline="") as f:
    f.writelines(lines)
print("PATCH OK: guarded pool_lapped sync at file line %d | backup: %s | CRLF x%d, LF-only x%d" % (i + 1, bak, crlf, lf))
