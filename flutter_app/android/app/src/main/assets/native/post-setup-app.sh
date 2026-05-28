#!/usr/bin/env bash
set -euo pipefail

: "${PREFIX:?PREFIX not set}"
: "${HOME:?HOME not set}"
: "${TMPDIR:=$PREFIX/tmp}"

PROJECT_DIR="$HOME/.openclaw-android"
BIN_DIR="$PROJECT_DIR/bin"
NODE_DIR="$PROJECT_DIR/node"
PATCH_DIR="$PROJECT_DIR/patches"
GLIBC_LDSO="$PREFIX/glibc/lib/ld-linux-aarch64.so.1"
MARKER="$PROJECT_DIR/.post-setup-done"

mkdir -p "$PROJECT_DIR" "$BIN_DIR" "$PATCH_DIR" "$TMPDIR" "$HOME/.cache/node/compile_cache" "$PREFIX/bin"

export PATH="$BIN_DIR:$PREFIX/bin:$PREFIX/glibc/bin:/system/bin:/system/xbin"
export TMP="$TMPDIR"
export TEMP="$TMPDIR"
export OA_GLIBC=1
export CONTAINER=1
export CLAWDHUB_WORKDIR="$HOME/.openclaw/workspace"
export CPATH="$PREFIX/include/glib-2.0:$PREFIX/lib/glib-2.0/include"
export OPENCLAW_NO_RESPAWN=1
export SSL_CERT_FILE="$PREFIX/etc/tls/cert.pem"
export CURL_CA_BUNDLE="$SSL_CERT_FILE"
export GIT_SSL_CAINFO="$SSL_CERT_FILE"
export GIT_CONFIG_NOSYSTEM=1
export GIT_EXEC_PATH="$PREFIX/libexec/git-core"
export GIT_TEMPLATE_DIR="$PREFIX/share/git-core/templates"
export _OA_WRAPPER_PATH="$BIN_DIR/node"

if [ -f "$MARKER" ]; then
  echo "[SKIP] Native OpenClaw setup already completed"
  exit 0
fi

if [ ! -x "$GLIBC_LDSO" ]; then
  echo "[FAIL] glibc linker missing: $GLIBC_LDSO"
  exit 1
fi

if [ ! -x "$NODE_DIR/bin/node.real" ] && [ -x "$NODE_DIR/bin/node" ]; then
  mv "$NODE_DIR/bin/node" "$NODE_DIR/bin/node.real"
fi

cat > "$BIN_DIR/node" << NODEWRAP
#!$PREFIX/bin/bash
[ -n "\${LD_PRELOAD:-}" ] && export _OA_ORIG_LD_PRELOAD="\$LD_PRELOAD"
unset LD_PRELOAD
_OA_COMPAT="$PATCH_DIR/glibc-compat.js"
export _OA_WRAPPER_PATH="$BIN_DIR/node"
if [ -f "\$_OA_COMPAT" ]; then
  case "\${NODE_OPTIONS:-}" in
    *"\$_OA_COMPAT"*) ;;
    *) export NODE_OPTIONS="\${NODE_OPTIONS:+\$NODE_OPTIONS }-r \$_OA_COMPAT --max-old-space-size=256" ;;
  esac
fi
exec "$GLIBC_LDSO" --library-path "$PREFIX/glibc/lib" "$NODE_DIR/bin/node.real" "\$@"
NODEWRAP
chmod +x "$BIN_DIR/node"

cat > "$BIN_DIR/npm" << NPMWRAP
#!$PREFIX/bin/bash
"$BIN_DIR/node" "$NODE_DIR/lib/node_modules/npm/bin/npm-cli.js" "\$@"
_npm_exit=\$?
case "\$*" in
  *-g*openclaw*|*--global*openclaw*|*openclaw*-g*|*openclaw*--global*)
    _oc_bin="$PREFIX/bin/openclaw"
    _oc_mjs="$PREFIX/lib/node_modules/openclaw/openclaw.mjs"
    if [ -f "\$_oc_mjs" ]; then
      [ -L "\$_oc_bin" ] && rm -f "\$_oc_bin"
      printf '#!$PREFIX/bin/bash\nexec "$BIN_DIR/node" "%s" "\$@"\n' "\$_oc_mjs" > "\$_oc_bin"
      chmod +x "\$_oc_bin"
    fi
    ;;
esac
case "\$*" in
  *-g*|*--global*)
    for _js in "$PREFIX/lib/node_modules"/*/bin/*.js "$PREFIX/lib/node_modules"/@*/*/bin/*.js; do
      [ -f "\$_js" ] || continue
      head -1 "\$_js" | grep -q '^#!/usr/bin/env node$' || continue
      sed -i "1s|#!/usr/bin/env node|#!$BIN_DIR/node|" "\$_js"
    done
    ;;
esac
exit \$_npm_exit
NPMWRAP
chmod +x "$BIN_DIR/npm"

cat > "$BIN_DIR/npx" << NPXWRAP
#!$PREFIX/bin/bash
exec "$BIN_DIR/node" "$NODE_DIR/lib/node_modules/npm/bin/npx-cli.js" "\$@"
NPXWRAP
chmod +x "$BIN_DIR/npx"

if [ -f "$NODE_DIR/bin/corepack" ]; then
  sed -i "1s|#!/usr/bin/env node|#!$BIN_DIR/node|" "$NODE_DIR/bin/corepack" || true
fi

REAL_GIT="$PREFIX/libexec/git-core/git"
if [ -f "$REAL_GIT" ] && [ ! -f "$PREFIX/bin/git.wrapper-installed" ]; then
  rm -f "$PREFIX/bin/git"
  cat > "$PREFIX/bin/git" << GITWRAP
#!$PREFIX/bin/bash
filtered=()
is_clone=false
for a in "\$@"; do
  case "\$a" in
    --recurse-submodules) ;;
    clone) is_clone=true; filtered+=("\$a") ;;
    *) filtered+=("\$a") ;;
  esac
done
if \$is_clone; then
  for a in "\${filtered[@]}"; do
    case "\$a" in clone|--*|-*|http*|ssh*|git*|[0-9]) ;; *) [ -d "\$a" ] && rm -rf "\$a" ;; esac
  done
fi
exec "$REAL_GIT" "\${filtered[@]}"
GITWRAP
  chmod +x "$PREFIX/bin/git"
  touch "$PREFIX/bin/git.wrapper-installed"
fi

cat > "$HOME/.bashrc" << BASHRC
# >>> OpenClaw native Android >>>
export PREFIX="$PREFIX"
export HOME="$HOME"
export TMPDIR="$TMPDIR"
export TMP="\$TMPDIR"
export TEMP="\$TMPDIR"
export PATH="$BIN_DIR:$PREFIX/bin:$PREFIX/glibc/bin:/system/bin:/system/xbin"
export OA_GLIBC=1
export CONTAINER=1
export CLAWDHUB_WORKDIR="$HOME/.openclaw/workspace"
export CPATH="$PREFIX/include/glib-2.0:$PREFIX/lib/glib-2.0/include"
export OPENCLAW_NO_RESPAWN=1
export NODE_COMPILE_CACHE="$HOME/.cache/node/compile_cache"
export SSL_CERT_FILE="$PREFIX/etc/tls/cert.pem"
export CURL_CA_BUNDLE="\$SSL_CERT_FILE"
export GIT_SSL_CAINFO="\$SSL_CERT_FILE"
# <<< OpenClaw native Android <<<
BASHRC

"$BIN_DIR/npm" config set script-shell "$PREFIX/bin/bash" 2>/dev/null || true
"$BIN_DIR/node" --version
"$BIN_DIR/npm" --version
python -c "import yaml" 2>/dev/null || python -m pip install pyyaml -q || true

echo "[INSTALL] npm install -g openclaw@latest --ignore-scripts"
"$BIN_DIR/npm" uninstall -g openclaw clawdhub 2>/dev/null || true
rm -rf "$PREFIX/lib/node_modules/openclaw" "$PREFIX/lib/node_modules/clawdhub" "$HOME/.npm/_cacache" 2>/dev/null || true
"$BIN_DIR/npm" install -g openclaw@latest --ignore-scripts --no-fund --no-audit

if [ -d "$PREFIX/lib/node_modules/openclaw" ]; then
  (cd "$PREFIX/lib/node_modules/openclaw" && npm_config_ignore_scripts=true "$BIN_DIR/node" scripts/postinstall-bundled-plugins.mjs 2>/dev/null) || true
fi

if command -v openclaw >/dev/null 2>&1; then
  openclaw --version || true
else
  _oc_mjs="$PREFIX/lib/node_modules/openclaw/openclaw.mjs"
  if [ -f "$_oc_mjs" ]; then
    printf '#!%s/bin/bash\nexec "%s" "%s" "$@"\n' "$PREFIX" "$BIN_DIR/node" "$_oc_mjs" > "$PREFIX/bin/openclaw"
    chmod +x "$PREFIX/bin/openclaw"
  fi
fi

echo "[PATCH] OpenClaw hardcoded paths"
OPENCLAW_DIR="$PREFIX/lib/node_modules/openclaw"
if [ -d "$OPENCLAW_DIR" ]; then
  TMP_FILES=$(grep -rl '/tmp' "$OPENCLAW_DIR" --include='*.js' --include='*.mjs' --include='*.cjs' 2>/dev/null || true)
  for f in $TMP_FILES; do
    sed -i "s|\"/tmp/|\"$PREFIX/tmp/|g" "$f"
    sed -i "s|'/tmp/|'$PREFIX/tmp/|g" "$f"
    sed -i "s|\`/tmp/|\`$PREFIX/tmp/|g" "$f"
    sed -i "s|\"/tmp\"|\"$PREFIX/tmp\"|g" "$f"
    sed -i "s|'/tmp'|'$PREFIX/tmp'|g" "$f"
  done
  SH_FILES=$(grep -rl '"/bin/sh"\|'\''/bin/sh'\''' "$OPENCLAW_DIR" --include='*.js' --include='*.mjs' --include='*.cjs' 2>/dev/null || true)
  for f in $SH_FILES; do
    sed -i "s|\"/bin/sh\"|\"$PREFIX/bin/sh\"|g" "$f"
    sed -i "s|'/bin/sh'|'$PREFIX/bin/sh'|g" "$f"
  done
  BASH_FILES=$(grep -rl '"/bin/bash"\|'\''/bin/bash'\''' "$OPENCLAW_DIR" --include='*.js' --include='*.mjs' --include='*.cjs' 2>/dev/null || true)
  for f in $BASH_FILES; do
    sed -i "s|\"/bin/bash\"|\"$PREFIX/bin/bash\"|g" "$f"
    sed -i "s|'/bin/bash'|'$PREFIX/bin/bash'|g" "$f"
  done
  ENV_FILES=$(grep -rl '"/usr/bin/env"\|'\''/usr/bin/env'\''' "$OPENCLAW_DIR" --include='*.js' --include='*.mjs' --include='*.cjs' 2>/dev/null || true)
  for f in $ENV_FILES; do
    sed -i "s|\"/usr/bin/env\"|\"$PREFIX/bin/env\"|g" "$f"
    sed -i "s|'/usr/bin/env'|'$PREFIX/bin/env'|g" "$f"
  done
fi

echo "[INSTALL] clawdhub"
"$BIN_DIR/npm" install -g clawdhub --no-fund --no-audit || true
CLAWHUB_DIR="$PREFIX/lib/node_modules/clawdhub"
if [ -d "$CLAWHUB_DIR" ]; then
  (cd "$CLAWHUB_DIR" && "$BIN_DIR/node" -e "require('undici')" 2>/dev/null) || \
    (cd "$CLAWHUB_DIR" && "$BIN_DIR/npm" install undici --no-fund --no-audit) || true
fi

mkdir -p "$HOME/.openclaw/workspace"
openclaw update || true

touch "$MARKER"
echo "[OK] Native OpenClaw setup completed"
