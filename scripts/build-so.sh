#!/usr/bin/env bash
set -euo pipefail

# Stage the SCS native libraries (and their BLAS/LAPACK/gfortran/OpenMP runtime
# closure) under scs/native-libs/candidates/<platform>/ with portable rpaths, so
# `raco pkg install` works on pkgs.racket-lang.org without Nix.
#
# Usage: scripts/build-so.sh <target>
#   targets: darwin | linux | linux-aarch64

TARGET="${1:-}"

usage() {
  echo "Usage: $0 <target>"
  echo "  targets: darwin | linux | linux-aarch64"
  exit 1
}

cd "$(dirname "$0")/.."

# Print the lib/ directories of every store path in the scs runtime closure.
scs_closure_libdirs() {
  nix path-info -r nixpkgs#scs 2>/dev/null | while IFS= read -r p; do
    [ -d "$p/lib" ] && echo "$p/lib"
  done
}

# Find a library by basename anywhere in the scs closure; echo its full path.
find_in_closure() {
  local base="$1"
  local d
  while IFS= read -r d; do
    if [ -f "$d/$base" ]; then
      echo "$d/$base"
      return 0
    fi
  done < <(scs_closure_libdirs)
  return 1
}

# ---------------------------------------------------------------------------
# macOS
# ---------------------------------------------------------------------------

# BFS the dependency graph of the seed dylibs, copying every non-system dylib
# into $dest, then rewrite ids/deps/rpaths so they all resolve via @rpath +
# @loader_path.  Handles both /nix/store deps and pre-existing @rpath deps by
# resolving basenames against the scs closure.
bundle_darwin() {
  local dest="$1"
  local scs
  scs=$(nix build --no-link --print-out-paths nixpkgs#scs 2>/dev/null)

  cp -v "$scs/lib/libscsdir.dylib" "$dest/"
  cp -v "$scs/lib/libscsindir.dylib" "$dest/"

  local -a worklist=(libscsdir.dylib libscsindir.dylib)
  local i=0
  while [ "$i" -lt "${#worklist[@]}" ]; do
    local lib="${worklist[$i]}"
    i=$((i + 1))
    local dep base src
    while IFS= read -r dep; do
      base="$(basename "$dep")"
      # skip self-reference and system libraries
      [ "$base" = "$lib" ] && continue
      case "$dep" in
        /usr/lib/*|/System/*) continue ;;
      esac
      if [ ! -f "$dest/$base" ]; then
        if src=$(find_in_closure "$base"); then
          cp -v "$src" "$dest/$base"
          worklist+=("$base")
        else
          echo "Warning: could not locate $base in scs closure" >&2
        fi
      fi
    done < <(otool -L "$dest/$lib" | tail -n +2 | awk '{print $1}')
  done

  # Rewrite install names, dependency paths, and rpaths.
  local f base dep dbase
  for f in "$dest"/*.dylib; do
    base="$(basename "$f")"
    chmod +w "$f"
    install_name_tool -id "@rpath/$base" "$f"
    while IFS= read -r dep; do
      dbase="$(basename "$dep")"
      case "$dep" in
        /usr/lib/*|/System/*) continue ;;
      esac
      [ "$dep" = "@rpath/$dbase" ] && continue
      if [ -f "$dest/$dbase" ]; then
        install_name_tool -change "$dep" "@rpath/$dbase" "$f"
      fi
    done < <(otool -L "$f" | tail -n +2 | awk '{print $1}')
    # Drop any non-@ rpaths (Nix store paths) and add @loader_path/.
    local rp
    for rp in $(otool -l "$f" | awk '/^ *path /{print $2}' | grep -v '^@' || true); do
      install_name_tool -delete_rpath "$rp" "$f" 2>/dev/null || true
    done
    if ! otool -l "$f" | awk '/^ *path /{print $2}' | grep -qx '@loader_path/.'; then
      install_name_tool -add_rpath '@loader_path/.' "$f"
    fi
  done
  echo "Bundled darwin candidate:"
  ls -la "$dest"
}

# ---------------------------------------------------------------------------
# Linux
# ---------------------------------------------------------------------------

# BFS the NEEDED graph of the seed .so files, copy every non-glibc dependency
# from the scs closure, set RPATH=$ORIGIN on each, build the companion glibc
# shim, then rewrite all bundled libs down to the glibc 2.17 baseline so the
# package loads on the older glibc pkg-build.racket-lang.org runs (< 2.27).
#
# polyfill-glibc downgrades most symbols on its own, but nixpkgs' gfortran
# imports glibc's _Float128 math (acosf128/expf128/... @GLIBC_2.26), which has
# no pre-2.26 equivalent.  Those are redirected to libscsshim.so via
# scripts/glibc-renames.txt (see build_glibc_shim_linux / polyfill_glibc_linux).
# libgcc_s is NOT bundled (see $skip below): the toolchain's copy pulls
# _dl_find_object@GLIBC_2.35 which polyfill cannot lower, and libgcc_s is an
# ABI-stable system library present on every Linux host (libgfortran needs only
# ancient GCC_3.3/4.2/4.3 symbols from it), so we let the host provide it.
bundle_linux() {
  local dest="$1" target_arch="${2:-x86_64}"
  local scs patchelf
  scs=$(nix build --no-link --print-out-paths nixpkgs#scs 2>/dev/null)
  patchelf=$(nix build --no-link --print-out-paths nixpkgs#patchelf 2>/dev/null)/bin/patchelf

  cp -v --no-preserve=mode "$scs/lib/libscsdir.so" "$dest/"
  cp -v --no-preserve=mode "$scs/lib/libscsindir.so" "$dest/"

  # glibc / loader libs we must NOT bundle (they come from the host).
  # libgcc_s is included here: it is an ABI-stable system library and the
  # toolchain's copy requires _dl_find_object@GLIBC_2.35, which polyfill-glibc
  # cannot lower; let the host provide it so it does not raise our glibc floor.
  local skip='^(libc|libm|libpthread|libdl|librt|ld-linux.*|libresolv|libutil|libgcc_s)\.'

  local -a worklist=(libscsdir.so libscsindir.so)
  local i=0
  while [ "$i" -lt "${#worklist[@]}" ]; do
    local lib="${worklist[$i]}"
    i=$((i + 1))
    local base src
    while IFS= read -r base; do
      [ -z "$base" ] && continue
      echo "$base" | grep -qE "$skip" && continue
      if [ ! -f "$dest/$base" ]; then
        if src=$(find_in_closure "$base"); then
          cp -v --no-preserve=mode "$src" "$dest/$base"
          worklist+=("$base")
        else
          echo "Warning: could not locate $base in scs closure" >&2
        fi
      fi
    done < <("$patchelf" --print-needed "$dest/$lib")
  done

  local f
  for f in "$dest"/*.so "$dest"/*.so.*; do
    [ -f "$f" ] || continue
    "$patchelf" --set-rpath '$ORIGIN' "$f"
  done
  echo "Set RPATH=\$ORIGIN on bundled libraries"

  # polyfill-glibc only fully supports the symbol-version rewrite on x86_64.
  # The aarch64 candidate ships at its native glibc dep (we only target
  # Ubuntu 24.04+ / glibc 2.39+ there), so skip the shim + polyfill on it.
  if [ "$target_arch" = "x86_64" ]; then
    build_glibc_shim_linux "$dest"
    polyfill_glibc_linux "$dest"
  else
    echo "Skipping glibc shim + polyfill on $target_arch (binaries keep their native glibc dep)"
  fi
  echo "Bundled linux candidate:"
  ls -la "$dest"
}

# Build libscsshim.so from scripts/glibc-shim.c.  This tiny .so ships beside the
# bundled libs and provides definitions that polyfill-glibc redirects the
# binaries to (via scripts/glibc-renames.txt) — see those files for the specific
# symbols and rationale.  Linked against only the libc baseline so it itself
# depends on nothing newer than GLIBC_2.2.5.
build_glibc_shim_linux() {
  local dest="$1"
  local cc_pkg cc
  # nixpkgs#gcc yields multiple outputs (man, out); ask for the out one so the
  # wrapper binary is at $cc_pkg/bin/gcc.
  cc_pkg=$(nix build --no-link --print-out-paths 'nixpkgs#gcc^out' 2>/dev/null)
  cc="$cc_pkg/bin/gcc"
  if [ ! -x "$cc" ]; then
    echo "Warning: gcc not available; skipping libscsshim.so build" >&2
    return
  fi
  # -fno-builtin: the f128 names are recognised by gcc as builtins; our void()
  # stubs intentionally mismatch their signatures, so suppress the builtin
  # handling (and its warnings) — we only need the exported symbol name.
  "$cc" -shared -fPIC -O2 -fno-builtin \
        -Wl,-soname,libscsshim.so \
        -o "$dest/libscsshim.so" \
        scripts/glibc-shim.c
  local patchelf
  patchelf=$(nix build --no-link --print-out-paths nixpkgs#patchelf 2>/dev/null)/bin/patchelf
  "$patchelf" --set-rpath '$ORIGIN' "$dest/libscsshim.so"
  echo "Built libscsshim.so (glibc deps: $(readelf -V "$dest/libscsshim.so" 2>/dev/null | grep -oE 'GLIBC_[0-9]+\.[0-9]+' | sort -V -u | tr '\n' ' '))"
}

# Rewrite the bundled ELF binaries so they only require glibc symbols available
# on the 2.17 baseline (CentOS 7 / manylinux2014), which covers
# pkg-build.racket-lang.org (glibc < 2.27).  polyfill-glibc handles most of the
# downgrade itself; the _Float128 math symbols it cannot rewrite are redirected
# to libscsshim.so via scripts/glibc-renames.txt.  polyfill adds libscsshim.so
# as a NEEDED entry, resolved at load time via the RUNPATH=$ORIGIN set above.
polyfill_glibc_linux() {
  local dest="$1"
  local polyfill
  polyfill=$(nix build --no-link --print-out-paths .#polyfill-glibc 2>/dev/null)/bin/polyfill-glibc
  if [ ! -x "$polyfill" ]; then
    echo "Warning: polyfill-glibc unavailable; skipping glibc downgrade" >&2
    return
  fi
  echo "Polyfilling bundled libs to require only glibc <= 2.17..."
  for f in "$dest"/*.so "$dest"/*.so.*; do
    [ -f "$f" ] || continue
    [ "$(basename "$f")" = "libscsshim.so" ] && continue
    "$polyfill" --rename-dynamic-symbols=scripts/glibc-renames.txt \
                --target-glibc=2.17 "$f"
    echo "  $(basename "$f") -> max glibc dep now: $(readelf -V "$f" 2>/dev/null | grep -oE 'GLIBC_[0-9]+\.[0-9]+' | sort -V -u | tail -1)"
  done
}

case "$TARGET" in
  darwin)
    [ "$(uname)" = "Darwin" ] || { echo "darwin target requires macOS" >&2; exit 1; }
    dest=scs/native-libs/candidates/darwin
    mkdir -p "$dest"
    bundle_darwin "$dest"
    ;;
  linux)
    SYSTEM="$(uname -m)-linux"
    [ "$SYSTEM" = "x86_64-linux" ] || { echo "linux target requires x86_64-linux (got $SYSTEM)" >&2; exit 1; }
    dest=scs/native-libs/candidates/linux-cpu
    mkdir -p "$dest"
    bundle_linux "$dest" x86_64
    ;;
  linux-aarch64)
    SYSTEM="$(uname -m)-linux"
    [ "$SYSTEM" = "aarch64-linux" ] || { echo "linux-aarch64 target requires aarch64-linux (got $SYSTEM)" >&2; exit 1; }
    dest=scs/native-libs/candidates/linux-aarch64
    mkdir -p "$dest"
    bundle_linux "$dest" aarch64
    ;;
  *)
    usage
    ;;
esac

echo "Done."
