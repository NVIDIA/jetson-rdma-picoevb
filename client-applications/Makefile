# Copyright (c) 2019, NVIDIA CORPORATION. All rights reserved.
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
# DEALINGS IN THE SOFTWARE.

CC ?= $(CROSS_COMPILE)gcc
ifeq ($(CUDA_TOOLKIT),)
	CUDA_TOOLKIT := $(wildcard /usr/local/cuda-10.1)
endif
ifeq ($(CUDA_TOOLKIT),)
	CUDA_TOOLKIT := $(wildcard /usr/local/cuda-10.0)
endif
NVCC ?= $(CUDA_TOOLKIT)/bin/nvcc

CFLAGS := \
	-ggdb

TARGETS := rdma-cuda rdma-malloc set-leds
default: $(TARGETS)

rdma-cuda: rdma-cuda.cu ../kernel-module/picoevb-rdma-ioctl.h Makefile
	$(NVCC) $(addprefix -Xcompiler ,$(CFLAGS)) -o $@ $< -l cuda

rdma-malloc: rdma-malloc.c ../kernel-module/picoevb-rdma-ioctl.h Makefile
	$(CC) $(CFLAGS) -o $@ $<

set-leds: set-leds.c ../kernel-module/picoevb-rdma-ioctl.h Makefile
	$(CC) $(CFLAGS) -o $@ $<

clean:
	rm -f $(TARGETS)
