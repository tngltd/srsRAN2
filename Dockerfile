# srsRAN 4G build environment (Ubuntu 24.04, x86_64 or arm64).
# The CMake/source fixes on this branch make it build cleanly on GCC 13.
#
# Build the image:   docker build -t srsran-build .
# Compile the code:  ./docker-build.sh   (mounts the repo, builds into ./build_docker)
FROM ubuntu:24.04

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
        libpcsclite-dev \
        libuhd-dev \
        uhd-host \
        iputils-ping \
        iproute2 \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /srsran
CMD ["/bin/bash"]
