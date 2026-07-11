# Research log — srsRAN UE on Partner IL with USRP + real SIM

**Objective:** Get srsUE (this fork) running on real hardware (`shaked-ms-a2`) and attach as a
client to the **Partner Israel** LTE network, using the **USRP** for RF and the **physical SIM via
a PC/SC reader**. Authorized/shielded/cabled RF only (per employer report).

**Machine:** `ssh shaked@shaked-ms-a2` — Ubuntu 25.10, x86_64, 32 cores, GCC 15. Work dir
`/home/shaked/srsRAN-project` (branch `build-test-mac`). sudo password held by the operator.

---

## Status summary (updated 2026-07-11)

| Component | State |
|-----------|-------|
| srsRAN build (srsue/srsenb/srsepc) on GCC 15 + PCSC | ✅ Done |
| srsUE full stack verified (ZMQ virtual, soft SIM → attach + data plane) | ✅ Done |
| SIM reader + SIM (ACS ACR39U, Partner IL USIM, IMSI 425010620050443) | ✅ Working |
| Partner IL config staged (`configs/ue_partner_il.conf`) | ✅ Done |
| **USRP (LibreSDR Artix-7 clone) usable** | ⛔ **BLOCKED — FPGA won't configure** |
| Live attach to Partner IL | ⛔ pending USRP |

**Critical path now = the USRP.** Everything else is ready.

---

## Chronology

### Phase 1 — Build (done)
- srsRAN 21.10 fork; Linux-only. Built on macOS/Docker, then Ubuntu 24.04 (Codespace), then the
  target box (Ubuntu 25.10 / GCC 15).
- Fixes committed for modern GCC: demote `-Werror` false positives (GCC 12+); add missing
  `<cstdint>`/`<array>`/`<string>` includes; C++20 template-id constructor in `block_queue.h`.
- Built with `libpcsclite-dev` → PCSC (real-SIM) support compiled in.

### Phase 2 — UE verification without RF (done)
- `run-zmq-test.sh`: srsEPC+srsENB+srsUE over ZeroMQ, soft test SIM → "Network attach successful.
  IP 172.16.0.2", GTP data-plane ping 0% loss. Confirms the whole UE stack works on the box.

### Phase 3 — SIM reader + SIM (done, 2026-07-11)
- Reader: **ACS ACR39U** (USB `072f:b100`), driverless CCID. (Earlier not connected / bad cable.)
- `pcsc_scan`: card present, valid ATR, decodes as 3G/4G USIM.
- `pcsc_usim_test` (srsRAN's own): "USIM is supported", **IMSI 425010620050443** (MCC 425 Israel,
  MNC 01 = **Partner**). The tool's `UMTS auth failed MAC!=XMAC` is EXPECTED (it sends a dummy
  RAND/AUTN); a real network challenge authenticates fine.
- pcscd needs root; srsue runs as root anyway (needs it for the TUN).

### Phase 4 — USRP (BLOCKED)
- Device: USB `2500:0023`, EEPROM name "B206i", serial `35D5F67`. It is a **LibreSDR** — a B210
  *clone* on a Xilinx **Artix-7** FPGA + AD936x (NOT a genuine Ettus B210, which is Spartan-6 / `0x0020`).
- Stock UHD 4.8 doesn't know PID `0x0023`. **Patched UHD** (source `~/uhd-src`, patch
  `~/uhd-0x0023-clone.patch`, build `~/uhd-src/host/build`) adds `0x0023`→B210 in the PID map, the
  discovery list, and both `b200_impl` open-path lists; plus two `<cstdint>` includes for GCC 15.
  → device now **discovered + opened**: `uhd_find_devices` shows product B210, serial 35D5F67.
- **Blocker: the Artix-7 FPGA will not configure.** `b2xx_fx3_utils -L <img>` →
  `Error loading FPGA. FX3 state (5): Unconfigured` (FPGA DONE never asserts). Confirmed on a
  freshly-replugged (clean) FX3, so it is not a wedged-state issue.

#### FPGA images tried (all fail "Unconfigured")
| image | size | source | result |
|-------|------|--------|--------|
| lmesserStep (XC7A75T/100T) | 2.9 MB | github.com/lmesserStep/LibreSDRB210 | Unconfigured |
| alphafox02 / NustyFrozen (XC7A200T) | 4.3 MB | github.com/alphafox02/LibreSDR_USRP | Unconfigured |
| bkerler (XC7A200T) | 4.66 MB | github.com/bkerler/LibreSDR_UHD_B220_Mini_FPGA | Unconfigured |
| gopher2 | — (Vivado source only, no .bin) | github.com/gopher2/LibreSDR | n/a |

Staged at `~/libresdr-images/` on the box. Stock Ettus b210 image backed up at
`/usr/share/uhd/images/usrp_b210_fpga.bin.ettus-stock`.

#### Interpretation
Either (a) the board's exact Artix-7 variant matches none of the above bitstreams, or (b) this
board revision self-configures from onboard SPI flash and does not accept volatile USB config →
needs JTAG flashing. Determining which needs the physical chip part number or a JTAG probe.
Note: the machine's USB hubs don't support per-port power switching (no remote power-cycle).

---

## Plan / next actions
1. Try the RF Swift bundled images (`libresdr_b210.bin`, `libresdr_b220.bin`) — 2 more candidates.
2. Hunt for any other prebuilt variant image (XC7A35T/50T, other forks).
3. If USB config keeps failing on every image → conclude it needs **JTAG flash of the FPGA** (or
   the exact vendor image) and provide the operator the openFPGALoader procedure.
4. Once the USRP probes cleanly (RX/TX channels): `cell_search` on B3/B7/B28 to find Partner's
   EARFCN → fill `dl_earfcn` in `configs/ue_partner_il.conf` → run srsue with the patched UHD
   (`LD_LIBRARY_PATH=~/uhd-src/host/build/lib`) and the real SIM.

## Run command (once USRP works)
```
LD_LIBRARY_PATH=~/uhd-src/host/build/lib UHD_IMAGES_DIR=/usr/share/uhd/images \
  sudo srsue ~/srsRAN-project/configs/ue_partner_il.conf
```

## Log of ongoing attempts
- 2026-07-11: created this log. Re-tried all 3 staged images on clean FX3 → all "Unconfigured".
- 2026-07-11: RF Swift bundles 2 more images (libresdr_b210.bin/b220.bin) but only inside its
  Docker container; **no Docker on the box** → can't extract that way. gopher2 repo is Vivado
  source only (no .bin).
- Key reframing: a B2x0 (incl. clones) loads its FPGA **volatile over USB every boot** (no onboard
  bitstream flash). So this is an **image-matching problem**, not a flash problem — the correct
  bitstream for this board's exact Artix-7 chip *will* configure over USB. All 3 tried images are
  for the wrong chip variant.
- **BLOCKED pending the exact FPGA chip variant.** Images tried cover XC7A75T-ish (2.9 MB) and
  XC7A200T-ish (4.3/4.66 MB). Need to know the actual chip (e.g. XC7A35T/50T/100T/200T) to fetch
  the matching bitstream. Operator could not read the chip marking.
- 2026-07-11: Found VHAE04 repo → vendor Google-Drive packages (RAR). Extracted the VENDOR's own
  images + manual. **This board is a Kintex-7 (XC7K325T) clone** ("K7 replacing the original S6",
  USB3 Type-C, onboard GPS, JTAG on FPC connector). Vendor manual: procedure is just "replace
  usrp_b210_fpga.bin, run uhd_usrp_probe"; vendor ships/validates on **UHD 4.6.0.0**.
- Tried the VENDOR's own images via the vendor's exact procedure (swap bin + uhd_usrp_probe AND
  b2xx -L), on a clean FX3:
  - vendor Kintex XC7K325T (5.2 MB) → Unconfigured / fx3 state 5
  - vendor B210mini (2.86 MB) → Unconfigured
  - vendor B220mini (4.3 MB, == alphafox02) → Unconfigured
  **All 6 distinct images (community + vendor, Artix + Kintex) fail identically.** → It is NOT an
  image problem; the FPGA won't configure at all under my patched UHD 4.8 on Linux.
- Hypothesis: UHD version. Vendor validated on 4.6.0.0; I'm on 4.8. Next: build UHD 4.6 + 0x0023
  patch, retest the vendor Kintex image. If that also fails → it's platform/hardware and needs
  JTAG flashing via the FPC connector (physical) or the vendor's Windows+UHD-4.6+WinUSB stack.
- Staged vendor images at ~/libresdr-images/ (kintex_XC7K325T_5.2MB.bin, vendor_B210mini_2.86MB.bin);
  vendor packages (RAR) + manual PDF also on the box.
- 2026-07-11 (decisive): diffed UHD 4.6 vs 4.8 `b200_iface.cpp` — the FPGA-config logic
  (`load_fpga`) is **byte-identical** (whole file differs by 6 trivial lines). **UHD version cannot
  affect FPGA configuration** → building 4.6 is pointless (also 4.6 needs a large Boost-1.88
  migration: io_service→io_context done, then resolver::query / address_v4::to_ulong removed, etc.).
  **Abandoned the UHD-4.6 path.**

## CONCLUSION (2026-07-11)
The FPGA will not accept volatile USB (FX3 slave-serial) configuration on this unit with ANY
bitstream — 6 distinct images (community + the vendor's own B210mini/B220mini/Kintex), via the
vendor's exact procedure, on a clean FX3, all fail "Unconfigured". The host-side config code is
UHD-version-independent, so this is **not** a software/image/UHD-version problem. It is
board/hardware-level. Remaining possibilities:
1. The board must be **flashed via JTAG** (the FPC connector, per the vendor manual) to its onboard
   config storage; the volatile USB-config path this UHD uses does not bring up this board.
2. A Linux/libusb vs Windows/WinUSB difference in transferring the large (5.2 MB) Kintex bitstream
   during config (vendor only demonstrated Windows + UHD 4.6 + WinUSB).
3. A hardware fault or a difference specific to this unit.

### What unblocks it (needs physical action / operator)
- **JTAG flash** the FPGA with the matching vendor bitstream via the FPC connector
  (openFPGALoader or Vivado + a JTAG probe). Highest-confidence fix.
- OR try the vendor's exact stack on **Windows** (their UHD 4.6 + WinUSB driver + matching bin) to
  confirm the board itself works, isolating Linux/libusb.
- OR confirm with the seller which image/procedure this exact unit needs.

### What IS ready (so live attach is one step away once RF works)
- Patched UHD 4.8 (discovers/opens the device): `~/uhd-src/host/build` (run tools/srsue with
  `LD_LIBRARY_PATH=~/uhd-src/host/build/lib`).
- srsUE build + PCSC + real Partner SIM (IMSI 425010620050443) all verified.
- `configs/ue_partner_il.conf` staged (APN uinternet; fill dl_earfcn after cell_search).
