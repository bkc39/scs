# Handoff: build & commit the Linux native-lib candidates

> Task for an agent running on **Linux** (with Nix). macOS is done; this is the
> last piece needed for the package to install from pkgs.racket-lang.org and for
> its docs to render on docs.racket-lang.org.

## Background

This repo (`bkc39/scs`) is a Racket binding to SCS. It ships the SCS native
library so `raco pkg install` works without Nix, by committing per-platform
prebuilt libraries under `scs/native-libs/candidates/<platform>/`. The
**darwin** candidate is already committed and validated. The **Linux**
candidates are missing, so the `raco-catalog` CI jobs currently *skip* on Linux
(see `.github/workflows/raco-catalog.yml`), and the catalog/docs build cannot
install the package on its Linux builder.

Your job: produce and commit:
- `scs/native-libs/candidates/linux-cpu/` (x86_64-linux), and
- `scs/native-libs/candidates/linux-aarch64/` (aarch64-linux).

Each holds `libscsdir`, `libscsindir`, and the bundled BLAS/LAPACK/gfortran/
OpenMP runtime closure, with portable rpaths so they load with no Nix store
paths.

## Prerequisites

- Nix with flakes enabled (`experimental-features = nix-command flakes`).
- **Two hosts** (the build script does NOT cross-compile — it guards on
  `uname -m`):
  - an **x86_64-linux** host for `linux-cpu`, and
  - an **aarch64-linux** host for `linux-aarch64`.
  - If you only have one arch, build that candidate; the catalog job for the
    other arch will keep skipping (acceptable, but the package won't install on
    that arch).

## Steps (run on each host)

From the repo root:

```bash
# On an x86_64-linux host:
./scripts/build-so.sh linux            # -> scs/native-libs/candidates/linux-cpu/

# On an aarch64-linux host:
./scripts/build-so.sh linux-aarch64    # -> scs/native-libs/candidates/linux-aarch64/
```

What the script does (see `scripts/build-so.sh`):
- BFS-walks the dependency closure of `libscsdir`/`libscsindir` from
  `nixpkgs#scs` and copies every non-system `.so` into the candidate dir.
- Sets `RUNPATH=$ORIGIN` on each via `patchelf`.
- On **x86_64** only, runs `polyfill-glibc` to rebase the glibc requirement to
  2.17 (manylinux2014) so the libs load on the older glibc that
  pkg-build.racket-lang.org runs. (aarch64 keeps its glibc dep; that candidate
  targets Ubuntu 24.04+ runners only.)

## Validate before committing (mirrors the CI checks)

1. Clean, no-Nix install + full test suite (the key check):

   ```bash
   env -u SCS_NATIVE_LIB_PATH bash scripts/test-local.sh
   ```

   This removes any previous install, copies the candidate libs into
   `scs/native-libs/` via the pre-install hook, and runs `raco test scs/` plus
   all examples (00-09). It must pass.

2. Portability spot-checks (what `raco-catalog.yml` asserts):

   ```bash
   D=scs/native-libs/candidates/linux-cpu     # or linux-aarch64
   # no Nix store paths in any lib:
   for l in "$D"/lib*.so*; do ldd "$l" | grep -q /nix/store && echo "BAD: $l" ; done
   # the SCS solvers must carry RUNPATH=$ORIGIN:
   readelf -d "$D/libscsdir.so"   | grep -E 'R(UN)?PATH'
   readelf -d "$D/libscsindir.so" | grep -E 'R(UN)?PATH'
   # a bundled BLAS must be present (LAPACK build):
   ls "$D"/libopenblas*.so* "$D"/libblas*.so* 2>/dev/null
   ```

## Commit & push

The `candidates/<platform>/` directories are **tracked** (only the top-level
`scs/native-libs/*.so*` staging copies are gitignored). Confirm and commit:

```bash
git checkout -b linux-candidates        # or commit onto the docs branch / master per maintainer
git status                              # candidates/linux-* should show as new files
git add scs/native-libs/candidates/linux-cpu scs/native-libs/candidates/linux-aarch64
git commit -m "Add Linux native-lib candidates (x86_64 + aarch64)"
git push -u origin linux-candidates
gh pr create --base master --title "Linux native-lib candidates" \
  --body "Built with scripts/build-so.sh on native x86_64-linux and aarch64-linux hosts; test-local.sh and the raco-catalog portability checks pass."
```

Sizes: the BLAS libs are the largest (~25-30 MB each), well under GitHub's
100 MB/file limit, so no tarball/splitting is needed (unlike the xgboost CUDA
candidate).

## Done when

- Both candidate dirs are committed.
- On the PR, the `raco-catalog` jobs for `ubuntu-latest`, `ubuntu-22.04`, and
  `ubuntu-24.04-arm` **run** (no longer "skipped") and pass — confirming a clean
  catalog-style install on Linux.

## Reference

- `scripts/build-so.sh` — the bundler (darwin path already proven).
- `scripts/test-local.sh` — the no-Nix install + test harness.
- `.github/workflows/raco-catalog.yml` — the portability + install checks.
- `scs/private/install-scs-native.rkt` — the pre-install hook that copies a
  candidate into place.
- `scs/native-libs/candidates/darwin/` — a completed candidate to compare against.
