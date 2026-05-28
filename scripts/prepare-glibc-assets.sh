#!/usr/bin/env bash
# Prepares glibc packages as APK assets (Opción 3 — sin descarga externa en dispositivo)
# Run this before building the APK to embed glibc + gcc-libs in the app.
set -euo pipefail

GLIBC_BUNDLE_URL="https://github.com/termux-pacman/glibc-packages/releases/download/20221025/gpft-20221025-aarch64.tar.xz"
ASSETS_DIR="flutter_app/android/app/src/main/assets/native/glibc"
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

mkdir -p "$ASSETS_DIR"

GLIBC_PKG="glibc-2.36-1-any.pkg.tar.xz"
GCC_LIBS_PKG="gcc-libs-12.2.0-0-any.pkg.tar.xz"

# Skip if both already exist
if [ -f "$ASSETS_DIR/$GLIBC_PKG" ] && [ -f "$ASSETS_DIR/$GCC_LIBS_PKG" ]; then
    echo "[OK] glibc assets already prepared:"
    ls -lh "$ASSETS_DIR/"
    exit 0
fi

echo "[DOWNLOAD] glibc bundle from GitHub releases..."
curl -sL -o "$TMPDIR/gpft.tar.xz" "$GLIBC_BUNDLE_URL"

echo "[EXTRACT] glibc bundle..."
tar -xJf "$TMPDIR/gpft.tar.xz" -C "$TMPDIR" --strip-components=1

echo "[COPY] Extracting individual packages..."
cp -v "$TMPDIR/$GLIBC_PKG" "$ASSETS_DIR/"
cp -v "$TMPDIR/$GCC_LIBS_PKG" "$ASSETS_DIR/"

echo "[OK] glibc assets ready for APK build:"
ls -lh "$ASSETS_DIR/"
