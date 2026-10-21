# -*- coding: utf-8 -*-
import shutil, sys

path = r"D:\p100-llama-cpp\llama.cpp\ggml\src\ggml-cuda\allreduce.cu"
bak  = r"D:\temp\allreduce.cu.bak_p2pdefault"

with open(path, "r", encoding="utf-8", newline="") as f:
    lines = f.readlines()

idx = [i for i, ln in enumerate(lines) if "GGML_CUDA_AR_P2P" in ln and '", 1)' in ln]
if len(idx) != 1:
    print("PATCH ABORT: P2P default anchor x%d. File unchanged." % len(idx))
    for i, ln in enumerate(lines):
        if "GGML_CUDA_AR_P2P" in ln:
            print("  line %d: %r" % (i + 1, ln))
    sys.exit(1)
i = idx[0]

old_line = lines[i]
new_line = old_line.replace('", 1)', '", 0)')
if new_line == old_line:
    print("PATCH ABORT: substitution failed. File unchanged."); sys.exit(1)

crlf = sum(1 for ln in lines if ln.endswith("\r\n"))
eol = "\r\n" if crlf * 2 > len(lines) else "\n"
indent = old_line[: len(old_line) - len(old_line.lstrip())]
comment_raw = [
    "P2P device staging is disabled by default (P20 safe-default fix).",
    "It only activates on all-peer-access topologies (e.g. 3 GPUs behind",
    "one PCIe root), where it breaks the MTP draft config (case 32b9763);",
    "dual-socket 4-GPU layouts never activate it (any failed pair falls",
    "back wholesale to mapped-host staging). Suspected Pascal ordering",
    "gap: volatile + threadfence_system does not carry over to peer-device",
    "writes on sm_60 (attributed, not proven). GGML_CUDA_AR_P2P=1 opts in.",
]
comment = [indent + "// " + t + eol for t in comment_raw]

shutil.copyfile(path, bak)
lines[i:i] = comment
lines[i + len(comment)] = new_line

with open(path, "w", encoding="utf-8", newline="") as f:
    f.writelines(lines)

txt = "".join(lines)
ok = ('GGML_CUDA_AR_P2P", 0)' in txt) and ('GGML_CUDA_AR_P2P", 1)' not in txt)
print("PATCH OK: P2P staging default 1 -> 0 at file line %d (+%d comment lines)" % (i + 1, len(comment)))
print("post-write verify:", "OK" if ok else "FAILED", "| backup:", bak)
