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

#include <linux/cdev.h>
#include <linux/idr.h>
#include <linux/interrupt.h>
#include <linux/module.h>
#include <linux/pagemap.h>
#include <linux/pci.h>
#include <linux/uaccess.h>
#include <linux/version.h>

#ifdef NV_BUILD_DGPU
#include <nv-p2p.h>
#else
#include <linux/nv-p2p.h>
#endif

#include "picoevb-rdma-ioctl.h"
#include "picoevb-rdma.h"

#define MODULENAME	"picoevb-rdma"

#define BAR_GPIO	0
#define BAR_DMA		1

#define NUM_H2C_CHANS	1
#define FPGA_RAM_SIZE	SZ_64K

#ifdef NV_BUILD_DGPU
#define GPU_PAGE_SHIFT	16
#else
#define GPU_PAGE_SHIFT	12
#endif
#define GPU_PAGE_SIZE	(((u64)1) << GPU_PAGE_SHIFT)
#define GPU_PAGE_OFFSET	(GPU_PAGE_SIZE - 1)
#define GPU_PAGE_MASK	(~GPU_PAGE_OFFSET)

struct pevb {
	struct pci_dev			*pdev;
	struct device			*dev;
	struct device			*devnode;
	struct device_dma_parameters	dma_params;
	dev_t				devt;
	struct cdev			cdev;
	void __iomem * const		*iomap;
	struct semaphore		sem;
	void				*descs_ptr;
	dma_addr_t			descs_dma_addr;
	struct completion		dma_xfer_cmpl;
	bool				h2c_error;
	bool				c2h_error;
};

struct pevb_file {
	struct pevb	*pevb;
	struct mutex	lock;
	struct idr	cuda_surfaces;
};

struct pevb_cuda_surface {
	struct pevb_file		*pevb_file;
	u64				va;
	u64				offset;
	u64				len;
	int				handle;
	struct nvidia_p2p_page_table	*page_table;
};

struct pevb_userbuf_dma {
	dma_addr_t	addr;
	u64		len;
};

struct pevb_userbuf {
	bool cuda;
	int n_dmas;
	struct pevb_userbuf_dma *dmas;

	union {
		struct {
			int to_dev;
			int pagecount;
			struct page **pages;
			struct sg_table *sgt;
			int map_ret;
		} pages;
		struct {
			struct pevb_cuda_surface *cusurf;
			struct nvidia_p2p_dma_mapping *map;
		} cuda;
	} priv;
};

static struct class *pevb_class;

static u32 pevb_readl(struct pevb *pevb, int bar, u32 reg)
{
	u32 val;

	dev_dbg(&pevb->pdev->dev, "readl(0x%08x)\n", reg);
	val = readl(pevb->iomap[bar] + reg);
	dev_dbg(&pevb->pdev->dev, "readl(0x%08x) -> 0x%08x\n", reg, val);
	return val;
}

static void pevb_writel(struct pevb *pevb, int bar, u32 val, u32 reg)
{
	dev_dbg(&pevb->pdev->dev, "write(0x%08x, 0x%08x)\n", val, reg);
	writel(val, pevb->iomap[bar] + reg);
}

static int pevb_fops_open(struct inode *inode, struct file *filep)
{
	struct pevb *pevb = container_of(inode->i_cdev, struct pevb, cdev);
	struct pevb_file *pevb_file;

	pevb_file = kzalloc(sizeof(*pevb_file), GFP_KERNEL);
	if (!pevb_file)
		return -ENOMEM;

	pevb_file->pevb = pevb;
	mutex_init(&pevb_file->lock);
	idr_init(&pevb_file->cuda_surfaces);

	filep->private_data = pevb_file;

	return 0;
}

static void pevb_p2p_free_callback(void *data)
{
	struct pevb_cuda_surface *cusurf = data;
	struct pevb_file *pevb_file = cusurf->pevb_file;

	mutex_lock(&pevb_file->lock);
	if (cusurf->handle >= 0) {
		idr_remove(&pevb_file->cuda_surfaces, cusurf->handle);
		cusurf->handle = -1;
	}
	mutex_unlock(&pevb_file->lock);

	nvidia_p2p_free_page_table(cusurf->page_table);
	kfree(cusurf);
}

static int pevb_fops_release(struct inode *inode, struct file *filep)
{
	struct pevb_file *pevb_file = filep->private_data;

	for (;;) {
		int id = 0;
		struct pevb_cuda_surface *cusurf;

		mutex_lock(&pevb_file->lock);

		cusurf = idr_get_next(&pevb_file->cuda_surfaces, &id);
		if (!cusurf) {
			mutex_unlock(&pevb_file->lock);
			break;
		}

		idr_remove(&pevb_file->cuda_surfaces, id);
		cusurf->handle = -1;

		mutex_unlock(&pevb_file->lock);

		nvidia_p2p_put_pages(
#ifdef NV_BUILD_DGPU
			0, 0, cusurf->va,
#endif
			cusurf->page_table);
#ifdef NV_BUILD_DGPU
		pevb_p2p_free_callback(cusurf);
#else
		/*
		 * nvidia_p2p_put_pages() calls pevb_p2p_free_callback() which
		 * frees cusurf.
		 */
#endif
	}

	kfree(pevb_file);

	return 0;
}

static int pevb_ioctl_led(struct pevb_file *pevb_file, unsigned long arg)
{
	struct pevb *pevb = pevb_file->pevb;

	pevb_writel(pevb, BAR_GPIO, arg, 0);
	return 0;
}

static int pevb_ioctl_pin_cuda(struct pevb_file *pevb_file, unsigned long arg)
{
	void __user *argp = (void __user *)arg;
	struct picoevb_rdma_pin_cuda pin_params;
	struct pevb_cuda_surface *cusurf;
	u64 aligned_len;
	int ret;

	if (copy_from_user(&pin_params, argp, sizeof(pin_params)))
		return -EFAULT;

	cusurf = kzalloc(sizeof(*cusurf), GFP_KERNEL);
	if (!cusurf)
		return -ENOMEM;

	cusurf->pevb_file = pevb_file;
	cusurf->va = pin_params.va & GPU_PAGE_MASK;
	cusurf->offset = pin_params.va & GPU_PAGE_OFFSET;
	cusurf->len = pin_params.size;
	aligned_len = (cusurf->offset + cusurf->len + GPU_PAGE_SIZE - 1) &
		GPU_PAGE_MASK;

	ret = nvidia_p2p_get_pages(
#ifdef NV_BUILD_DGPU
		0, 0,
#endif
		cusurf->va, aligned_len, &cusurf->page_table,
		pevb_p2p_free_callback, cusurf);
	if (ret < 0) {
		kfree(cusurf);
		return ret;
	}

	mutex_lock(&pevb_file->lock);
	cusurf->handle = idr_alloc(&pevb_file->cuda_surfaces, cusurf, 0, 0,
		GFP_KERNEL);
	mutex_unlock(&pevb_file->lock);

	if (cusurf->handle < 0) {
		ret = cusurf->handle;
		goto put_pages;
	}

	pin_params.handle = cusurf->handle;

	ret = copy_to_user(argp, &pin_params, sizeof(pin_params));
	if (ret)
		goto put_pages;

	return 0;

put_pages:
	nvidia_p2p_put_pages(
#ifdef NV_BUILD_DGPU
		0, 0, cusurf->va,
#endif
		cusurf->page_table);
#ifdef NV_BUILD_DGPU
	pevb_p2p_free_callback(cusurf);
#else
	/*
	 * nvidia_p2p_put_pages() calls pevb_p2p_free_callback() which
	 * frees cusurf.
	 */
#endif

	return ret;
}

static int pevb_ioctl_unpin_cuda(struct pevb_file *pevb_file, unsigned long arg)
{
	void __user *argp = (void __user *)arg;
	struct picoevb_rdma_unpin_cuda unpin_params;
	struct pevb_cuda_surface *cusurf;

	if (copy_from_user(&unpin_params, argp, sizeof(unpin_params)))
		return -EFAULT;

	mutex_lock(&pevb_file->lock);
	cusurf = idr_find(&pevb_file->cuda_surfaces, unpin_params.handle);
	if (!cusurf) {
		mutex_unlock(&pevb_file->lock);
		return -EINVAL;
	}
	idr_remove(&pevb_file->cuda_surfaces, unpin_params.handle);
	cusurf->handle = -1;
	mutex_unlock(&pevb_file->lock);

	nvidia_p2p_put_pages(
#ifdef NV_BUILD_DGPU
		0, 0, cusurf->va,
#endif
		cusurf->page_table);
#ifdef NV_BUILD_DGPU
	pevb_p2p_free_callback(cusurf);
#else
	/*
	 * nvidia_p2p_put_pages() calls pevb_p2p_free_callback() which
	 * frees cusurf.
	 */
#endif

	return 0;
}

static void pevb_userbuf_add_dma_chunk(struct pevb_userbuf *ubuf,
	dma_addr_t addr, u64 len)
{
	struct pevb_userbuf_dma *dma;
	dma_addr_t end;

	if (ubuf->n_dmas) {
		dma = &ubuf->dmas[ubuf->n_dmas - 1];
		end = dma->addr + dma->len;
		if (addr == end) {
			dma->len += len;
			return;
		}
	}

	dma = &ubuf->dmas[ubuf->n_dmas];
	dma->addr = addr;
	dma->len = len;
	ubuf->n_dmas++;
}

static int pevb_get_userbuf_cuda(struct pevb_file *pevb_file,
	struct pevb_userbuf *ubuf, __u64 handle64, __u64 len, int to_dev)
{
	struct pevb *pevb = pevb_file->pevb;
	int id, ret, i;
	struct pevb_cuda_surface *cusurf;
	u64 offset, len_left;

	ubuf->cuda = true;

	if (handle64 & ~0xefffffffU)
		return -EINVAL;
	id = handle64 & 0xefffffffU;

	cusurf = idr_find(&pevb_file->cuda_surfaces, id);
	if (!cusurf)
		return -EINVAL;
	ubuf->priv.cuda.cusurf = cusurf;

	if (len > cusurf->len)
		return -EINVAL;

#ifdef NV_BUILD_DGPU
	ret = nvidia_p2p_dma_map_pages(pevb->pdev, cusurf->page_table,
		&ubuf->priv.cuda.map);
#else
	ret = nvidia_p2p_dma_map_pages(&pevb->pdev->dev, cusurf->page_table,
		&ubuf->priv.cuda.map, to_dev ? DMA_TO_DEVICE : DMA_FROM_DEVICE);
#endif
	if (ret < 0)
		return ret;

	ubuf->dmas = kmalloc_array(ubuf->priv.cuda.map->entries,
		sizeof(*ubuf->dmas), GFP_KERNEL);
	if (!ubuf->dmas)
		return -ENOMEM;

	offset = cusurf->offset;
	len_left = cusurf->len;
	for (i = 0; i < ubuf->priv.cuda.map->entries; i++) {
#ifdef NV_BUILD_DGPU
		dma_addr_t dma_this = ubuf->priv.cuda.map->dma_addresses[i];
		u64 len_this = min(GPU_PAGE_SIZE - offset, len_left);
#else
		dma_addr_t dma_this = ubuf->priv.cuda.map->hw_address[i];
		u64 len_this = ubuf->priv.cuda.map->hw_len[i];
#endif

		dma_this += offset;
		pevb_userbuf_add_dma_chunk(ubuf, dma_this, len_this);

		if (len_this >= len_left)
			break;
		len_left -= len_this;
		offset = 0;
	}

	return 0;
}

static int pevb_get_userbuf_pages(struct pevb *pevb, struct pevb_userbuf *ubuf,
	__u64 src, __u64 len, int to_dev)
{
	unsigned long offset;
	unsigned long start;
	unsigned long end;
	int nr_pages, ret, i;
	struct scatterlist *sg;

	ubuf->cuda = false;

	ubuf->priv.pages.to_dev = to_dev;

	offset = offset_in_page(src);
	start = src - offset;
	end = src + len;
	nr_pages = (end - start + PAGE_SIZE - 1) >> PAGE_SHIFT;

	ubuf->priv.pages.pages = kmalloc_array(nr_pages,
		sizeof(*ubuf->priv.pages.pages), GFP_KERNEL);
	if (!ubuf->priv.pages.pages)
		return -ENOMEM;

	ubuf->priv.pages.pagecount = get_user_pages(
#if LINUX_VERSION_CODE < KERNEL_VERSION(4, 6, 0)
		current, current->mm,
#endif
		start, nr_pages,
		to_dev ? 0 : FOLL_WRITE,
		ubuf->priv.pages.pages, NULL);
	if (ubuf->priv.pages.pagecount != nr_pages) {
		if (ubuf->priv.pages.pagecount < 0)
			return ubuf->priv.pages.pagecount;
		else
			return -EFAULT;
	}

	ubuf->priv.pages.sgt = kzalloc(sizeof(*ubuf->priv.pages.sgt),
		GFP_KERNEL);
	if (!ubuf->priv.pages.sgt)
		return -ENOMEM;

	ret = sg_alloc_table_from_pages(ubuf->priv.pages.sgt,
		ubuf->priv.pages.pages, nr_pages, offset, len, GFP_KERNEL);
	if (ret)
		return ret;

	ubuf->priv.pages.map_ret = dma_map_sg(&pevb->pdev->dev,
		ubuf->priv.pages.sgt->sgl, ubuf->priv.pages.sgt->nents,
		to_dev ? DMA_TO_DEVICE : DMA_FROM_DEVICE);
	if (!ubuf->priv.pages.map_ret)
		return -EFAULT;

	ubuf->dmas = kmalloc_array(ubuf->priv.pages.map_ret,
		sizeof(*ubuf->dmas), GFP_KERNEL);
	if (!ubuf->dmas)
		return -ENOMEM;

	for_each_sg(ubuf->priv.pages.sgt->sgl, sg, ubuf->priv.pages.map_ret, i)
		pevb_userbuf_add_dma_chunk(ubuf, sg_dma_address(sg),
			sg_dma_len(sg));

	return 0;
}

static void pevb_put_userbuf_pages(struct pevb *pevb, struct pevb_userbuf *ubuf)
{
	if (ubuf->priv.pages.map_ret)
		dma_unmap_sg(&pevb->pdev->dev, ubuf->priv.pages.sgt->sgl,
			ubuf->priv.pages.sgt->nents,
			ubuf->priv.pages.to_dev ?
				DMA_TO_DEVICE : DMA_FROM_DEVICE);
	if (ubuf->priv.pages.sgt)
		sg_free_table(ubuf->priv.pages.sgt);
	release_pages(ubuf->priv.pages.pages, ubuf->priv.pages.pagecount
#if LINUX_VERSION_CODE < KERNEL_VERSION(4, 15, 0)
		, 0
#endif
	);
	kfree(ubuf->priv.pages.pages);
}

static void pevb_put_userbuf_cuda(struct pevb *pevb, struct pevb_userbuf *ubuf)
{
	if (ubuf->priv.cuda.map)
#ifdef NV_BUILD_DGPU
		nvidia_p2p_dma_unmap_pages(pevb->pdev,
			ubuf->priv.cuda.cusurf->page_table,
			ubuf->priv.cuda.map);
#else
		nvidia_p2p_dma_unmap_pages(ubuf->priv.cuda.map);
#endif
}

static void pevb_put_userbuf(struct pevb *pevb, struct pevb_userbuf *ubuf)
{
	if (ubuf->cuda)
		pevb_put_userbuf_cuda(pevb, ubuf);
	else
		pevb_put_userbuf_pages(pevb, ubuf);
	kfree(ubuf->dmas);
}

static irqreturn_t pevb_irq_handler(int irq, void *data)
{
	struct pevb *pevb = data;
	u32 reg, status;
	irqreturn_t ret = IRQ_NONE;
	const u32 bad_status =
		(XLNX_DMA_H2C_STATUS_DESC_ERR_MASK <<
			XLNX_DMA_H2C_STATUS_DESC_ERR_SHIFT) |
		(XLNX_DMA_H2C_STATUS_WRITE_ERR_MASK <<
			XLNX_DMA_H2C_STATUS_WRITE_ERR_SHIFT) |
		(XLNX_DMA_H2C_STATUS_READ_ERR_MASK <<
			XLNX_DMA_H2C_STATUS_READ_ERR_SHIFT) |
		XLNX_DMA_H2C_STATUS_IDLE_STOPPED |
		XLNX_DMA_H2C_STATUS_INVALID_LEN |
		XLNX_DMA_H2C_STATUS_MAGIC_STOPPED |
		XLNX_DMA_H2C_STATUS_ALIGN_MISMATCH;

	dev_dbg(&pevb->pdev->dev, "%s()\n", __func__);
	reg = XLNX_REG(H2C, 0, H2C_STATUS_RD_CLR);
	status = pevb_readl(pevb, BAR_DMA, reg);
	status &= ~XLNX_DMA_H2C_STATUS_BUSY;
	if (status) {
		dev_dbg(&pevb->pdev->dev, "H2C status 0x%08x\n", status);
		pevb->h2c_error = !!(status & bad_status);
		complete(&pevb->dma_xfer_cmpl);
		ret = IRQ_HANDLED;
	}

	reg = XLNX_REG(C2H, 0, H2C_STATUS_RD_CLR);
	status = pevb_readl(pevb, BAR_DMA, reg);
	status &= ~XLNX_DMA_H2C_STATUS_BUSY;
	if (status) {
		dev_dbg(&pevb->pdev->dev, "C2H status 0x%08x\n", status);
		pevb->c2h_error = !!(status & bad_status);
		complete(&pevb->dma_xfer_cmpl);
		ret = IRQ_HANDLED;
	}

	return ret;
}

static int pevb_dma(struct pevb *pevb, bool c2h)
{
	u32 chan_offset, irq_int_en_bit_offset, sgma_ctrl_bit;
	u32 reg, val;
	int ret;

	if (c2h) {
		chan_offset = XLNX_REG(C2H, 0, H2C_CTRL) -
			XLNX_REG(H2C, 0, H2C_CTRL);
		irq_int_en_bit_offset =
			XLNX_DMA_IRQ_CH_C2H_BIT(0, NUM_H2C_CHANS) -
			XLNX_DMA_IRQ_CH_H2C_BIT(0);
		sgma_ctrl_bit = XLNX_DMA_SGDMA_CTRL_C2H_DSC_HALT_SHIFT;
	} else {
		chan_offset = 0;
		irq_int_en_bit_offset = 0;
		sgma_ctrl_bit = XLNX_DMA_SGDMA_CTRL_H2C_DSC_HALT_SHIFT;
	}

	reinit_completion(&pevb->dma_xfer_cmpl);

	/* Program descriptor location */
	reg = XLNX_REG(H2C_SGDMA, 0, H2C_SGDMA_DESC_LOW_ADDR) + chan_offset;
	val = pevb->descs_dma_addr & 0xffffffffU;
	pevb_writel(pevb, BAR_DMA, val, reg);
	reg = XLNX_REG(H2C_SGDMA, 0, H2C_SGDMA_DESC_HIGH_ADDR) + chan_offset;
	val = pevb->descs_dma_addr >> 32;
	pevb_writel(pevb, BAR_DMA, val, reg);
	reg = XLNX_REG(H2C_SGDMA, 0, H2C_SGDMA_DESC_ADJACENT) + chan_offset;
	pevb_writel(pevb, BAR_DMA, 0, reg);
	/* Clear any pending status */
	reg = XLNX_REG(H2C, 0, H2C_STATUS_RD_CLR) + chan_offset;
	pevb_readl(pevb, BAR_DMA, reg);
	/* Enable all IRQs in channel */
	reg = XLNX_REG(H2C, 0, H2C_INT_EN) + chan_offset;
	pevb_writel(pevb, BAR_DMA, 0xffffffffU, reg);
	/* Enable channel IRQ at top level */
	reg = XLNX_REG(IRQ, 0, IRQ_CH_INT_EN_W1S);
	val = XLNX_DMA_IRQ_CH_H2C_BIT(irq_int_en_bit_offset);
	pevb_writel(pevb, BAR_DMA, val, reg);
	/* Start DMA */
	reg = XLNX_REG(H2C, 0, H2C_CTRL) + chan_offset;
	val = (XLNX_DMA_H2C_CTRL_IE_DESC_ERR_MASK <<
			XLNX_DMA_H2C_CTRL_IE_DESC_ERR_SHIFT) |
		(XLNX_DMA_H2C_CTRL_IE_WRITE_ERR_MASK <<
			XLNX_DMA_H2C_CTRL_IE_WRITE_ERR_SHIFT) |
		(XLNX_DMA_H2C_CTRL_IE_READ_ERR_MASK <<
			XLNX_DMA_H2C_CTRL_IE_READ_ERR_SHIFT) |
		XLNX_DMA_H2C_CTRL_IE_IDLE_STOPPED |
		XLNX_DMA_H2C_CTRL_IE_INVALID_LEN |
		XLNX_DMA_H2C_CTRL_IE_MAGIC_STOPPED |
		XLNX_DMA_H2C_CTRL_IE_ALIGN_MISMATCH |
		XLNX_DMA_H2C_CTRL_IE_DESC_COMPLETED |
		XLNX_DMA_H2C_CTRL_IE_DESC_STOPPED |
		XLNX_DMA_H2C_CTRL_RUN;
	/*
	 * Ensure all memory writes for descriptor and configuration registers
	 * have completed before triggering the DMA operation.
	 */
	wmb();
	pevb_writel(pevb, BAR_DMA, val, reg);
	/* Wait for DMA completion (via IRQ) */
	ret = wait_for_completion_interruptible(&pevb->dma_xfer_cmpl);
	if (ret)
		dev_err(&pevb->pdev->dev, "DMA interrupted\n");
	else {
		if (pevb->h2c_error) {
			dev_err(&pevb->pdev->dev, "DMA failed\n");
			ret = -EIO;
		}
	}
	/* Disable channel IRQ at top level */
	reg = XLNX_REG(IRQ, 0, IRQ_CH_INT_EN_W1C);
	val = XLNX_DMA_IRQ_CH_H2C_BIT(irq_int_en_bit_offset);
	pevb_writel(pevb, BAR_DMA, val, reg);
	/* Disable all IRQs in channel */
	reg = XLNX_REG(H2C, 0, H2C_INT_EN) + chan_offset;
	pevb_writel(pevb, BAR_DMA, 0, reg);
	/* Cancel descriptor fetches */
	reg = XLNX_REG(SGDMA, 0, SGDMA_CTRL_W1S);
	val = BIT(sgma_ctrl_bit);
	pevb_writel(pevb, BAR_DMA, val, reg);
	reg = XLNX_REG(SGDMA, 0, SGDMA_CTRL_W1C);
	pevb_writel(pevb, BAR_DMA, val, reg);
	/* Cancel channel operation */
	reg = XLNX_REG(H2C, 0, H2C_CTRL) + chan_offset;
	pevb_writel(pevb, BAR_DMA, 0, reg);

	return ret;
}

static int pevb_dma_h2c(struct pevb *pevb, dma_addr_t pcie_addr,
	unsigned long ram_offset, unsigned long len)
{
	struct xlnx_dma_desc *desc;

	dev_dbg(&pevb->pdev->dev, "DMA H2C PCI:0x%llx -> BUF:0%04lx +0x%lx\n",
		pcie_addr, ram_offset, len);

	/* Create descriptor */
	desc = pevb->descs_ptr;
	desc->control = XLNX_DMA_DESC_CONTROL_MAGIC |
		XLNX_DMA_DESC_CONTROL_EOP |
		XLNX_DMA_DESC_CONTROL_COMPLETED |
		XLNX_DMA_DESC_CONTROL_STOP;
	desc->len = len;
	desc->src_adr = pcie_addr & 0xffffffffU;
	desc->src_adr_hi = pcie_addr >> 32;
	desc->dst_adr = ram_offset & 0xffffffffU;
	desc->dst_adr_hi = ram_offset >> 32;
	desc->nxt_adr = 0;
	desc->nxt_adr_hi = 0;

	return pevb_dma(pevb, false);
}

static int pevb_dma_c2h(struct pevb *pevb, dma_addr_t pcie_addr,
	unsigned long ram_offset, unsigned long len)
{
	struct xlnx_dma_desc *desc;

	dev_dbg(&pevb->pdev->dev, "DMA C2H BUF:0x%04lx -> PCI:0x%llx +0x%lx\n",
		ram_offset, pcie_addr, len);

	/* Create descriptor */
	desc = pevb->descs_ptr;
	desc->control = XLNX_DMA_DESC_CONTROL_MAGIC |
		XLNX_DMA_DESC_CONTROL_EOP |
		XLNX_DMA_DESC_CONTROL_COMPLETED |
		XLNX_DMA_DESC_CONTROL_STOP;
	desc->len = len;
	desc->src_adr = ram_offset & 0xffffffffU;
	desc->src_adr_hi = ram_offset >> 32;
	desc->dst_adr = pcie_addr & 0xffffffffU;
	desc->dst_adr_hi = pcie_addr >> 32;
	desc->nxt_adr = 0;
	desc->nxt_adr_hi = 0;

	return pevb_dma(pevb, true);
}

static int pevb_dma_h2c2h(struct pevb *pevb, struct pevb_userbuf *src,
	struct pevb_userbuf *dst, u64 len)
{
	int ret;
	u64 overall_len_remaining = len;
	int src_idx = -1, dst_idx = -1;
	dma_addr_t src_addr, dst_addr;
	u64 src_len_remaining = 0, dst_len_remaining = 0;
	u64 len_chunk;

	if (down_interruptible(&pevb->sem))
		return -ERESTARTSYS;

	while (overall_len_remaining) {
		if (!src_len_remaining) {
			src_idx++;
			if (src_idx >= src->n_dmas) {
				ret = -EINVAL;
				goto unlock;
			}
			src_addr = src->dmas[src_idx].addr;
			src_len_remaining = src->dmas[src_idx].len;
		}
		if (!dst_len_remaining) {
			dst_idx++;
			if (dst_idx >= dst->n_dmas) {
				ret = -EINVAL;
				goto unlock;
			}
			dst_addr = dst->dmas[dst_idx].addr;
			dst_len_remaining = dst->dmas[dst_idx].len;
		}

		len_chunk = min_t(u64, src_len_remaining, dst_len_remaining);
		len_chunk = min_t(u64, len_chunk, FPGA_RAM_SIZE);
		len_chunk = min_t(u64, len_chunk, overall_len_remaining);

		ret = pevb_dma_h2c(pevb, src_addr, 0, len_chunk);
		if (ret)
			goto unlock;

		ret = pevb_dma_c2h(pevb, dst_addr, 0, len_chunk);
		if (ret)
			goto unlock;

		overall_len_remaining -= len_chunk;
		src_len_remaining -= len_chunk;
		dst_len_remaining -= len_chunk;
		src_addr += len_chunk;
		dst_addr += len_chunk;
	}

	ret = 0;

unlock:
	up(&pevb->sem);

	return ret;
}

#define VALID_FLAGS ( \
	PICOEVB_DMA_FLAG_SRC_IS_CUDA | \
	PICOEVB_DMA_FLAG_DST_IS_CUDA \
)

static int pevb_ioctl_dma(struct pevb_file *pevb_file, unsigned long arg)
{
	struct pevb *pevb = pevb_file->pevb;
	void __user *argp = (void __user *)arg;
	struct picoevb_rdma_dma dma_params;
	struct pevb_userbuf src_ubuf = {0}, dst_ubuf = {0};
	int ret;

	if (copy_from_user(&dma_params, argp, sizeof(dma_params)))
		return -EFAULT;

	if (dma_params.flags & ~VALID_FLAGS)
		return -EINVAL;

	mutex_lock(&pevb_file->lock);

	if (dma_params.flags & PICOEVB_DMA_FLAG_SRC_IS_CUDA)
		ret = pevb_get_userbuf_cuda(pevb_file, &src_ubuf,
			dma_params.src, dma_params.len, 1);
	else
		ret = pevb_get_userbuf_pages(pevb, &src_ubuf, dma_params.src,
			dma_params.len, 1);
	if (ret)
		goto put_userbuf_src;

	if (dma_params.flags & PICOEVB_DMA_FLAG_DST_IS_CUDA)
		ret = pevb_get_userbuf_cuda(pevb_file, &dst_ubuf,
			dma_params.dst, dma_params.len, 0);
	else
		ret = pevb_get_userbuf_pages(pevb, &dst_ubuf, dma_params.dst,
			dma_params.len, 0);
	if (ret)
		goto put_userbuf_dst;

	ret = pevb_dma_h2c2h(pevb, &src_ubuf, &dst_ubuf, dma_params.len);
	if (ret)
		goto put_userbuf_dst;

	ret = 0;
	/* fall-through for cleanup */

put_userbuf_dst:
	pevb_put_userbuf(pevb, &dst_ubuf);
put_userbuf_src:
	pevb_put_userbuf(pevb, &src_ubuf);
	mutex_unlock(&pevb_file->lock);

	return ret;
}

static long pevb_fops_unlocked_ioctl(struct file *filep, unsigned int cmd,
	unsigned long arg)
{
	struct pevb_file *pevb_file = filep->private_data;

	switch (cmd) {
	case PICOEVB_IOC_LED:
		return pevb_ioctl_led(pevb_file, arg);
	case PICOEVB_IOC_PIN_CUDA:
		return pevb_ioctl_pin_cuda(pevb_file, arg);
	case PICOEVB_IOC_UNPIN_CUDA:
		return pevb_ioctl_unpin_cuda(pevb_file, arg);
	case PICOEVB_IOC_DMA:
		return pevb_ioctl_dma(pevb_file, arg);
	default:
		return -EINVAL;
	}
}

static const struct file_operations pevb_fops = {
	.owner		= THIS_MODULE,
	.open		= pevb_fops_open,
	.release	= pevb_fops_release,
	.unlocked_ioctl	= pevb_fops_unlocked_ioctl,
};

static int pevb_probe(struct pci_dev *pdev, const struct pci_device_id *ent)
{
	struct pevb *pevb;
	int ret;

	pevb = devm_kzalloc(&pdev->dev, sizeof(*pevb), GFP_KERNEL);
	if (!pevb)
		return -ENOMEM;
	pci_set_drvdata(pdev, pevb);
	pevb->pdev = pdev;

	/*
	 * In practice, there is a limit of FPGA_RAM_SIZE. However, since every
	 * DMA operation actually consists of two copies (H2C and C2H) that are
	 * interleaved together in FPGA_RAM_SIZE chunks, and the src and dst
	 * IOVA mappings may not be identically aligned due to user-space not
	 * enforcing any particular alignment of the memory allocations, and
	 * hence may not be identically chunked into <=FPGA_RAM_SIZE segment
	 * sizes by dma_map_sg(), we cannot rely on dma_map_sg()'s chunking in
	 * this case. Instead, this driver must handle the chunking itself, and
	 * so can accept arbitrarily long IOVA chunks in sg lists.
	 */
	pevb->dma_params.max_segment_size = UINT_MAX;
	pdev->dev.dma_parms = &pevb->dma_params;

	sema_init(&pevb->sem, 1);
	init_completion(&pevb->dma_xfer_cmpl);

	pevb->descs_ptr = dmam_alloc_coherent(&pdev->dev, SZ_4K,
		&pevb->descs_dma_addr, GFP_KERNEL);
	if (!pevb->descs_ptr) {
		dev_err(&pdev->dev,
			"dma_alloc_coherent(descriptors): failed\n");
		return -ENOMEM;
	}

	ret = alloc_chrdev_region(&pevb->devt, 0, 1, MODULENAME);
	if (ret < 0) {
		dev_err(&pdev->dev, "alloc_chrdev_region(): %d\n", ret);
		return ret;
	}

	cdev_init(&pevb->cdev, &pevb_fops);
	ret = cdev_add(&pevb->cdev, pevb->devt, 1);
	if (ret < 0) {
		dev_err(&pdev->dev, "cdev_add(): %d\n", ret);
		goto err_unregister_chrdev_region;
	}

	pevb->devnode = device_create(pevb_class, &pevb->pdev->dev, pevb->devt,
		NULL, "picoevb");
	if (!pevb->devnode) {
		ret = -ENOMEM;
		goto err_cdev_del;
	}

	ret = pcim_enable_device(pdev);
	if (ret < 0) {
		dev_err(&pdev->dev, "pci_enable_device(): %d\n", ret);
		goto err_device_destroy;
	}

	ret = pcim_iomap_regions(pdev, BIT(BAR_GPIO) | BIT(BAR_DMA),
		MODULENAME);
	if (ret < 0) {
		dev_err(&pdev->dev, "pcim_iomap_regions(): %d\n", ret);
		goto err_device_destroy;
	}
	pevb->iomap = pcim_iomap_table(pdev);

	pci_set_master(pdev);

	ret = request_irq(pdev->irq, pevb_irq_handler, IRQF_SHARED,
		dev_name(&pdev->dev), pevb);
	if (ret) {
		dev_err(&pdev->dev, "request_irq(): %d\n", ret);
		goto err_clear_master;
	}

	return 0;

err_clear_master:
	pci_clear_master(pdev);
err_device_destroy:
	device_destroy(pevb_class, pevb->devt);
err_cdev_del:
	cdev_del(&pevb->cdev);
err_unregister_chrdev_region:
	unregister_chrdev_region(pevb->devt, 1);
	return ret;
}

static void pevb_remove(struct pci_dev *pdev)
{
	struct pevb *pevb = pci_get_drvdata(pdev);

	free_irq(pdev->irq, pevb);
	pci_clear_master(pdev);
	device_destroy(pevb_class, pevb->devt);
	cdev_del(&pevb->cdev);
	unregister_chrdev_region(pevb->devt, 1);
	pdev->dev.dma_parms = NULL;
}

static void pevb_shutdown(struct pci_dev *pdev)
{
}

static const struct pci_device_id pevb_pci_ids[] = {
	{ PCI_DEVICE(PCI_VENDOR_ID_NVIDIA, 0x001), },
	{ },
};
MODULE_DEVICE_TABLE(pci, pevb_pci_ids);

static struct pci_driver pevb_driver = {
	.name		= MODULENAME,
	.id_table	= pevb_pci_ids,
	.probe		= pevb_probe,
	.remove		= pevb_remove,
	.shutdown	= pevb_shutdown,
};

static int __init pevb_init(void)
{
	int ret;

	pevb_class = class_create(THIS_MODULE, "chardrv");
	if (!pevb_class)
		return -ENOMEM;

	ret = pci_register_driver(&pevb_driver);
	if (ret)
		class_destroy(pevb_class);

	return ret;
}
module_init(pevb_init);

static void __exit pevb_exit(void)
{
	pci_unregister_driver(&pevb_driver);
	class_destroy(pevb_class);
}
module_exit(pevb_exit);

MODULE_AUTHOR("Stephen Warren <swerren@nvidia.com>");
MODULE_LICENSE("GPL v2");
