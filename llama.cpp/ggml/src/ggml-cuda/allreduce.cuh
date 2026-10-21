#pragma once

#include "common.cuh"
#include "ggml-backend-impl.h"

#include <cstddef>

// Opaque pipeline context -- owns all pinned buffers, streams, and events.
struct ggml_cuda_ar_pipeline;

// Allocate a pipeline for n_devices GPUs.
// devices[] holds the CUDA device IDs in rank order.
// Returns nullptr on allocation failure.
ggml_cuda_ar_pipeline * ggml_cuda_ar_pipeline_init(
    const int * devices, size_t n_devices);

// Release all resources owned by the pipeline.
void ggml_cuda_ar_pipeline_free(ggml_cuda_ar_pipeline * pipeline);

// Execute an in-place AllReduce (sum) across tensors[0..n_devices-1].
// tensors[i] must live on the device managed by backends[i] and be
// contiguous F32, F16, or BF16.
// Preconditions are checked by the CUDA comm dispatcher before calling this.
// Returns true once the reduction work has been enqueued successfully.
bool ggml_cuda_ar_allreduce(
    ggml_cuda_ar_pipeline * pipeline,
    ggml_backend_t        * backends,
    ggml_tensor           ** tensors);

// GP100-P16: residual-add folding.  The AllReduce callback notifies the shard
// output; the graph-capture loop binds it to the residual ADD's operands and
// skips that ADD; on replays the chunked path launches the fused ar_kernel
// variant, and a post-capture fixup fills the outputs of the capture-pass
// launch.  See allreduce.cu.
void ggml_cuda_ar_residual_notify(int dev, const void * ar_out, int64_t ne);
bool ggml_cuda_ar_residual_pending_take(int dev, const void * ar_out, int64_t ne);
void ggml_cuda_ar_residual_bind(int dev, const void * ar_out, float * add_dst, const float * residual, int64_t ne);
bool ggml_cuda_ar_residual_lookup(int dev, const void * ar_out, float ** add_dst, const float ** residual, int64_t * ne);
void ggml_cuda_ar_residual_begin_capture(int dev, const void * cgraph);
void ggml_cuda_ar_residual_fixup(int dev, cudaStream_t stream);

