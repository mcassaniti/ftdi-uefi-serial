# Multi-architecture EDK II build environment for FtdiUsbSerialDxe
FROM ubuntu:24.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive

# Install EDK II build dependencies & toolchains
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    uuid-dev \
    nasm \
    bison \
    flex \
    git \
    python3 \
    acpica-tools \
    ca-certificates \
    patch \
    gcc-aarch64-linux-gnu \
    g++-aarch64-linux-gnu \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# Clone EDK II core and edk2-platforms
RUN git clone --depth 1 https://github.com/tianocore/edk2.git && \
    git clone --depth 1 https://github.com/tianocore/edk2-platforms.git

# Initialize submodules needed for BaseTools / compilation
WORKDIR /build/edk2
RUN git submodule update --init \
    BaseTools/Source/C/BrotliCompress/brotli \
    MdePkg/Library/MipiSysTLib/mipisyst \
    MdeModulePkg/Library/BrotliCustomDecompressLib/brotli

# Build EDK II BaseTools
RUN make -C BaseTools -j$(nproc)

# Copy patches and platform files from repository
COPY patches/ /build/patches/
COPY FtdiUsbSerial.dsc /build/FtdiUsbSerial.dsc
COPY entrypoint.sh /build/entrypoint.sh

# Apply FtdiUsbSerialDxe bug fixes and feature patches
WORKDIR /build/edk2-platforms
RUN for p in /build/patches/*.patch; do \
        echo "Applying patch $p..." && \
        (git apply --ignore-space-change --whitespace=nowarn "$p" || patch -p1 < "$p"); \
    done

WORKDIR /build
RUN chmod +x /build/entrypoint.sh && chmod -R 777 /build

ENTRYPOINT ["/build/entrypoint.sh"]
CMD ["X64", "RELEASE"]
