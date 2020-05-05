/*
 * Copyright (c) 2019-2020, NVIDIA CORPORATION. All rights reserved.
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

#define MAX_TRANSFER_SIZE (100 * 1024 * 1024)

int main(int argc, char **argv)
{
	int fd, ret;
	struct picoevb_rdma_card_info card_info;
	uint64_t transfer_size;
	cudaError_t ce;
	void *buf;
	CUresult cr;
	unsigned int flag = 1;
	struct picoevb_rdma_pin_cuda pin_params;
	struct picoevb_rdma_h2c_dma dma_params;
	uint64_t tdelta_us;
	struct picoevb_rdma_unpin_cuda unpin_params;

	if (argc != 1) {
		fprintf(stderr, "usage: rdma-cuda-h2c-perf\n");
		return 1;
	}

	fd = open("/dev/picoevb", O_RDWR);
	if (fd < 0) {
		perror("open() failed");
		return 1;
	}

	ret = ioctl(fd, PICOEVB_IOC_CARD_INFO, &card_info);
	if (ret != 0) {
		fprintf(stderr, "ioctl(CARD_INFO) failed: %d\n", ret);
		perror("ioctl() failed");
		return 1;
	}
	transfer_size = card_info.fpga_ram_size;
	if (transfer_size > MAX_TRANSFER_SIZE)
		transfer_size = MAX_TRANSFER_SIZE;

#ifdef NV_BUILD_DGPU
	ce = cudaMalloc(&buf, transfer_size);
#else
	ce = cudaHostAlloc(&buf, transfer_size, cudaHostAllocDefault);
#endif
	if (ce != cudaSuccess) {
		fprintf(stderr, "Allocation of GPU buffer failed: %d\n", ce);
		return 1;
	}

	cr = cuPointerSetAttribute(&flag, CU_POINTER_ATTRIBUTE_SYNC_MEMOPS,
		(CUdeviceptr)buf);
	if (cr != CUDA_SUCCESS) {
		fprintf(stderr, "cuPointerSetAttribute(buf) failed: %d\n", cr);
		return 1;
	}

	pin_params.va = (__u64)buf;
	pin_params.size = transfer_size;
	ret = ioctl(fd, PICOEVB_IOC_PIN_CUDA, &pin_params);
	if (ret != 0) {
		fprintf(stderr, "ioctl(PIN_CUDA buf) failed: ret=%d errno=%d\n", ret, errno);
		return 1;
	}

	ce = cudaDeviceSynchronize();
	if (ce != cudaSuccess) {
		fprintf(stderr, "cudaDeviceSynchronize() failed: %d\n", ce);
		return 1;
	}

	dma_params.src = pin_params.handle;
	dma_params.dst = 0;
	dma_params.len = transfer_size;
	dma_params.flags = PICOEVB_H2C_DMA_FLAG_SRC_IS_CUDA;
	ret = ioctl(fd, PICOEVB_IOC_H2C_DMA, &dma_params);
	if (ret != 0) {
		fprintf(stderr, "ioctl(DMA) failed: %d\n", ret);
		perror("ioctl() failed");
		return 1;
	}

	tdelta_us = dma_params.dma_time_ns / 1000;
	printf("Bytes:%lu usecs:%lu MB/s:%lf\n", transfer_size, tdelta_us, (double)transfer_size / (double)tdelta_us);

	unpin_params.handle = pin_params.handle;
	ret = ioctl(fd, PICOEVB_IOC_UNPIN_CUDA, &unpin_params);
	if (ret != 0) {
		fprintf(stderr, "ioctl(UNPIN_CUDA buf) failed: %d\n", ret);
		return 1;
	}

#ifdef NV_BUILD_DGPU
	ce = cudaFree(buf);
#else
	ce = cudaFreeHost(buf);
#endif
	if (ce != cudaSuccess) {
		fprintf(stderr, "Free of buf failed: %d\n", ce);
		return 1;
	}

	ret = close(fd);
	if (ret < 0) {
		perror("close() failed");
		return 1;
	}

	return 0;
}
