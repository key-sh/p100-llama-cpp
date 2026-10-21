# -*- coding: utf-8 -*-
spike = r"D:\temp\p19b_spike.cu"
hello = r"D:\temp\p19hello.cu"

raw = open(spike, "rb").read()
if raw.startswith(b"\xef\xbb\xbf"):
    print("BOM found and removed")
    raw = raw[3:]
try:
    txt = raw.decode("utf-8"); enc = "utf-8"
except UnicodeDecodeError:
    txt = raw.decode("gbk"); enc = "gbk"

bad = []
line = 1
for ch in txt:
    if ch == "\n":
        line += 1
    elif ord(ch) > 127:
        bad.append((line, ch))

print("encoding:", enc, "| non-ascii chars:", len(bad))
for ln, ch in bad[:10]:
    print("  line %d: U+%04X %r" % (ln, ord(ch), ch))

clean = "".join(ch if ord(ch) < 128 else "-" for ch in txt)
open(spike, "w", encoding="ascii", newline="").write(clean)
print("spike rewritten as pure ASCII:", spike)

hello_src = """#include <cstdio>
#include <cuda_runtime.h>

__global__ void hello_kernel(int * out) { *out = 42; }

int main() {
    int nd = 0;
    if (cudaGetDeviceCount(&nd) != cudaSuccess) { printf("cudaGetDeviceCount failed\\n"); return 1; }
    printf("[hello] devices = %d\\n", nd);
    for (int i = 0; i < nd; ++i) {
        cudaSetDevice(i);
        int * d = nullptr; int h = 0;
        if (cudaMalloc((void **)&d, sizeof(int)) != cudaSuccess) { printf("[hello] dev %d malloc failed\\n", i); return 1; }
        hello_kernel<<<1, 1>>>(d);
        if (cudaGetLastError() != cudaSuccess) { printf("[hello] dev %d launch failed\\n", i); return 1; }
        if (cudaMemcpy(&h, d, sizeof(int), cudaMemcpyDeviceToHost) != cudaSuccess) { printf("[hello] dev %d memcpy failed\\n", i); return 1; }
        printf("[hello] dev %d kernel OK (%d)\\n", i, h);
        cudaFree(d);
    }
    printf("[hello] PASS\\n");
    return 0;
}
"""
open(hello, "w", encoding="ascii", newline="").write(hello_src)
print("hello probe written:", hello)
