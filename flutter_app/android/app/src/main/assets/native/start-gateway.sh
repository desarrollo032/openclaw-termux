#!/usr/bin/env bash
set -euo pipefail

export PREFIX="${PREFIX:-__PREFIX__}"
export HOME="${HOME:-__HOME__}"
export TMPDIR="${TMPDIR:-$PREFIX/tmp}"
export TMP="$TMPDIR"
export TEMP="$TMPDIR"
export PATH="$HOME/.openclaw-android/bin:$PREFIX/bin:$PREFIX/glibc/bin:/system/bin:/system/xbin"
export OA_GLIBC=1
export CONTAINER=1
export CLAWDHUB_WORKDIR="$HOME/.openclaw/workspace"
export CPATH="$PREFIX/include/glib-2.0:$PREFIX/lib/glib-2.0/include"
export OPENCLAW_NO_RESPAWN=1
export OPENCLAW_NO_WATCHDOG=1
export UV_THREADPOOL_SIZE=4
export UV_USE_IO_URING=0
export CHOKIDAR_USEPOLLING=false
export CHOKIDAR_INTERVAL=2000
export NODE_COMPILE_CACHE="$HOME/.cache/node/compile_cache"
export SSL_CERT_FILE="$PREFIX/etc/tls/cert.pem"
export CURL_CA_BUNDLE="$SSL_CERT_FILE"
export GIT_SSL_CAINFO="$SSL_CERT_FILE"
export _OA_WRAPPER_PATH="$HOME/.openclaw-android/bin/node"

mkdir -p "$TMPDIR" "$NODE_COMPILE_CACHE" "$HOME/.openclaw-android"
echo "$$" > "$HOME/.openclaw-android/gateway.pid"

exec openclaw gateway --no-color --no-emoji 2>&1
