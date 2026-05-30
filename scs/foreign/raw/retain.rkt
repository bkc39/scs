#lang racket/base

;; Keep FFI backing buffers alive for as long as the struct that points at them.
;;
;; A cstruct stores the *raw address* of each pointer field; that address is not
;; a GC root, so the GC-managed (atomic-interior) buffers a struct points at
;; could be collected while the struct is still live.  `retain!` records the
;; backing values in a weak-key table keyed by the owning struct: the buffers
;; stay reachable exactly as long as the owner is, and become collectible once
;; the owner does.

(provide retain!)

(define retained (make-weak-hasheq))

;; (retain! owner buf ...) -> owner
(define (retain! owner . things)
  (hash-set! retained owner things)
  owner)
