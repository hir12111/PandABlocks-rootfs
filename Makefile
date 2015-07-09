# Top level make file for building u-boot, kernel, rootfs.

include CONFIG

# First stage bootloader image
# This is managed here under source control, despite being a binary, because it
# will never change and the build process is already recorded elsewhere.
FSBL_ELF = $(PWD)/fsbl.elf


# U_BOOT_ELF = $(HOME)/targetOS/PandA/PandaLinux/images/u-boot.elf

# Device tree compiler, generated by Linux kernel build.
DTC = $(LINUX_BUILD)/scripts/dtc/dtc


export PATH := $(BINUTILS_DIR):$(PATH)

# ------------------------------------------------------------------------------
# Helper code lifted from rootfs

# Function for safely quoting a string before exposing it to the shell.
# Wraps string in quotes, and escapes all internal quotes.  Invoke as
#
#   $(call SAFE_QUOTE,string to expand)
#
SAFE_QUOTE = '$(subst ','\'',$(1))'

# )' (Gets vim back in sync)

# Passing makefile exports through is a bit tiresome.  We could mark our
# symbols with export -- but that means *every* command gets them, and I
# don't like that.  This macro instead just exports the listed symbols into a
# called function, designed to be called like:
#
#       $(call EXPORT,$(EXPORTS)) script
#
EXPORT = $(foreach var,$(1),$(var)=$(call SAFE_QUOTE,$($(var))))


# Both kernel and u-boot builds need these two symbols to be exported
EXPORTS = $(call EXPORT,CROSS_COMPILE ARCH)


# ------------------------------------------------------------------------------
# Basic rules

default: u-boot

clean:
	rm -rf $(BUILD_ROOT)

clean-all: clean
	-chmod -R +w $(SRC_ROOT)
	rm -rf $(ZYNQ_ROOT)


# ------------------------------------------------------------------------------
# Building u-boot
#

U_BOOT_SRC = $(SRC_ROOT)/u-boot-$(U_BOOT_TAG)
U_BOOT_BUILD = $(BUILD_ROOT)/u-boot
U_BOOT_ELF = $(U_BOOT_BUILD)/u-boot.elf

MAKE_U_BOOT = $(EXPORTS) KBUILD_OUTPUT=$(U_BOOT_BUILD) $(MAKE) -C $(U_BOOT_SRC)

DEVICE_TREE_DTB = $(BOOT_BUILD)/devicetree.dtb


# Rule to create binary device tree from device tree source.
$(DEVICE_TREE_DTB): devicetree.dts
	$(DTC) -o $@ -O dtb -I dts $<

$(U_BOOT_SRC):
	mkdir -p $(SRC_ROOT)
	unzip -q $(TAR_REPO)/u-boot-$(U_BOOT_TAG) -d $(SRC_ROOT)
	patch -p1 -d $(U_BOOT_SRC) < u-boot/u-boot.patch
	ln -s $(PWD)/u-boot/PandA_defconfig $(U_BOOT_SRC)/configs
	ln -s $(PWD)/u-boot/PandA.h $(U_BOOT_SRC)/include/configs
	chmod -R a-w $(U_BOOT_SRC)

$(U_BOOT_ELF): $(U_BOOT_SRC)
	mkdir -p $(U_BOOT_BUILD)
	$(MAKE_U_BOOT) PandA_config
	$(MAKE_U_BOOT) EXT_DTB=$(DEVICE_TREE_DTB)
	ln -s u-boot $(U_BOOT_ELF)

u-boot: $(U_BOOT_ELF)
u-boot-src: $(U_BOOT_SRC)


# ------------------------------------------------------------------------------
# Boot image
#

# Once we have u-boot and fsbl build we can assemble the first stage boot image.
#

$(BOOT_BUILD)/boot.bif:
	mkdir -p $(BOOT_BUILD)
	scripts/make_boot.bif $@ $(FSBL_ELF) $(U_BOOT_ELF)

$(BOOT_BUILD)/boot.bin: $(BOOT_BUILD)/boot.bif $(FSBL_ELF) $(U_BOOT_ELF)
	cd $(BOOT_BUILD)  &&  $(BOOTGEN) -w -image boot.bif -o i $@

boot: $(BOOT_BUILD)/boot.bin $(DEVICE_TREE_DTB)

# # Inverse rule to extract device tree source from blob.
# %.dts: %.dtb
# 	$(DTC) -o $@ -O dts -I dtb $<


.PHONY: clean clean-all u-boot u-boot-src boot
