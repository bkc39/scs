#lang racket/base

;; raco review does surface-level linting without macro expansion; it would
;; misreport the re-exports below.  The contracts are the only value-add here.
#|review: ignore|#

;; Facade for the safe, contracted low-level layer.  `(require scs/foreign)`
;; re-exports the cstructs and type aliases from the raw layer and wraps the
;; solver entry points with contracts.  The workspace returned by scs-init is
;; GC-reclaimed (the raw layer wires allocator/deallocator), so the safe surface
;; does not export scs-finish; `(require (submod scs/foreign unsafe))` exposes it
;; for callers needing deterministic release.

(require racket/contract/base
         (only-in ffi/unsafe cpointer?)
         "foreign/raw/library.rkt"
         "foreign/raw/kw-struct.rkt"
         "foreign/raw/retain.rkt"
         "foreign/raw/structs.rkt"
         "foreign/raw/solver.rkt")

(provide (all-from-out "foreign/raw/library.rkt")
         (all-from-out "foreign/raw/kw-struct.rkt")
         (all-from-out "foreign/raw/retain.rkt")
         (all-from-out "foreign/raw/structs.rkt")
         _scs-work-pointer
         scs-version
         scs-set-default-settings
         (contract-out
          [scs-init
           (-> scs-data? scs-cone? scs-settings? cpointer?)]
          [scs-solve
           (-> cpointer? scs-solution? scs-info? exact-integer? exact-integer?)]
          [scs-update
           (-> cpointer? cpointer? cpointer? exact-integer?)]
          [scs-init/indirect
           (-> scs-data? scs-cone? scs-settings? cpointer?)]
          [scs-solve/indirect
           (-> cpointer? scs-solution? scs-info? exact-integer? exact-integer?)]
          [scs-update/indirect
           (-> cpointer? cpointer? cpointer? exact-integer?)]))

(module+ unsafe
  (provide scs-finish
           scs-finish/indirect))
