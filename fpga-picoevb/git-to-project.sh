#!/bin/bash

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

set -e

cd "$(dirname "${0}")"

vivado=vivado
if [ ! -x "$(which ${vivado})" ]; then
    vivado=~/Xilinx/Vivado/2018.3/bin/vivado
fi

rm -rf vivado-project.srcs
rm -rf vivado-project
"${vivado}" -nojournal -nolog -mode batch -source git-to-ips.tcl

# In theory, the following should work instead of all the mkdir/mv below,
# but that generates synthesis errors:-(
# mv vivado-project/vivado-project.srcs vivado-project.srcs

mkdir -p vivado-project.srcs/sources_1/ip/axi_bram_ctrl_0/
mv vivado-project/vivado-project.srcs/sources_1/ip/axi_bram_ctrl_0/axi_bram_ctrl_0.xci \
   vivado-project.srcs/sources_1/ip/axi_bram_ctrl_0/axi_bram_ctrl_0.xci

mkdir -p vivado-project.srcs/sources_1/ip/axi_gpio_0/
mv vivado-project/vivado-project.srcs/sources_1/ip/axi_gpio_0/axi_gpio_0.xci \
   vivado-project.srcs/sources_1/ip/axi_gpio_0/axi_gpio_0.xci

mkdir -p vivado-project.srcs/sources_1/ip/blk_mem_gen_0/
mv vivado-project/vivado-project.srcs/sources_1/ip/blk_mem_gen_0/blk_mem_gen_0.xci \
   vivado-project.srcs/sources_1/ip/blk_mem_gen_0/blk_mem_gen_0.xci

mkdir -p vivado-project.srcs/sources_1/ip/xdma_0/
mv vivado-project/vivado-project.srcs/sources_1/ip/xdma_0/xdma_0.xci \
   vivado-project.srcs/sources_1/ip/xdma_0/xdma_0.xci

rm -rf vivado-project
"${vivado}" -nojournal -nolog -mode batch -source git-to-project.tcl
