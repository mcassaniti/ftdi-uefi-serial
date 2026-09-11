#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="${SCRIPT_DIR}/bin"

ARCH="${1:-X64}"
TARGET="${2:-RELEASE}"

echo "=========================================================="
echo " Building FtdiUsbSerialDxe UEFI Driver via Docker"
echo " Architecture : ${ARCH}"
echo " Build Target : ${TARGET}"
echo " Output Dir   : ${BIN_DIR}"
echo "=========================================================="

mkdir -p "${BIN_DIR}"

if ! command -v docker &> /dev/null; then
    echo "Error: docker is not installed or not in PATH."
    exit 1
fi

IMAGE_NAME="ftdi-uefi-serial-builder"

echo "==> Building Docker image: ${IMAGE_NAME}..."
docker build -t "${IMAGE_NAME}" -f "${SCRIPT_DIR}/Dockerfile" "${SCRIPT_DIR}"

if [ "${ARCH}" = "all" ]; then
    ARCHS=("X64" "AARCH64")
else
    ARCHS=("${ARCH}")
fi

for a in "${ARCHS[@]}"; do
    echo "==> Compiling driver for ${a} (${TARGET})..."
    docker run --rm \
        --user "$(id -u):$(id -g)" \
        -v "${BIN_DIR}:/out" \
        "${IMAGE_NAME}" \
        "${a}" "${TARGET}"
done

echo ""
echo "=========================================================="
echo " Build Complete! Output artifacts in ${BIN_DIR}:"
echo "=========================================================="
ls -lh "${BIN_DIR}"/*.efi

echo ""
echo "SHA256 Checksums:"
if command -v sha256sum &> /dev/null; then
    sha256sum "${BIN_DIR}"/*.efi
fi
