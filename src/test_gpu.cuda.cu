#ifndef TEST_GPU_CUDA_H 
#define TEST_GPU_CUDA_H

#include "common_gpu.h"

// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------
// GPU KERNELS ---------------------------------------------------------------
// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------


// GPU Kernel for reduction using warp (uses appropriate warp for NVIDIA vs AMD devices i. e. "portable wave aware code")
__device__ void warp_reduce(volatile double *sdata, size_t thread_idx) {
    if (warpSize == 64) { if (GPU_BLOCK_SIZE >= 128) sdata[thread_idx] += sdata[thread_idx + 64]; }
    if (GPU_BLOCK_SIZE >= 64) sdata[thread_idx] += sdata[thread_idx + 32];
    if (GPU_BLOCK_SIZE >= 32) sdata[thread_idx] += sdata[thread_idx + 16];
    if (GPU_BLOCK_SIZE >= 16) sdata[thread_idx] += sdata[thread_idx + 8];
    if (GPU_BLOCK_SIZE >= 8) sdata[thread_idx] += sdata[thread_idx + 4];
    if (GPU_BLOCK_SIZE >= 4) sdata[thread_idx] += sdata[thread_idx + 2];
    if (GPU_BLOCK_SIZE >= 2) sdata[thread_idx] += sdata[thread_idx + 1];
}

__global__
void gpu_matmul_short(double* __restrict__ C, double* __restrict__ B, double* __restrict__ A, size_t N) {
    __shared__ double _c[GPU_BLOCK_SIZE];
    size_t _j = blockDim.x * blockIdx.x + threadIdx.x;
    if (_j < N) {
        _c[threadIdx.x] = A[_j]*B[_j];
    } else {
        _c[threadIdx.x] = 0.0;
    }
    __syncthreads();

    // NEED TO REDUCE _c ON SHARED MEMORY AND ADD TO GLOBAL isf
    if (GPU_BLOCK_SIZE >= 1024) {
        if (threadIdx.x < 512) {
            _c[threadIdx.x] += _c[threadIdx.x + 512];
        }
        __syncthreads();
    } 

    if (GPU_BLOCK_SIZE >= 512) {
        if (threadIdx.x < 256) {
            _c[threadIdx.x] += _c[threadIdx.x + 256];
        }
        __syncthreads();
    } 

    if (GPU_BLOCK_SIZE >= 256) {
        if (threadIdx.x < 128) {
            _c[threadIdx.x] += _c[threadIdx.x + 128];
        }
        __syncthreads();
    } 

    if (warpSize == 32) {
        if (GPU_BLOCK_SIZE >= 128) {
            if (threadIdx.x < 64) {
                _c[threadIdx.x] += _c[threadIdx.x + 64];
            }
            __syncthreads();
        } 
    }

    if (threadIdx.x < warpSize) {
        warp_reduce(_c, threadIdx.x);
    }

    if (threadIdx.x == 0) {
        C[0] = _c[0];
    }
}


// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------
// GPU KERNEL WRAPPER --------------------------------------------------------
// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------
namespace cuda_wrapper {
    void gpu_matmul_wrapper(dim3 grid_size, dim3 group_size, double* __restrict__ C, double* __restrict__ B, double* __restrict__ A, size_t N) {
        gpu_matmul <<<grid_size, group_size, 0, 0>>> ( 
                C, B, A, N
                );
    }
    void gpu_matmul_wrapper(dim3 grid_size, dim3 group_size, cudaStream_t stream, double* __restrict__ C, double* __restrict__ B, double* __restrict__ A, size_t N) {
        gpu_matmul <<<grid_size, group_size, 0, stream>>> ( 
                C, B, A, N
                );
    }
}
#endif

