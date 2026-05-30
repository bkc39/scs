# AGENTS.md

## Project Overview

This repository provides Racket bindings for [SCS](https://github.com/cvxgrp/scs),
the Splitting Conic Solver. The Racket package is the `scs` collection (under
`scs/`):

- `(require scs)` is the high-level API for ordinary Racket data (vectors,
  lists, the CSC matrix builders). **Use this by default.** The solver
  workspace is reclaimed by Racket's GC; user code never calls `scs-finish`.
- `(require scs/foreign)` is the contracted low-level wrapper layer. It exposes
  the SCS cstructs and a workspace whose handle is GC-reclaimed via
  `(allocator … (deallocator))`.
- `(require scs/foreign/raw)` is the direct C FFI layer (`define-ffi-definer`
  bindings to the SCS C API).

Unlike the sibling `xgboost` project, **SCS is pure C with a small, stable C
API**, so there is **no hand-written C/C++ shim** — we bind the SCS C API
directly. The native library comes from `nixpkgs#scs` (currently 3.2.11, built
with LAPACK, shipping both `libscsdir` (direct) and `libscsindir` (indirect)).

## Build Commands

```bash
nix build            # build the package, run raco test + fast examples
nix develop          # dev shell with racket + scs + linters + python-scs
```

Inside `nix develop`:

```bash
raco test scs/
racket examples/00-quadratic-program.rkt

# Linters (provisioned into the user scope on first shell entry):
resyntax analyze --directory scs       # report refactoring suggestions
resyntax fix --directory scs           # apply them in place
raco review scs/**/*.rkt               # surface-level lint
```

Note: `raco review` does not expand macros, so the pure re-export facades
(`main.rkt`, `foreign.rkt`, `foreign/raw.rkt`) and `info.rkt` carry a
`#|review: ignore|#` directive — every `contract-out` re-export would
otherwise be misreported as "provided but not defined".

The `Nix checks` workflow runs `resyntax analyze` as a CI gate, so run
`resyntax fix` before pushing.

## Native library / portability

`scripts/build-so.sh` stages the SCS native libraries (and their BLAS/LAPACK/
gfortran/OpenMP closure) under `scs/native-libs/candidates/<platform>/` with
`$ORIGIN` rpaths so a plain `raco pkg install` works without Nix:

```bash
./scripts/build-so.sh darwin         # → candidates/darwin/
./scripts/build-so.sh linux          # → candidates/linux-cpu/
raco pkg install --name scs ./scs    # pre-installer picks the right candidate
```

The pre-install hook `scs/private/install-scs-native.rkt` copies the chosen
candidate's libraries into `scs/native-libs/` at install time. In Nix builds it
instead copies from `$SCS_NATIVE_LIB_PATH/lib`.

## Architecture (Racket)

Every top-level module path is a thin *re-export facade*; the implementation
lives in sub-collection modules (target ≤ 500 lines/file).

- `scs/info.rkt` — package metadata and native-library pre-install hook.
- `scs/main.rkt` — facade for the high-level API; re-exports `core/*`.
- `scs/core/*.rkt` — high-level implementation: `matrix` (CSC builders),
  `cone`, `settings`, `solve`.
- `scs/foreign.rkt` — facade for the safe contracted layer.
- `scs/foreign/raw.rkt` — facade for the direct C FFI layer; re-exports
  `foreign/raw/{library,kw-struct,structs,solver}.rkt`.
- `scs/private/install-scs-native.rkt` — native-library pre-install hook.
- `scs/tests/*.rkt` — cross-cutting integration tests; module-local unit tests
  live in `module+ test` submodules.
- `examples/NN-*.rkt` — numbered runnable examples; each exports `run-example`,
  prints concise output from `module+ main`, and verifies behavior from
  `module+ test`.

The dev shell also provides `python3` with `scs`, `numpy`, and `scipy` so the
reference Python SCS implementation can cross-validate our results
(`scripts/reference.py`).

Every new public API or user-visible feature should include an example-backed
E2E test in the same change set unless that is impractical.

## SCS C API surface

The bound public C API: `scs_init`, `scs_update`, `scs_solve`, `scs_finish`,
`scs_set_default_settings`, `scs_version`. `scs_int` is 32-bit `int` in the
nixpkgs build (no `DLONG`); `scs_float` is `double`. The FFI uses an `_scs-int`
ctype alias (= `_int`) so a future `DLONG` build is a one-line change.
