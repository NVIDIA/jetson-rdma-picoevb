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

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <sys/types.h>
#include "../kernel-module/picoevb-rdma-ioctl.h"

#define MAX_TRANSFER_SIZE (100 * 1024 * 1024)

int main(int argc, char **argv)
{
	int fd, ret;
	struct picoevb_rdma_card_info card_info;
	uint64_t transfer_size;
	void *dst;
	struct picoevb_rdma_c2h_dma dma_params;
	struct timeval  tvs, tve;
	uint64_t tdelta_us;

	if (argc != 1) {
		fprintf(stderr, "usage: rdma-malloc\n");
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

	dst = calloc(transfer_size, 1);
	if (!dst) {
		fprintf(stderr, "malloc(dst) failed\n");
		return 1;
	}

	dma_params.src = 0;
	dma_params.dst = (__u64)dst;
	dma_params.len = transfer_size;
	dma_params.flags = 0;
	gettimeofday(&tvs, NULL);
	ret = ioctl(fd, PICOEVB_IOC_C2H_DMA, &dma_params);
	gettimeofday(&tve, NULL);
	if (ret != 0) {
		fprintf(stderr, "ioctl(DMA) failed: %d\n", ret);
		perror("ioctl() failed");
		return 1;
	}

	tdelta_us = ((tve.tv_sec - tvs.tv_sec) * 1000000) + tve.tv_usec - tvs.tv_usec;
	printf("Bytes:%lu usecs:%lu MB/s:%lf\n", transfer_size, tdelta_us, (double)transfer_size / (double)tdelta_us);

	free(dst);

	ret = close(fd);
	if (ret < 0) {
		perror("close() failed");
		return 1;
	}

	return 0;
}
