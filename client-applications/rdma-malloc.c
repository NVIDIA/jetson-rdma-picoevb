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
#include <sys/types.h>
#include "../kernel-module/picoevb-rdma-ioctl.h"

#define SURFACE_W	1024
#define SURFACE_H	1024
#define SURFACE_SIZE	(SURFACE_W * SURFACE_H)

#define OFFSET(x, y)	(((y) * SURFACE_W) + x)
#define DATA(x, y)	(((y & 0xffff) << 16) | ((x) & 0xffff))

int main(int argc, char **argv)
{
	uint32_t *src, *dst;
	uint32_t y, x;
	int fd, ret;
	struct picoevb_rdma_dma dma_params;

	if (argc != 1) {
		fprintf(stderr, "usage: rdma-malloc\n");
		return 1;
	}

	fd = open("/dev/picoevb", O_RDWR);
	if (fd < 0) {
		perror("open() failed");
		return 1;
	}

	src = malloc(SURFACE_SIZE * sizeof(*src));
	if (!src) {
		fprintf(stderr, "malloc(src) failed\n");
		return 1;
	}

	dst = malloc(SURFACE_SIZE * sizeof(*dst));
	if (!dst) {
		fprintf(stderr, "malloc(dst) failed\n");
		return 1;
	}

	for (y = 0; y < SURFACE_H; y++) {
		for (x = 0; x < SURFACE_W; x++) {
			uint32_t expected = DATA(x, y);
			uint32_t offset = OFFSET(x, y);
			src[offset] = expected;
			dst[offset] = ~expected;
		}
	}

	dma_params.src = (__u64)src;
	dma_params.dst = (__u64)dst;
	dma_params.len = SURFACE_SIZE * sizeof(*src);
	dma_params.flags = 0;
	ret = ioctl(fd, PICOEVB_IOC_DMA, &dma_params);
	if (ret != 0) {
		fprintf(stderr, "ioctl() failed: %d\n", ret);
		perror("ioctl() failed");
		return 1;
	}

	ret = 0;
	for (y = 0; y < SURFACE_H; y++) {
		for (x = 0; x < SURFACE_W; x++) {
			uint32_t expected = DATA(x, y);
			uint32_t offset = OFFSET(x, y);
			uint32_t actual = dst[offset];
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

	free(dst);
	free(src);

	ret = close(fd);
	if (ret < 0) {
		perror("close() failed");
		return 1;
	}

	return 0;
}
