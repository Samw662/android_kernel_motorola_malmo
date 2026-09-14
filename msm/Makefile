# SPDX-License-Identifier: GPL-2.0
# Qualcomm Display (msm_drm) — in-tree build support

# When building as part of kernel (in-tree), this Makefile is unused.
# The Kbuild handles compilation via obj-m/msm_drm.o.
# This Makefile exists for:
#  1. External module builds (Android DLKM via m= path)
#  2. 'make modules' invoked directly on this directory

DISPLAY_ROOT ?= $(CURDIR)/..

# Support in-tree build: export DISPLAY_ROOT for Kbuild include paths
export DISPLAY_ROOT

KBUILD_OPTIONS += DISPLAY_ROOT=$(DISPLAY_ROOT)

all: modules

modules_install:
	$(MAKE) INSTALL_MOD_STRIP=1 -C $(KERNEL_SRC) M=$(M) modules_install

%:
	$(MAKE) -C $(KERNEL_SRC) M=$(M) $@ $(KBUILD_OPTIONS)

clean:
	rm -f *.o *.ko *.mod.c *.mod.o *~ .*.cmd Module.symvers
	rm -rf .tmp_versions
