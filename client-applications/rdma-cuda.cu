/*
 * Copyright (c) 2019, NVIDIA CORPORATION. All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
 * THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */

#include <cuda.h>
#include <cuda_runtime_api.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <sys/stat.h>
#include <sys/types.h>
#include "../kernel-module/picoevb-rdma-ioctl.h"

#define SURFACE_W	1024
#define SURFACE_H	1024
#define SURFACE_SIZE	(SURFACE_W * SURFACE_H)

#define OFFSET(x, y)	(((y) * SURFACE_W) + x)
#define DATA(x, y)	(((y & 0xffff) << 16) | ((x) & 0xffff))

extern "C" __global__ void fill_surface(uint32_t *output, uint32_t xor_val)
{
	unsigned int pos_x = (blockIdx.x * blockDim.x) + threadIdx.x;
	unsigned int pos_y = (blockIdx.y * blockDim.y) + threadIdx.y;

	output[OFFSET(pos_x, pos_y)] = DATA(pos_x, pos_y) ^ xor_val;
}

int main(int argc, char **argv)
{
	cudaError_t ce;
	CUresult cr;
	uint32_t *src_d, *dst_d, *dst_cpu;
	uint32_t y, x;
	int fd, ret;
	unsigned int flag = 1;
	struct picoevb_rdma_pin_cuda pin_params_src, pin_params_dst;
	struct picoevb_rdma_h2c2h_dma dma_params;
	struct picoevb_rdma_unpin_cuda unpin_params_src, unpin_params_dst;

	if (argc != 1) {
		fprintf(stderr, "usage: rdma-cuda\n");
		return 1;
	}

	fd = open("/dev/picoevb", O_RDWR);
	if (fd < 0) {
		perror("open() failed");
		return 1;
	}

#ifdef NV_BUILD_DGPU
	ce = cudaMalloc(&src_d, SURFACE_SIZE * sizeof(*src_d));
#else
	ce = cudaHostAlloc(&src_d, SURFACE_SIZE * sizeof(*src_d),
		cudaHostAllocDefault);
#endif
	if (ce != cudaSuccess) {
		fprintf(stderr, "Allocation of src_d failed: %d\n", ce);
		return 1;
	}

	cr = cuPointerSetAttribute(&flag, CU_POINTER_ATTRIBUTE_SYNC_MEMOPS,
		(CUdeviceptr)src_d);
	if (cr != CUDA_SUCCESS) {
		fprintf(stderr, "cuPointerSetAttribute(src_d) failed: %d\n", cr);
		return 1;
	}

	pin_params_src.va = (__u64)src_d;
	pin_params_src.size = SURFACE_SIZE * sizeof(*src_d);
	ret = ioctl(fd, PICOEVB_IOC_PIN_CUDA, &pin_params_src);
	if (ret != 0) {
		fprintf(stderr, "ioctl(PIN_CUDA src) failed: ret=%d errno=%d\n", ret, errno);
		return 1;
	}

#ifdef NV_BUILD_DGPU
	ce = cudaMalloc(&dst_d, SURFACE_SIZE * sizeof(*dst_d));
#else
	ce = cudaHostAlloc(&dst_d, SURFACE_SIZE * sizeof(*dst_d),
		cudaHostAllocDefault);
#endif
	if (ce != cudaSuccess) {
		fprintf(stderr, "Allocation of dst_d failed: %d\n", ce);
		return 1;
	}

	cr = cuPointerSetAttribute(&flag, CU_POINTER_ATTRIBUTE_SYNC_MEMOPS,
		(CUdeviceptr)dst_d);
	if (cr != CUDA_SUCCESS) {
		fprintf(stderr, "cuPointerSetAttribute(dst_d) failed: %d\n", cr);
		return 1;
	}

	pin_params_dst.va = (__u64)dst_d;
	pin_params_dst.size = SURFACE_SIZE * sizeof(*dst_d);
	ret = ioctl(fd, PICOEVB_IOC_PIN_CUDA, &pin_params_dst);
	if (ret != 0) {
		fprintf(stderr, "ioctl(PIN_CUDA dst) failed: ret=%d errno=%d\n", ret, errno);
		return 1;
	}

#if (SURFACE_W < 16) || (SURFACE_H < 16)
#error Grid and block sizes must be shrunk for small surfaces
#endif
#if (SURFACE_W & 15) || (SURFACE_H & 15)
#error Grid and block sizes are not a multiple of the surface size
#endif
	dim3 dimGrid(SURFACE_W / 16, SURFACE_H / 16);
	dim3 dimBlock(16, 16);
	fill_surface<<<dimGrid, dimBlock>>>(src_d, 0);
	fill_surface<<<dimGrid, dimBlock>>>(dst_d, 0xffffffffU);

	ce = cudaDeviceSynchronize();
	if (ce != cudaSuccess) {
		fprintf(stderr, "cudaDeviceSynchronize() failed: %d\n", ce);
		return 1;
	}

	dma_params.src = pin_params_src.handle;
	dma_params.dst = pin_params_dst.handle;
	dma_params.len = SURFACE_SIZE * sizeof(*src_d);
	dma_params.flags = PICOEVB_H2C2H_DMA_FLAG_SRC_IS_CUDA |
		PICOEVB_H2C2H_DMA_FLAG_DST_IS_CUDA;
	ret = ioctl(fd, PICOEVB_IOC_H2C2H_DMA, &dma_params);
	if (ret != 0) {
		fprintf(stderr, "ioctl(DMA) failed: %d\n", ret);
		return 1;
	}

	/*
	 * dGPU on x86 does not allow GPUDirect RDMA on host pinned memory
	 * (cudaMalloc), so we must allocate device memory, and manually copy
	 * it to the host for validation.
	 */
#ifdef NV_BUILD_DGPU
	ce = cudaMallocHost(&dst_cpu, SURFACE_SIZE * sizeof(*dst_cpu), 0);
	if (ce != cudaSuccess) {
		fprintf(stderr, "cudaMallocHost(dst_cpu) failed\n");
		return 1;
	}
	ce = cudaMemcpy(dst_cpu, dst_d, SURFACE_SIZE * sizeof(*dst_cpu), cudaMemcpyDeviceToHost);
	if (ce != cudaSuccess) {
		fprintf(stderr, "cudaMemcpy() failed: %d\n", ce);
		return 1;
	}
#else
	dst_cpu = dst_d;
#endif

	ret = 0;
	for (y = 0; y < SURFACE_H; y++) {
		for (x = 0; x < SURFACE_W; x++) {
			uint32_t expected = DATA(x, y);
			uint32_t offset = OFFSET(x, y);
			uint32_t actual = dst_cpu[offset];
			if (actual != expected) {
				fprintf(stderr,
					"dst[0x%x] is 0x%x not 0x%x\n",
					offset, actual, expected);
				ret = 1;
			}
		}
	}
	if (ret)
		return 1;

#ifdef NV_BUILD_DGPU
	ce = cudaFreeHost(dst_cpu);
	if (ce != cudaSuccess) {
		fprintf(stderr, "cudaFreeHost(dst_cpu) failed: %d\n", ce);
		return 1;
	}
#endif

	unpin_params_dst.handle = pin_params_dst.handle;
	ret = ioctl(fd, PICOEVB_IOC_UNPIN_CUDA, &unpin_params_dst);
	if (ret != 0) {
		fprintf(stderr, "ioctl(UNPIN_CUDA dst) failed: %d\n", ret);
		return 1;
	}

#ifdef NV_BUILD_DGPU
	ce = cudaFree(dst_d);
#else
	ce = cudaFreeHost(dst_d);
#endif
	if (ce != cudaSuccess) {
		fprintf(stderr, "Free of dst_d failed: %d\n", ce);
		return 1;
	}

	unpin_params_src.handle = pin_params_src.handle;
	ret = ioctl(fd, PICOEVB_IOC_UNPIN_CUDA, &unpin_params_src);
	if (ret != 0) {
		fprintf(stderr, "ioctl(UNPIN_CUDA src) failed: %d\n", ret);
		return 1;
	}

#ifdef NV_BUILD_DGPU
	ce = cudaFree(src_d);
#else
	ce = cudaFreeHost(src_d);
#endif
	if (ce != cudaSuccess) {
		fprintf(stderr, "Free of src_d failed: %d\n", ce);
		return 1;
	}

	ret = close(fd);
	if (ret < 0) {
		perror("close() failed");
		return 1;
	}

	return 0;
}
