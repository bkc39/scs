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
# from the scs closure, set RPATH=$ORIGIN on each, then downgrade the glibc
# requirement to 2.17 (manylinux2014) so the package loads on the older glibc
# pkg-build.racket-lang.org runs.
bundle_linux() {
  local dest="$1" target_arch="${2:-x86_64}"
  local scs patchelf
  scs=$(nix build --no-link --print-out-paths nixpkgs#scs 2>/dev/null)
  patchelf=$(nix build --no-link --print-out-paths nixpkgs#patchelf 2>/dev/null)/bin/patchelf

  cp -v --no-preserve=mode "$scs/lib/libscsdir.so" "$dest/"
  cp -v --no-preserve=mode "$scs/lib/libscsindir.so" "$dest/"

  # glibc / loader libs we must NOT bundle (they come from the host).
  local skip='^(libc|libm|libpthread|libdl|librt|ld-linux.*|libresolv|libutil)\.'

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

  if [ "$target_arch" = "x86_64" ]; then
    local polyfill
    polyfill=$(nix build --no-link --print-out-paths .#polyfill-glibc 2>/dev/null)/bin/polyfill-glibc
    if [ -x "$polyfill" ]; then
      echo "Polyfilling bundled libs to require only glibc <= 2.17..."
      for f in "$dest"/*.so "$dest"/*.so.*; do
        [ -f "$f" ] || continue
        "$polyfill" --target-glibc=2.17 "$f" || true
      done
    else
      echo "Warning: polyfill-glibc unavailable; skipping glibc downgrade" >&2
    fi
  else
    echo "Skipping glibc polyfill on $target_arch"
  fi
  echo "Bundled linux candidate:"
  ls -la "$dest"
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
