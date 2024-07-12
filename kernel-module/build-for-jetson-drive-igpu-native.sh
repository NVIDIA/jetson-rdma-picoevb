#!/bin/sh

# Copyright (c) 2019-2024, NVIDIA CORPORATION. All rights reserved.
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

NVIDIA_OOT_SRC_DIR="/usr/src/nvidia/nvidia-oot/"
if [ ! -d ${NVIDIA_OOT_SRC_DIR} ]; then
	echo "Nvdia OOT source not found in $NVIDIA_OOT_SRC_DIR"
	NVIDIA_OOT_SRC_DIR="/usr/src/./linux-headers-tegra-oot*"
	if [ ! -d ${NVIDIA_OOT_SRC_DIR} ]; then
		echo "Nvidia OOT  source not found in $NVIDIA_OOT_SRC_DIR"
		exit;
	fi
fi
echo "Nvidia OOT source found at ${NVIDIA_OOT_SRC_DIR}"

NVIDIA_SRC_DIR="$(find ${NVIDIA_OOT_SRC_DIR}/* -name nv-p2p.h 2>/dev/null|head -1|xargs dirname 2>/dev/null)"
export NVIDIA_SRC_DIR="$(echo $(cd $NVIDIA_SRC_DIR && cd ../ && pwd))"
echo ${NVIDIA_SRC_DIR}

export NVIDIA_EXTRA_SYMBOLS="$(find ${NVIDIA_OOT_SRC_DIR}* -name 'Module.symvers' |head -1)"
echo ${NVIDIA_EXTRA_SYMBOLS}

exec make
