#include <cstdio>
#include <cuda_runtime.h>

__global__ void hello_kernel(int * out) { *out = 42; }

int main() {
    int nd = 0;
    if (cudaGetDeviceCount(&nd) != cudaSuccess) { printf("cudaGetDeviceCount failed\n"); return 1; }
    printf("[hello] devices = %d\n", nd);
    for (int i = 0; i < nd; ++i) {
        cudaSetDevice(i);
        int * d = nullptr; int h = 0;
        if (cudaMalloc((void **)&d, sizeof(int)) != cudaSuccess) { printf("[hello] dev %d malloc failed\n", i); return 1; }
        hello_kernel<<<1, 1>>>(d);
        if (cudaGetLastError() != cudaSuccess) { printf("[hello] dev %d launch failed\n", i); return 1; }
        if (cudaMemcpy(&h, d, sizeof(int), cudaMemcpyDeviceToHost) != cudaSuccess) { printf("[hello] dev %d memcpy failed\n", i); return 1; }
        printf("[hello] dev %d kernel OK (%d)\n", i, h);
        cudaFree(d);
    }
    printf("[hello] PASS\n");
    return 0;
}
