#include <cstdio>
#include <cuda_runtime.h>

int main() {
    int n = 0;
    cudaError_t rc = cudaGetDeviceCount(&n);
    if (rc != cudaSuccess) { printf("getDeviceCount rc=%s\n", cudaGetErrorString(rc)); return 1; }
    printf("devices=%d\n", n);
    int can[64][64] = {};
    for (int i = 0; i < n && i < 64; ++i) {
        for (int j = 0; j < n && j < 64; ++j) {
            if (i == j) continue;
            int c = 0;
            rc = cudaDeviceCanAccessPeer(&c, i, j);
            can[i][j] = (rc == cudaSuccess) ? c : -1;
            printf("can   %d -> %d : %2d  (rc=%s)\n", i, j, can[i][j], cudaGetErrorString(rc));
        }
    }
    for (int i = 0; i < n && i < 64; ++i) {
        cudaSetDevice(i);
        for (int j = 0; j < n && j < 64; ++j) {
            if (i == j || can[i][j] != 1) continue;
            rc = cudaDeviceEnablePeerAccess(j, 0);
            printf("enable %d -> %d : rc=%s\n", i, j, cudaGetErrorString(rc));
        }
    }
    printf("done\n");
    return 0;
}