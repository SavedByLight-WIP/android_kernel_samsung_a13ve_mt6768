#!/bin/bash

export CROSS_COMPILE=$(pwd)/toolchain/gcc/linux-x86/aarch64/aarch64-linux-android-4.9/bin/aarch64-linux-androidkernel-
export CC=$(pwd)/toolchain/clang/host/linux-x86/clang-r383902/bin/clang
export CLANG_TRIPLE=aarch64-linux-gnu-
export ARCH=arm64
#export ANDROID_MAJOR_VERSION=r

export KCFLAGS=-w
export CONFIG_SECTION_MISMATCH_WARN_ONLY=y

make -C $(pwd) O=$(pwd)/out KCFLAGS=-w CONFIG_SECTION_MISMATCH_WARN_ONLY=y a13ve_defconfig
make -C $(pwd) O=$(pwd)/out KCFLAGS=-w CONFIG_SECTION_MISMATCH_WARN_ONLY=y -j16

cp out/arch/arm64/boot/Image $(pwd)/arch/arm64/boot/Image

###############################################################################
# External connectivity modules (bt / gps / fmradio / connfem / udc_lib)
#
# These are NOT part of the main kernel obj-y/obj-m tree (unlike wlan, which
# is built in via CONFIG_WLAN_DRV_BUILD_IN). They build as standalone
# out-of-tree kernel modules against the kernel we just built above, using
# the same pattern as any external module (M=<dir>, O=<kernel out dir>).
#
# UNTESTED: I have no aarch64 toolchain or network access in the sandbox
# that generated this script, so this has never actually been compiled.
# Treat it as a documented starting point, not a verified build step.
#
# Verified/derived values (from your device's Loaded Modules list and
# defconfig, not guessed):
#   - BT_PLATFORM=connac1x   -> matches loaded module "bt_drv_connac1x"
#     (module Makefile names the .ko bt_drv_$(BT_PLATFORM))
#   - fmradio MODULE_NAME=fmradio_drv_mt6631 -> matches loaded module
#     "fmradio_drv_mt6631"; CFG_FM_CHIP is left unset so the Makefile's
#     default branch builds the mt6631 chip driver, consistent with
#     CONFIG_MTK_FM_CHIP="MT6631_FM" in a13ve_defconfig.
#   - gps: GPS_CHIP_ID just needs to be anything other than the literal
#     string "common" for the real gps_drv driver to build; left unset.
#   - connfem: no chip-specific variable required.
#
# NOT verified: whether these are the exact chip/board variant values
# Samsung actually used for A13VE's BoardConfig — I could not find that
# in either archive you provided. If a build fails or produces a .ko with
# unexpected behavior, this is the first place to check.

KERNEL_OUT=$(pwd)/out
VENDOR_CONN=$(pwd)/../vendor/mediatek/kernel_modules/connectivity
VENDOR_UDC=$(pwd)/../vendor/mediatek/kernel_modules/udc
EXT_MOD_OUT=$(pwd)/out_ext_modules
mkdir -p "$EXT_MOD_OUT"

build_ext_module() {
    local moddir="$1"
    shift
    if [ ! -d "$moddir" ]; then
        echo "WARNING: $moddir not found, skipping"
        return
    fi
    make -C $(pwd) O="$KERNEL_OUT" ARCH=arm64 CROSS_COMPILE=$CROSS_COMPILE \
        M="$moddir" KERNEL_OUT="$KERNEL_OUT" "$@" modules
    find "$moddir" -maxdepth 1 -name '*.ko' -exec cp -v {} "$EXT_MOD_OUT/" \;
}

build_ext_module "$VENDOR_CONN/bt/mt66xx/wmt" BT_PLATFORM=connac1x
build_ext_module "$VENDOR_CONN/gps"
build_ext_module "$VENDOR_CONN/connfem"
build_ext_module "$VENDOR_CONN/fmradio" MODULE_NAME=fmradio_drv_mt6631
build_ext_module "$VENDOR_UDC"

echo "External modules (if built successfully) are in $EXT_MOD_OUT"
echo "These still need to be placed into your ramdisk (e.g. /lib/modules or"
echo "/vendor/lib/modules) with matching insmod/modules.load entries in"
echo "init.rc -- that part is not automated here since it depends on your"
echo "actual ramdisk layout."
