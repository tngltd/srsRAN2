# USRP on shaked-ms-a2 is a LibreSDR (Artix-7 B210/B220 clone) — status & how to finish

## What the device is (confirmed)
- USB `2500:0023`, EEPROM name **"B206i"**, serial **35D5F67**.
- It is a **LibreSDR** — a B210 *clone* built on a Xilinx **Artix-7** FPGA + AD936x,
  NOT a genuine Ettus B210 (which uses a Spartan-6 and enumerates as `0x0020`).
- Sold as "LibreSDR B210 Mini / B220 Mini" (XC7A100T+AD9363 or XC7A200T+AD9361).

## What works (done + committed)
Stock UHD 4.8 does not know PID `0x0023`, so it never sees the device. The patched UHD
(source: `~/uhd-src`, patch: `~/uhd-0x0023-clone.patch`, build: `~/uhd-src/host/build`) makes it
**discoverable and openable** — `uhd_find_devices` reports `product: B210, serial: 35D5F67`.
The patch also carries two `#include <cstdint>` fixes UHD 4.8 needs to build on GCC 15.
The srsRAN build itself is done and the RF-less UE test passes (`./run-zmq-test.sh`).

## The blocker (needs physical access)
The Artix-7 FPGA **will not configure**. On every attempt UHD loads the FX3 firmware, detects
"B210", starts loading the FPGA bitstream, and then fails:
```
Error loading FPGA. FX3 state (5): Unconfigured      # LibreSDR Artix-7 images
this->peek32(0) ... AssertionError: accum_timeout     # stock Ettus Spartan-6 image
```
I tried **all** community LibreSDR FPGA images over the USB/FX3 path — **all fail identically**:
| image | size | source | result |
|-------|------|--------|--------|
| lmesserStep (XC7A75T/100T) | 2.9 MB | github.com/lmesserStep/LibreSDRB210 | Unconfigured |
| alphafox02 / NustyFrozen (XC7A200T) | 4.3 MB | github.com/alphafox02/LibreSDR_USRP | Unconfigured |
| bkerler (XC7A200T) | 4.66 MB | github.com/bkerler/LibreSDR_UHD_B220_Mini_FPGA | Unconfigured |

All three are staged at `~/libresdr-images/` on the box.

Because *every* image fails at the config step (not just one), the USB-load path isn't working on
this board. The most likely reasons, both requiring **hands on the hardware**:
1. **The FPGA must be flashed to its onboard SPI/QSPI flash via JTAG** (Vivado / openFPGALoader +
   a JTAG probe), after which it self-configures at power-on. Some LibreSDR revisions only work
   this way; the over-USB config path does not.
2. The board is a variant whose exact bitstream isn't among the three above (identify the Artix-7
   chip from the silkscreen or JTAG IDCODE, then use the matching image).
Also: the FX3 cannot be power-cycled remotely (the machine's USB hubs don't support per-port power
switching), and a clean physical **unplug/replug** is advisable before the next attempt.

## How to finish (once at the machine)
1. Read the Artix-7 part number off the chip (e.g. `XC7A100T` / `XC7A200T`) — or where the board
   was purchased (AliExpress listing / vendor usually links the exact `usrp_b210_fpga.bin`).
2. Easiest path — flash the FPGA to onboard flash via JTAG with the vendor's/ matching bitstream
   (openFPGALoader or Vivado). Then power-cycle; the FPGA self-configures.
3. If USB-load is supported on your revision: `cp <matching>.bin /usr/share/uhd/images/usrp_b210_fpga.bin`
   then, with the patched UHD:
   ```
   LD_LIBRARY_PATH=~/uhd-src/host/build/lib UHD_IMAGES_DIR=/usr/share/uhd/images \
     ~/uhd-src/host/build/utils/uhd_usrp_probe
   ```
   A good result shows RX/TX channels and freq ranges (no "Unconfigured"/"accum_timeout").
4. To use it from srsRAN, run srsue/srsenb with `LD_LIBRARY_PATH=~/uhd-src/host/build/lib` so it
   picks up the patched libuhd (or `sudo make install` the patched UHD to /usr/local and prepend it).

## The UHD patch (also at ~/uhd-0x0023-clone.patch)
Adds PID `0x0023` → B210 to `B2XX_PID_TO_PRODUCT`, `b200_vid_pid_pairs`, and both device lists in
the `b200_impl` open path; plus `#include <cstdint>` in `ref_clk_calibration_iface.hpp` and
`fbx_constants.hpp` for GCC 15.
