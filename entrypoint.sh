#!/bin/bash
set -eo pipefail

ARCH="${1:-X64}"
TARGET="${2:-RELEASE}"

echo "=========================================================="
echo " Building FtdiUsbSerialDxe for Architecture: ${ARCH}"
echo " Target: ${TARGET}"
echo "=========================================================="

export PYTHON_COMMAND=python3
export PYTHON3_ENABLE=TRUE
export EDK_TOOLS_PATH=/build/edk2/BaseTools
export PACKAGES_PATH=/build/edk2:/build/edk2-platforms:/build

cd /build/edk2
. edksetup.sh BaseTools

TOOLCHAIN="GCC"
if [ "${ARCH}" = "AARCH64" ]; then
    export GCC_AARCH64_PREFIX=aarch64-linux-gnu-
fi

build -p /build/FtdiUsbSerial.dsc -a "${ARCH}" -t "${TOOLCHAIN}" -b "${TARGET}"

mkdir -p /out
EFI_FILE=$(find /build -name "FtdiUsbSerialDxe.efi" -type f | head -n 1)
if [ -z "${EFI_FILE}" ]; then
    echo "Error: FtdiUsbSerialDxe.efi was not generated!"
    exit 1
fi

OUT_NAME="FtdiUsbSerialDxe-${ARCH}.efi"
cp "${EFI_FILE}" "/out/${OUT_NAME}"
cp "${EFI_FILE}" "/out/FtdiUsbSerialDxe.efi"

echo "Build successful: /out/${OUT_NAME}"
ls -lh "/out/${OUT_NAME}"
