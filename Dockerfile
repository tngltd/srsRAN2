# srsRAN 4G build environment
# Builds srsUE / srsENB / srsEPC inside Linux (works on Apple Silicon via linux/arm64).
#
# Build the image:   docker build -t srsran-build .
# Compile the code:  see docker-build.sh  (mounts the repo and runs cmake+make)
# Ubuntu 20.04 ships GCC 9, which srsRAN 21.10 was written against.
# Newer GCC (11+) turns a benign turbo-decoder warning into an error via -Werror.
FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        cmake \
        git \
        pkg-config \
        libfftw3-dev \
        libmbedtls-dev \
        libboost-program-options-dev \
        libconfig++-dev \
        libsctp-dev \
        libzmq3-dev \
        libuhd-dev \
        uhd-host \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /srsran
CMD ["/bin/bash"]
