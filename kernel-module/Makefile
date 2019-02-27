# Copyright (c) 2019, NVIDIA CORPORATION.  All rights reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms and conditions of the GNU General Public License,
# version 2, as published by the Free Software Foundation.
#
# This program is distributed in the hope it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.

KDIR ?= /lib/modules/$(shell uname -r)/build

.PHONY: default
default: modules

%:
	$(MAKE) -C "$(KDIR)" "M=$$PWD" "$@"

ifdef NV_BUILD_DGPU
modules: Module.symvers

Module.symvers: $(NVIDIA_KO) nvidia-ko-to-module-symvers
	./nvidia-ko-to-module-symvers "$<" "$@"
endif
