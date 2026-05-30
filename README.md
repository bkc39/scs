# scs

Racket bindings for [SCS](https://github.com/cvxgrp/scs), the Splitting Conic
Solver, built with Nix. SCS solves convex cone programs of the form

```
minimize    (1/2) xᵀP x + cᵀx
subject to  A x + s = b,  s ∈ K
```

where `K` is a Cartesian product of zero, positive-orthant, box, second-order,
semidefinite, exponential, and power cones.

The default API is high level:

```racket
#lang racket

(require scs)

;; minimize (1/2) xᵀP x + cᵀx
;;   s.t.  -x0 + x1 = -1,  x0 <= 0.3,  x1 <= -0.5
(define A
  (scs:matrix 3 2
              -1 1
               1 0
               0 1))

(define P
  (scs:sparse-matrix 2 2
                     '(0 0 3)
                     '(0 1 -1)
                     '(1 1 2)))

(define result
  (solve #:A A
         #:b #(-1.0 0.3 -0.5)
         #:c #(-1.0 -1.0)
         #:P P
         #:cone (make-cone #:zero 1 #:positive 2)))

(scs-result-status result)   ; => "solved"
(scs-result-x result)        ; => #(0.3 -0.7)
```

Use `(require scs/foreign)` for the contracted low-level wrappers, and
`(require scs/foreign/raw)` for the direct C FFI bindings.

Full documentation — a Guide, worked Examples, and an API Reference — is in the
package's Scribble docs (`scs/scribblings/`, hosted on docs.racket-lang.org);
render them locally with `raco scribble scs/scribblings/scs.scrbl` or
`raco docs scs`.

## Quick start

```bash
nix build              # build, run tests + examples
nix develop            # dev shell: racket + scs + python(scs) + linters
racket examples/00-quadratic-program.rkt
```

## Layout

- `scs/main.rkt` — high-level root API for `(require scs)`.
- `scs/foreign.rkt` — contracted low-level Racket wrappers.
- `scs/foreign/raw.rkt` — direct C FFI bindings to the SCS C API.
- `scs/core/` — high-level implementation: `matrix`, `cone`, `settings`, `solve`.
- `scs/private/install-scs-native.rkt` — native-library pre-install hook.
- `examples/` — numbered runnable examples (each with `module+ main` and
  `module+ test`).
- `flake.nix` — Nix build; uses `nixpkgs#scs` (3.2.11, both solver variants,
  LAPACK).

See `AGENTS.md` for architecture notes.
