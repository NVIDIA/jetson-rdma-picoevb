/*
 * Copyright (c) 2019, NVIDIA CORPORATION.  All rights reserved.
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms and conditions of the GNU General Public License,
 * version 2, as published by the Free Software Foundation.
 *
 * This program is distributed in the hope it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
 * more details.
 */

#ifndef __PICOEVB_RDMA_IOCTL_H__
#define __PICOEVB_RDMA_IOCTL_H__

#include <linux/types.h>

struct picoevb_rdma_pin_cuda {
	/* In */
	__u64 va;
	__u64 size;
	/* Out */
	__u32 handle;
};

struct picoevb_rdma_unpin_cuda {
	/* In */
	__u32 handle;
};

struct picoevb_rdma_dma {
	/* In */
	/* Malloc: Pointer, CUDA: Handle from IOC_PIN_CUDA */
	__u64 src;
	/* Malloc: Pointer, CUDA: Handle from IOC_PIN_CUDA */
	__u64 dst;
	__u64 len;
	__u64 flags;
};
#define PICOEVB_DMA_FLAG_SRC_IS_CUDA (1 << 0)
#define PICOEVB_DMA_FLAG_DST_IS_CUDA (1 << 1)

#define PICOEVB_IOC_LED		_IOW('P', 0, __u32)
#define PICOEVB_IOC_PIN_CUDA	_IOWR('P', 1, struct picoevb_rdma_pin_cuda)
#define PICOEVB_IOC_UNPIN_CUDA	_IOW('P', 2, struct picoevb_rdma_unpin_cuda)
#define PICOEVB_IOC_DMA		_IOW('P', 3, struct picoevb_rdma_dma)

#endif
