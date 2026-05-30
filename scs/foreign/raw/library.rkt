#lang racket/base

;; Native library handles and the FFI definers shared by the raw layer.
;;
;; nixpkgs#scs ships two builds that export the same C API but use different
;; linear-system solvers: libscsdir (direct) and libscsindir (indirect/CG).  We
;; load both; `define-scs` binds against the direct solver and
;; `define-scs-indirect` against the indirect one.
;;
;; `native-libs-dir` is resolved relative to this file, which lives at
;; scs/foreign/raw/ — two directories below the collection root — so the path to
;; scs/native-libs/ climbs two levels.  In Nix builds SCS_NATIVE_LIB_PATH points
;; at the scs derivation, whose libraries live under lib/.

(require ffi/unsafe
         ffi/unsafe/define
         ffi/unsafe/define/conventions
         racket/runtime-path)

(provide define-scs
         define-scs-indirect
         _scs-int
         _scs-float)

;; scs_int is 32-bit `int` in the nixpkgs build (no DLONG); scs_float is double.
;; Aliasing here makes a future DLONG/SFLOAT build a one-line change.
(define _scs-int _int)
(define _scs-float _double)

(define-runtime-path native-libs-dir "../../native-libs")

(define (scs-lib-dir)
  (define env (getenv "SCS_NATIVE_LIB_PATH"))
  (if env (build-path env "lib") native-libs-dir))

(define libscsdir (ffi-lib (build-path (scs-lib-dir) "libscsdir")))
(define libscsindir (ffi-lib (build-path (scs-lib-dir) "libscsindir")))

(define-ffi-definer define-scs libscsdir
  #:make-c-id convention:hyphen->underscore)

(define-ffi-definer define-scs-indirect libscsindir
  #:make-c-id convention:hyphen->underscore)
