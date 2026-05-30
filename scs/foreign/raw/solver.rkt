#lang racket/base

;; FFI bindings to the SCS public C API entry points.
;;
;; The direct (libscsdir) and indirect (libscsindir) builds export the same
;; symbols, so the indirect bindings use #:c-id to map back to the real C name.
;; scs-init wraps the workspace with (allocator … (deallocator)) so scs-finish
;; runs automatically when the workspace is collected.

(require ffi/unsafe
         ffi/unsafe/alloc
         "library.rkt"
         "structs.rkt")

(provide (all-defined-out))

;; Opaque solver workspace handle (struct SCS_WORK).
(define _scs-work-pointer (_cpointer 'SCS_WORK))

;; const char *scs_version(void);
(define-scs scs-version
  (_fun -> _string))

;; void scs_set_default_settings(ScsSettings *stgs);
(define-scs scs-set-default-settings
  (_fun _scs-settings-pointer -> _void))

;; --- direct solver (libscsdir) ---

;; void scs_finish(ScsWork *w);
(define-scs scs-finish
  (_fun _scs-work-pointer -> _void)
  #:wrap (deallocator))

;; ScsWork *scs_init(const ScsData *d, const ScsCone *k, const ScsSettings *s);
(define-scs scs-init
  (_fun _scs-data-pointer
        _scs-cone-pointer
        _scs-settings-pointer
        -> _scs-work-pointer)
  #:wrap (allocator scs-finish))

;; scs_int scs_solve(ScsWork *w, ScsSolution *sol, ScsInfo *info, scs_int warm);
(define-scs scs-solve
  (_fun _scs-work-pointer
        _scs-solution-pointer
        _scs-info-pointer
        _scs-int
        -> _scs-int))

;; scs_int scs_update(ScsWork *w, scs_float *b, scs_float *c);
(define-scs scs-update
  (_fun _scs-work-pointer
        _pointer
        _pointer
        -> _scs-int))

;; --- indirect solver (libscsindir): same C symbols, distinct Racket names ---

(define-scs-indirect scs-finish/indirect
  (_fun _scs-work-pointer -> _void)
  #:c-id scs_finish
  #:wrap (deallocator))

(define-scs-indirect scs-init/indirect
  (_fun _scs-data-pointer
        _scs-cone-pointer
        _scs-settings-pointer
        -> _scs-work-pointer)
  #:c-id scs_init
  #:wrap (allocator scs-finish/indirect))

(define-scs-indirect scs-solve/indirect
  (_fun _scs-work-pointer
        _scs-solution-pointer
        _scs-info-pointer
        _scs-int
        -> _scs-int)
  #:c-id scs_solve)

(define-scs-indirect scs-update/indirect
  (_fun _scs-work-pointer
        _pointer
        _pointer
        -> _scs-int)
  #:c-id scs_update)
