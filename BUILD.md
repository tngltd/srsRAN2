# Building & running this srsRAN fork

This is a fork of **srsRAN 4G** (v21.10) — the software-defined-radio LTE suite:

| Binary   | Role                                            |
|----------|-------------------------------------------------|
| `srsue`  | A full LTE UE (a "phone") in software           |
| `srsenb` | An LTE base station (eNodeB)                     |
| `srsepc` | A lightweight LTE core network (MME/HSS/S-P-GW)  |

The fork adds LTE **uplink-sniffing** features (PCI-mode cell search, uplink
channel-estimation tweaks, GPSDO timing). Those changes are on the receive path
and do **not** break normal UE operation — `srsue` still works as a regular UE.

srsRAN 4G is **Linux-only** (it uses SCTP, TUN/TAP, epoll). It does not build or
run on macOS natively; use Linux or the Docker image below.

---

## Build on Ubuntu (recommended — 22.04 or 24.04, x86_64)

```bash
sudo apt-get update
sudo apt-get install -y build-essential cmake git pkg-config \
    libfftw3-dev libmbedtls-dev libboost-program-options-dev \
    libconfig++-dev libsctp-dev libzmq3-dev libpcsclite-dev \
    libuhd-dev uhd-host iputils-ping

mkdir -p build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j"$(nproc)"
```

Binaries land in `build/{srsue,srsenb,srsepc}/src/`.

Dependency notes:
- `libzmq3-dev` — enables the RF-less virtual radio (test without any hardware).
- `libpcsclite-dev` — enables real-SIM support via a PC/SC card reader (`usim mode = pcsc`).
- `libuhd-dev` + `uhd-host` — the USRP driver.

## Build in Docker (e.g. on a Mac)

```bash
docker build -t srsran-build .
./docker-build.sh          # builds into ./build_docker
```
Note: Docker containers have no USB passthrough, so this is for **compiling** and
the ZMQ virtual test only — not for the USRP or a USB SIM reader.

---

## Verify it runs — RF-less end-to-end test (no hardware needed)

```bash
sudo ./run-zmq-test.sh
```
This starts srsEPC + srsENB + srsUE over ZeroMQ, and the UE performs a full
attach with a soft test SIM. Expected output:

```
Network attach successful. IP: 172.16.0.2
...
3 packets transmitted, 3 received, 0% packet loss
```

That confirms PHY sync, RRC connection, NAS attach, SIM authentication, IP
allocation, and the GTP data plane — the entire UE stack.

---

## Using a real SIM (physical card)

Two options in `ue.conf` under `[usim]`:

- `mode = soft` — you type the `imsi` / `k` / `opc` yourself. Only works for
  **test SIMs** whose keys you know (e.g. sysmoUSIM). Commercial SIMs won't work
  (their keys are secret).
- `mode = pcsc` — reads the **physical SIM through a PC/SC reader**; the card does
  the crypto, so this is what a real operator SIM needs. Set `reader` / `pin` if
  required. Requires `libpcsclite-dev` (built in) + `pcscd` running + the reader
  plugged in.

## Hardware notes

- **USRP** — needed for over-the-air use (UHD is built in). Use its GPSDO if present.
- **SIM + PC/SC reader** — needed only for `mode = pcsc` with a real card.
- Real hardware (USRP, USB SIM reader) must run on a **physical Linux machine** —
  cloud VMs and Docker have no USB passthrough.
