#!/usr/bin/env bash
# RF-less end-to-end test: srsEPC + srsENB + srsUE over ZeroMQ (no SDR hardware).
# Proves the full UE stack runs on Linux: PHY sync, RRC, NAS attach, soft-SIM
# authentication, and IP allocation.
#
# Usage:  sudo ./run-zmq-test.sh   (needs root for the TUN interfaces)
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD="$ROOT/build"
CFG=/tmp/srscfg
LOG=/tmp/srslogs
mkdir -p "$CFG" "$LOG"

# Kill any leftovers from a previous run (stale ZMQ sockets block re-binding).
for p in srsue srsenb srsepc; do pkill -9 -x "$p" 2>/dev/null; done
sleep 1
cleanup() { for p in srsue srsenb srsepc; do pkill -9 -x "$p" 2>/dev/null; done; }
trap cleanup EXIT

# Bind ZMQ to loopback on high ports so the Codespaces/host port-forwarder
# doesn't grab them (it auto-forwards 0.0.0.0 listeners).
ENB_ARGS="fail_on_disconnect=true,tx_port=tcp://127.0.0.1:52000,rx_port=tcp://127.0.0.1:52001,id=enb,base_srate=23.04e6"
UE_ARGS="tx_port=tcp://127.0.0.1:52001,rx_port=tcp://127.0.0.1:52000,id=ue,base_srate=23.04e6"

# Assemble configs from the in-tree .example files (strips .example). Running each
# component from $CFG lets the relative references (sib.conf/rr.conf/rb.conf/user_db.csv) resolve.
cp "$ROOT"/srsenb/enb.conf.example      "$CFG/enb.conf"
cp "$ROOT"/srsenb/sib.conf.example      "$CFG/sib.conf"
cp "$ROOT"/srsenb/rr.conf.example       "$CFG/rr.conf"
cp "$ROOT"/srsenb/rb.conf.example       "$CFG/rb.conf"
cp "$ROOT"/srsue/ue.conf.example        "$CFG/ue.conf"
cp "$ROOT"/srsepc/epc.conf.example      "$CFG/epc.conf"
cp "$ROOT"/srsepc/user_db.csv.example   "$CFG/user_db.csv"
cd "$CFG"

echo ">> starting srsEPC (core network)"
"$BUILD/srsepc/src/srsepc" "$CFG/epc.conf" >"$LOG/epc.log" 2>&1 &
EPC=$!; sleep 3

echo ">> starting srsENB (base station) over ZMQ"
"$BUILD/srsenb/src/srsenb" "$CFG/enb.conf" \
  --rf.device_name=zmq --rf.device_args="$ENB_ARGS" \
  >"$LOG/enb.log" 2>&1 &
ENB=$!; sleep 5

echo ">> starting srsUE (the phone) over ZMQ"
"$BUILD/srsue/src/srsue" "$CFG/ue.conf" \
  --rf.device_name=zmq --rf.device_args="$UE_ARGS" \
  >"$LOG/ue.log" 2>&1 &
UE=$!

echo ">> waiting for network attach..."
for i in $(seq 1 40); do
  grep -q "Network attach successful" "$LOG/ue.log" && break
  sleep 1
done

sleep 2
echo "===================== srsUE log ====================="
cat "$LOG/ue.log"
echo "===================== tun_srsue ====================="
ip addr show tun_srsue 2>&1 || true
echo "===================== data-plane ping (UE -> SGi GW) ====================="
timeout 10 ping -c 3 -I tun_srsue 172.16.0.1 2>&1 || true

echo ">> stopping"
kill "$UE" "$ENB" "$EPC" 2>/dev/null
wait 2>/dev/null
