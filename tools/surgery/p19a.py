# -*- coding: utf-8 -*-
import shutil, sys

path = r"D:\p100-llama-cpp\llama.cpp\ggml\src\ggml-cuda\allreduce.cu"
bak  = r"D:\temp\allreduce.cu.bak_p19a"

old = '''static ggml_cuda_ar_slot_info ggml_cuda_ar_acquire_slot(ggml_cuda_ar_pipeline * p) {
    const int slot = static_cast<int>(p->call_count % GGML_CUDA_AR_POOL_SIZE);
    const bool pool_lapped = p->call_count >= GGML_CUDA_AR_POOL_SIZE;
    p->call_count++;

    if (pool_lapped) {
        for (int i = 0; i < p->n_devices; ++i) {
            ggml_cuda_set_device(p->devices[i]);
            CUDA_CHECK(cudaEventSynchronize(p->ev_pool[i][slot].ker));
        }
    }

    return { slot, (int) p->call_count };
}'''

new = '''static ggml_cuda_ar_slot_info ggml_cuda_ar_acquire_slot(ggml_cuda_ar_pipeline * p) {
    const int slot = static_cast<int>(p->call_count % GGML_CUDA_AR_POOL_SIZE);
    const bool pool_lapped = p->call_count >= GGML_CUDA_AR_POOL_SIZE;
    p->call_count++;

    // P19-A: host-side sync skipped by default (GGML_CUDA_AR_ASYNC, default 1).
    // Slot-reuse safety is already guaranteed device-side by the arrival-token
    // handshake: kernel N on device i passes Phase 2 only after every peer
    // reached Phase 2 of kernel N, and a peer reaches Phase 2 of kernel N-1
    // only after fully completing kernel N-2 (per-device stream order), whose
    // Phase 3 is the last reader of the slot kernel N is about to overwrite.
    // The AR call sequence is collective (one host call drives all devices),
    // so this lockstep ordering holds for every chunk. The legacy sync forced
    // a blocking host round trip per AR (and a WDDM submit flush on Windows),
    // serializing launch submission on the token-generation path.
    // GGML_CUDA_AR_ASYNC=0 restores the legacy behavior.
    static const bool ar_async = ggml_cuda_ar_env_u64("GGML_CUDA_AR_ASYNC", 1) != 0;
    if (pool_lapped && !ar_async) {
        for (int i = 0; i < p->n_devices; ++i) {
            ggml_cuda_set_device(p->devices[i]);
            CUDA_CHECK(cudaEventSynchronize(p->ev_pool[i][slot].ker));
        }
    }

    return { slot, (int) p->call_count };
}'''

src = open(path, "r", encoding="utf-8", newline="").read()
crlf = "\r\n" in src
if crlf:
    old_n = old.replace("\n", "\r\n")
    new_n = new.replace("\n", "\r\n")
else:
    old_n, new_n = old, new
cnt = src.count(old_n)
if cnt != 1:
    print("PATCH ABORT: pattern found", cnt, "times (expected 1). File unchanged.")
    sys.exit(1)
shutil.copyfile(path, bak)
open(path, "w", encoding="utf-8", newline="").write(src.replace(old_n, new_n))
print("PATCH OK. backup:", bak, "| CRLF:", crlf)
