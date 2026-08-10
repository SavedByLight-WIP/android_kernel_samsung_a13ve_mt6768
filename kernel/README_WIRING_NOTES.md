# a13ve kernel — connectivity module wiring notes

## What was fixed (in-tree, part of this kernel build)
Wi-Fi (`wmt_drv`, `wmt_chrdev_wifi`, `wlan_drv_gen4m`) was missing because its source
was never in the public kernel repo — MediaTek moved it to a sibling repo,
`vendor/mediatek/kernel_modules/connectivity/`, and the kernel's own Makefile
(`drivers/misc/mediatek/connectivity/Makefile`) only pulls it in when
`CONFIG_WLAN_DRV_BUILD_IN=y` and the vendor tree exists one directory above
the kernel source root (`$(srctree)/..`).

Changes made:
1. Added `vendor/mediatek/kernel_modules/connectivity/` (and `udc/`) as a
   sibling of the kernel repo, pulled from your SM-A137F Platform.tar.gz.
2. Uncommented `export CONFIG_WLAN_DRV_BUILD_IN=y` in
   `drivers/misc/mediatek/connectivity/Makefile` so the build symlinks
   `wmt_drv/`, `wmt_chrdev_wifi/`, `wlan_drv_gen4m/` into place and builds
   them in (built directly into the kernel image, not as loadable .ko).

**Keep the folder layout as-is when you build** — `vendor/` must stay a
sibling of `android_kernel_samsung_a13ve_mt6768-master/`, not inside it,
or the `$(srctree)/..` lookup in the Makefile will fail with a
"not existed" error.

**Unverified, worth checking**: the same Makefile hardcodes
`WLAN_CHIP_ID=6765` for all CONNAC builds, while your defconfig targets
`CONFIG_MTK_COMBO_CHIP_CONSYS_6768`. I didn't change this — I have no way
to compile/boot-test this tree to confirm whether it matters for gen4m's
chip detection on mt6769t. If Wi-Fi still misbehaves after this fix, that
line is the next thing to check against MediaTek's mt6768/mt6769 reference.

## bt / gps / fmradio / connfem / udc — build automation added, UNTESTED
`bt_drv_connac1x`, `gps_drv`, `fmradio_drv_mt6631`, `connfem`, and `udc_lib`
each have their own external-module `Makefile` under
`vendor/mediatek/kernel_modules/connectivity/{bt,gps,fmradio,connfem}/` and
`vendor/mediatek/kernel_modules/udc/`. Unlike Wi-Fi, they have no built-in
(`obj-y`) path in the source as provided — they only build as loadable
`.ko` files (`obj-m`). I deliberately did not try to force them built-in:
these drivers wait for `/vendor` to mount and firmware/properties to exist
before init, so compiling them into the kernel image would make them run
far too early in boot — a likely new bootloop, not a fix.

I've added a build stage to both `build_kernel.sh` and
`.github/workflows/build-kernel.yaml` that compiles these as external
modules against the kernel built in the same run, using the standard
`make ... M=<moddir> modules` pattern. **This has never actually been
compiled or boot-tested** — there's no aarch64 toolchain or network access
in the sandbox that produced this zip. Treat it as a documented starting
point.

What's verified vs. assumed in that build stage:
- `BT_PLATFORM=connac1x` and `MODULE_NAME=fmradio_drv_mt6631` — these came
  directly from the loaded-module names you gave me
  (`bt_drv_connac1x`, `fmradio_drv_mt6631`), not guessed, and the fmradio
  chip default matches your defconfig's `CONFIG_MTK_FM_CHIP="MT6631_FM"`.
- GPS and connfem need no chip-specific build variable.
- What I could **not** verify: whether these are the exact board-variant
  values Samsung actually used for A13VE — that lives in a BoardConfig.mk
  I don't have. If the build fails or a module misbehaves, this is the
  first place to check.

Once built, the `.ko` files still need to land inside your ramdisk's
`/lib/modules` (or wherever `/vendor` resolves to) with matching `insmod`
lines in `init.rc`, since this device has a single combined ramdisk baked
into `boot.img` rather than a separate `vendor_boot`. I haven't done that
part — I don't have your ramdisk/`init.rc` to edit safely; send it over
when you're ready and I'll add the load order.
