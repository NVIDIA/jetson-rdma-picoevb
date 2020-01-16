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

struct picoevb_rdma_h2c2h_dma {
	/* In */
	/* Malloc: Pointer, CUDA: Handle from IOC_PIN_CUDA */
	__u64 src;
	/* Malloc: Pointer, CUDA: Handle from IOC_PIN_CUDA */
	__u64 dst;
	__u64 len;
	__u64 flags;
	/* Out */
	__u64 dma_time_ns;
};
#define PICOEVB_H2C2H_DMA_FLAG_SRC_IS_CUDA (1 << 0)
#define PICOEVB_H2C2H_DMA_FLAG_DST_IS_CUDA (1 << 1)

struct picoevb_rdma_card_info {
	/* Out */
	__u64 fpga_ram_size;
};

struct picoevb_rdma_h2c_dma {
	/* In */
	/* Malloc: Pointer, CUDA: Handle from IOC_PIN_CUDA */
	__u64 src;
	/* RAM buffer offset */
	__u64 dst;
	__u64 len;
	__u64 flags;
	/* Out */
	__u64 dma_time_ns;
};
#define PICOEVB_H2C_DMA_FLAG_SRC_IS_CUDA (1 << 0)

struct picoevb_rdma_c2h_dma {
	/* In */
	/* Malloc: Pointer, CUDA: Handle from IOC_PIN_CUDA */
	__u64 dst;
	/* RAM buffer offset */
	__u64 src;
	__u64 len;
	__u64 flags;
	/* Out */
	__u64 dma_time_ns;
};
#define PICOEVB_C2H_DMA_FLAG_DST_IS_CUDA (1 << 0)

#define PICOEVB_IOC_LED		_IOW('P', 0, __u32)
#define PICOEVB_IOC_PIN_CUDA	_IOWR('P', 1, struct picoevb_rdma_pin_cuda)
#define PICOEVB_IOC_UNPIN_CUDA	_IOW('P', 2, struct picoevb_rdma_unpin_cuda)
#define PICOEVB_IOC_H2C2H_DMA	_IOWR('P', 3, struct picoevb_rdma_h2c2h_dma)
#define PICOEVB_IOC_CARD_INFO	_IOR('P', 4, struct picoevb_rdma_card_info)
#define PICOEVB_IOC_H2C_DMA	_IOWR('P', 5, struct picoevb_rdma_h2c_dma)
#define PICOEVB_IOC_C2H_DMA	_IOWR('P', 6, struct picoevb_rdma_c2h_dma)

#endif
