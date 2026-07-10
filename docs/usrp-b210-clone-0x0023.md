# USRP B210 clone (USB `2500:0023`, EEPROM name "B206i") — notes

The USRP attached to `shaked-ms-a2` is **not a genuine Ettus B210**. It enumerates as
`2500:0023` with a "Cypress / WestBridge" descriptor and an EEPROM name of **"B206i"**
(not a real Ettus model). Serial `35D5F67`. It is a **B210 clone**.

## What works after patching

Stock UHD 4.8 does **not** recognize PID `0x0023` (its B2x0 list only has `0x0020`–`0x0022`),
so `uhd_find_devices` returns nothing. Patching UHD to add `0x0023` makes it:
- **discoverable** (`uhd_find_devices` → product B210, serial 35D5F67), and
- **openable** (the device open path also has its own device list that needs `0x0023`).

The patch is saved on the machine at `/home/shaked/uhd-0x0023-clone.patch` and reproduced
below. It also includes two `#include <cstdint>` fixes UHD 4.8 needs to build on GCC 15.

Build/install the patched UHD:
```bash
cd ~/uhd-src && git apply uhd-0x0023-clone.patch   # (already applied in ~/uhd-src)
cd host && mkdir -p build && cd build
cmake .. -DCMAKE_INSTALL_PREFIX=/usr/local -DENABLE_PYTHON_API=OFF -DENABLE_PYMOD_UTILS=OFF
make -j$(nproc)
# run tools with:  LD_LIBRARY_PATH=~/uhd-src/host/build/lib UHD_IMAGES_DIR=/usr/share/uhd/images ...
```

## What still does NOT work — the blocker

After discovery+open, UHD loads a stock FPGA image (`usrp_b210_fpga.bin`) and then
**times out reading register 0** (`AssertionError: accum_timeout < _timeout` on `peek32`).
This is the classic signature of an **FPGA image that does not match the clone's hardware**.
Stock Ettus FPGA images (both b200 and b210) do not sync with this board.

**Conclusion:** this clone needs its **vendor's own FPGA image and/or UHD fork** — stock
UHD + stock images cannot drive it. srsRAN can only use it once UHD can fully bring it up.

Also note: repeated firmware reloads put the FX3 into a bad state (`fx3 is in state 5`);
recover with a physical **unplug / replug** of the USRP.

## Options
1. Obtain the clone vendor's UHD fork + FPGA image (whoever supplied the board).
2. Use a **genuine Ettus B200/B210** — it enumerates as `0x0020` and works with stock UHD.
3. Test srsUE without RF using `./run-zmq-test.sh` (already verified working).

## The patch
```diff
--- a/host/lib/usrp/b200/b200_iface.hpp
+++ b/host/lib/usrp/b200/b200_iface.hpp
@@ B2XX_PID_TO_PRODUCT
-        B200MINI_PRODUCT_ID, B200MINI)(B205MINI_PRODUCT_ID, B205MINI);
+        B200MINI_PRODUCT_ID, B200MINI)(B205MINI_PRODUCT_ID, B205MINI)(0x0023, B210);
--- a/host/lib/usrp/b200/b200_impl.hpp   (b200_vid_pid_pairs)
+   ...append (B200_VENDOR_ID, 0x0023)
--- a/host/lib/usrp/b200/b200_impl.cpp   (b200_impl ctor device lists, both branches)
+   ...append (vid/B200_VENDOR_ID, 0x0023)
--- GCC 15 build fixes: add #include <cstdint> to
    host/include/uhd/features/ref_clk_calibration_iface.hpp
    host/lib/include/uhdlib/usrp/dboard/fbx/fbx_constants.hpp
```
