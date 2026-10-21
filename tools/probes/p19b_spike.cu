// ============================================================================
// p19b_spike.cu - P19 Phase B spike (standalone; does not touch main build)
// Q1: can ONE CUDA graph capture kernels on MULTIPLE devices (P100, WDDM)?
// Q2: are results bit-exact vs. per-launch submission?
// Q3: per-round host cost: N x cudaLaunchKernel  vs  1 x cudaGraphLaunch(9-node)
// Build: "D:\Tools\CUDA\bin\nvcc.exe" -O2 -arch=sm_60 -o D:\temp\p19b_spike.exe D:\temp\p19b_spike.cu
// ============================================================================
#define NOMINMAX
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <vector>
#include <windows.h>
#include <cuda_runtime.h>

#define CK(x) do { cudaError_t rc_ = (x); if (rc_ != cudaSuccess) { \
    printf("[spike] CUDA error: %s @ line %d\n", cudaGetErrorString(rc_), __LINE__); \
    exit(1); } } while (0)

#define MAXD 4
#ifndef COUNT
#define COUNT 4096        /* floats per GPU (16 KB ~ tg-layer AR size) */
#endif
#define ROUNDS 200

struct Peers { float * stage[MAXD]; int * cnt[MAXD]; };

/* Simplified allreduce, device-side round counter (no token argument =>
   static kernel args, the P19-B design). cnt[r] written only by rank r
   (same-stream order, no atomics). Data fenced system-wide BEFORE the
   counter bump; peers spin until every counter >= my round, then acquire. */
__global__ void ar_kernel(float * sendrecv, Peers peers, int rank, int n, int count) {
    const int tid = threadIdx.x;
    __shared__ int round_sh;
    if (tid == 0) {
        round_sh = *(volatile int *)peers.cnt[rank] + 1;
    }
    __syncthreads();
    const int my = round_sh;

    /* Phase 1: publish our slice to mapped pinned staging */
    float * my_stage = peers.stage[rank];
    for (int i = tid; i < count; i += blockDim.x) {
        my_stage[i] = sendrecv[i];
    }
    __threadfence_system();

    /* Phase 2: signal our round, then wait for every peer */
    if (tid == 0) {
        *(volatile int *)peers.cnt[rank] = my;
        for (int r = 0; r < n; ++r) {
            if (r == rank) continue;
            while (*(volatile int *)peers.cnt[r] < my) {
                const long long t0 = clock64();      /* light PCIe backoff */
                while (clock64() - t0 < 64) { }
            }
        }
    }
    __syncthreads();
    __threadfence_system();

    /* Phase 3: rank-order float sum (bit-exact across GPUs) */
    for (int i = tid; i < count; i += blockDim.x) {
        float sum = 0.0f;
        for (int r = 0; r < n; ++r) {
            const float v = (r == rank) ? sendrecv[i] : peers.stage[r][i];
            sum = (r == 0) ? v : sum + v;
        }
        sendrecv[i] = sum;
    }
}

static float g_ref[COUNT];

static void make_reference(int nd, int rounds) {
    for (int j = 0; j < COUNT; ++j) {
        float sum = 0.0f;
        for (int r = 0; r < nd; ++r) {
            const float x = (float)(r * 1000000 + j);
            sum = (r == 0) ? x : sum + x;
        }
        g_ref[j] = sum;
    }
    for (int k = 1; k < rounds; ++k) {
        for (int j = 0; j < COUNT; ++j) {
            float sum = 0.0f;
            for (int r = 0; r < nd; ++r) sum = (r == 0) ? g_ref[j] : sum + g_ref[j];
            g_ref[j] = sum;
        }
    }
}

int main() {
    int nd = 0;
    CK(cudaGetDeviceCount(&nd));
    if (nd < 2) { printf("[spike] FAIL: need >= 2 GPUs, found %d\n", nd); return 1; }
    if (nd > MAXD) nd = MAXD;
    printf("[spike] GPUs = %d | %d floats/GPU | %d rounds\n", nd, COUNT, ROUNDS);

    float * stage_h[MAXD] = {};
    float * sendrecv[MAXD] = {};
    int   * cnt_h[MAXD] = {};
    cudaStream_t s[MAXD] = {};
    Peers peers = {};

    for (int i = 0; i < nd; ++i) {
        CK(cudaSetDevice(i));
        CK(cudaHostAlloc((void **)&stage_h[i], COUNT * sizeof(float),
                         cudaHostAllocPortable | cudaHostAllocMapped));
        CK(cudaHostAlloc((void **)&cnt_h[i], sizeof(int),
                         cudaHostAllocPortable | cudaHostAllocMapped));
        CK(cudaHostGetDevicePointer((void **)&peers.stage[i], stage_h[i], 0));
        CK(cudaHostGetDevicePointer((void **)&peers.cnt[i], cnt_h[i], 0));
        *cnt_h[i] = 0;
        CK(cudaMalloc((void **)&sendrecv[i], COUNT * sizeof(float)));
        CK(cudaStreamCreateWithFlags(&s[i], cudaStreamNonBlocking));
    }

    LARGE_INTEGER qpf, t0, t1;
    QueryPerformanceFrequency(&qpf);

    auto reset_state = [&]() {
        for (int i = 0; i < nd; ++i) {
            CK(cudaSetDevice(i));
            std::vector<float> h(COUNT);
            for (int j = 0; j < COUNT; ++j) h[j] = (float)(i * 1000000 + j);
            CK(cudaMemcpy(sendrecv[i], h.data(), COUNT * sizeof(float), cudaMemcpyHostToDevice));
            *cnt_h[i] = 0;
        }
        for (int i = 0; i < nd; ++i) { CK(cudaSetDevice(i)); CK(cudaDeviceSynchronize()); }
    };

    auto verify_all = [&](const char * tag) {
        bool ok = true;
        for (int i = 0; i < nd && ok; ++i) {
            CK(cudaSetDevice(i));
            float out[COUNT];
            CK(cudaMemcpy(out, sendrecv[i], COUNT * sizeof(float), cudaMemcpyDeviceToHost));
            if (memcmp(out, g_ref, COUNT * sizeof(float)) != 0) ok = false;
        }
        printf("[spike] %-9s checksum: %s\n", tag, ok ? "OK (bit-exact)" : "MISMATCH");
        return ok;
    };

    make_reference(nd, ROUNDS);

    /* ---- arm 1: per-launch submission (current design) ---- */
    reset_state();
    QueryPerformanceCounter(&t0);
    for (int k = 0; k < ROUNDS; ++k) {
        for (int i = 0; i < nd; ++i) {
            CK(cudaSetDevice(i));
            ar_kernel<<<1, 256, 0, s[i]>>>(sendrecv[i], peers, i, nd, COUNT);
            CK(cudaGetLastError());
        }
    }
    for (int i = 0; i < nd; ++i) { CK(cudaSetDevice(i)); CK(cudaStreamSynchronize(s[i])); }
    QueryPerformanceCounter(&t1);
    const double base_ms = (double)(t1.QuadPart - t0.QuadPart) * 1000.0 / (double)qpf.QuadPart;
    const bool base_ok = verify_all("baseline");

    /* ---- arm 2: one multi-device graph per round ---- */
    reset_state();
    cudaGraph_t graph = nullptr;
    cudaGraphExec_t gexec = nullptr;
    bool cap_ok = true;
    cudaError_t cap_err = cudaSuccess;
    {
        CK(cudaSetDevice(0));
        cap_err = cudaStreamBeginCapture(s[0], cudaStreamCaptureModeRelaxed);
        if (cap_err != cudaSuccess) {
            printf("[spike] capture error at BeginCapture: %s\n", cudaGetErrorString(cap_err));
            cap_ok = false;
        }
        cudaEvent_t e0 = nullptr, eb[MAXD] = {};
        if (cap_ok) {
            CK(cudaEventCreateWithFlags(&e0, cudaEventDisableTiming));
            cap_err = cudaEventRecord(e0, s[0]);
            if (cap_err != cudaSuccess) { printf("[spike] capture error at record e0: %s\n", cudaGetErrorString(cap_err)); cap_ok = false; }
        }
        if (cap_ok) {
            ar_kernel<<<1, 256, 0, s[0]>>>(sendrecv[0], peers, 0, nd, COUNT);
            if (cudaGetLastError() != cudaSuccess) { printf("[spike] launch inside capture failed\n"); cap_ok = false; }
        }
        for (int i = 1; cap_ok && i < nd; ++i) {
            CK(cudaSetDevice(i));
            CK(cudaEventCreateWithFlags(&eb[i], cudaEventDisableTiming));
            cap_err = cudaStreamWaitEvent(s[i], e0, 0);
            if (cap_err != cudaSuccess) { printf("[spike] capture error at cross-wait s[%d]: %s\n", i, cudaGetErrorString(cap_err)); cap_ok = false; break; }
            ar_kernel<<<1, 256, 0, s[i]>>>(sendrecv[i], peers, i, nd, COUNT);
            if (cudaGetLastError() != cudaSuccess) { printf("[spike] launch inside capture failed (dev %d)\n", i); cap_ok = false; break; }
            cap_err = cudaEventRecord(eb[i], s[i]);
            if (cap_err != cudaSuccess) { printf("[spike] capture error at record eb[%d]: %s\n", i, cudaGetErrorString(cap_err)); cap_ok = false; break; }
            CK(cudaSetDevice(0));
            cap_err = cudaStreamWaitEvent(s[0], eb[i], 0);
            if (cap_err != cudaSuccess) { printf("[spike] capture error at join eb[%d]: %s\n", i, cudaGetErrorString(cap_err)); cap_ok = false; break; }
        }
        if (cap_ok) {
            cap_err = cudaStreamEndCapture(s[0], &graph);
            if (cap_err != cudaSuccess || graph == nullptr) {
                printf("[spike] capture error at EndCapture: %s\n", cudaGetErrorString(cap_err));
                cap_ok = false;
            }
        } else {
            (void)cudaStreamEndCapture(s[0], &graph);
            (void)cudaGetLastError();
        }
    }
    if (cap_ok) {
        cap_err = cudaGraphInstantiateWithFlags(&gexec, graph, 0);
        if (cap_err != cudaSuccess) {
            printf("[spike] instantiate error: %s\n", cudaGetErrorString(cap_err));
            cap_ok = false;
        }
    }
    double graph_ms = 0.0;
    bool graph_ok = false;
    if (cap_ok) {
        QueryPerformanceCounter(&t0);
        for (int k = 0; k < ROUNDS; ++k) {
            CK(cudaSetDevice(0));
            cap_err = cudaGraphLaunch(gexec, s[0]);
            if (cap_err != cudaSuccess) { printf("[spike] graph launch error: %s\n", cudaGetErrorString(cap_err)); cap_ok = false; break; }
        }
        if (cap_ok) {
            for (int i = 0; i < nd; ++i) { CK(cudaSetDevice(i)); CK(cudaStreamSynchronize(s[i])); }
            QueryPerformanceCounter(&t1);
            graph_ms = (double)(t1.QuadPart - t0.QuadPart) * 1000.0 / (double)qpf.QuadPart;
            graph_ok = verify_all("graph");
        }
    }

    /* ---- verdict ---- */
    printf("[spike] baseline : %8.2f ms total | %7.2f us/round (4 x cudaLaunchKernel)\n",
           base_ms, base_ms * 1000.0 / ROUNDS);
    if (cap_ok) {
        printf("[spike] graph    : %8.2f ms total | %7.2f us/round (1 x cudaGraphLaunch)\n",
               graph_ms, graph_ms * 1000.0 / ROUNDS);
        printf("[spike] delta    : %+.2f us/round (%+.1f%%)\n",
               (base_ms - graph_ms) * 1000.0 / ROUNDS,
               base_ms > 0.0 ? (base_ms - graph_ms) / base_ms * 100.0 : 0.0);
    }
    const bool supported = cap_ok && graph_ok && base_ok;
    printf("[spike] verdict  : %s\n",
           supported ? "MULTI-DEVICE SINGLE GRAPH = SUPPORTED (bit-exact)"
                     : "NOT SUPPORTED / INCORRECT (see errors above)");

    if (graph) cudaGraphDestroy(graph);
    if (gexec) cudaGraphExecDestroy(gexec);
    return supported ? 0 : 2;
}
