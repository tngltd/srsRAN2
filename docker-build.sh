#!/usr/bin/env bash
# Compile srsRAN 4G inside the srsran-build container.
# Usage: ./docker-build.sh            (builds into ./build_docker)
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

docker run --rm -v "${REPO_DIR}:/srsran" -w /srsran srsran-build bash -c '
    set -e
    mkdir -p build_docker
    cd build_docker
    cmake .. -DCMAKE_BUILD_TYPE=Release
    make -j"$(nproc)"
'
echo "Done. Binaries under build_docker/{srsue,srsenb,srsepc}/src/"
