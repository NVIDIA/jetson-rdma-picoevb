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

SRC_DIR="$(find /usr/src/nvidia/nvidia-oot/* -name nv-p2p.h 2>/dev/null|head -1|xargs dirname 2>/dev/null)"
if [ ! -d "${SRC_DIR}" ]; then
	SRC_DIR="$(find /usr/src/./linux-headers-tegra-oot* -name nv-p2p.h 2>/dev/null|head -1|xargs dirname 2>/dev/null)"
fi
echo ${SRC_DIR}
export NVIDIA_SRC_DIR="$(echo $(cd $SRC_DIR && cd ../ && pwd))"
if [ ! -d "${NVIDIA_SRC_DIR}" ]; then
        echo "ERROR: Could not find nv-p2p.h"
        exit 1
fi

NV_EXTRA_SYMBOLS="$(find /usr/src/nvidia/nvidia-oot/* -name 'Module.symvers' |head -1)"
if [ ! -f "${NV_EXTRA_SYMBOLS}" ]; then
	NV_EXTRA_SYMBOLS="$(find  /usr/src/./linux-headers-tegra-oot* -name 'Module.symvers' |head -1)"
fi

echo ${NV_EXTRA_SYMBOLS}
export NVIDIA_EXTRA_SYMBOLS=${NV_EXTRA_SYMBOLS}
if [ ! -f "${NVIDIA_EXTRA_SYMBOLS}" ]; then
        echo "ERROR: Could not find NVIDIA_EXTRA_SYMBOL"
        exit 1
fi
exec make
