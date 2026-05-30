#lang racket/base

;; Pre-install hook (declared by info.rkt as `pre-install-collection`).
;;
;; Populates scs/native-libs/ with the SCS shared libraries (and their
;; BLAS/LAPACK/gfortran/OpenMP runtime closure) so the FFI loader in
;; foreign/raw/library.rkt can find them.  Three sources, in priority order:
;;
;;   1. Nix build: SCS_NATIVE_LIB_PATH points at the scs derivation; copy from
;;      its lib/ subdirectory.
;;   2. Already staged: native-libs/ already holds libscsdir.*; nothing to do.
;;   3. Catalog install: copy from native-libs/candidates/<platform>/, which
;;      scripts/build-so.sh stages with portable ($ORIGIN / @loader_path) rpaths.

(provide pre-installer)

(require racket/file)

(define (copy-native-libs! dest-dir source-dir pattern)
  (make-directory* dest-dir)
  (for ([f (in-list (directory-list source-dir))]
        #:when (regexp-match? pattern (path->string f)))
    (define src (build-path source-dir f))
    (define dst (build-path dest-dir f))
    (when (or (file-exists? dst) (link-exists? dst))
      (delete-file dst))
    (copy-file src dst)))

(define (has-matching-files? dir pattern)
  (and (directory-exists? dir)
       (pair? (filter (lambda (f) (regexp-match? pattern (path->string f)))
                      (directory-list dir)))))

;; Candidate directory name for the running platform.
(define (candidate-name)
  (case (system-type 'os)
    [(macosx) "darwin"]
    [(unix)
     (if (regexp-match? #rx"aarch64|arm" (path->string (system-library-subpath #f)))
         "linux-aarch64"
         "linux-cpu")]
    [else #f]))

(define (pre-installer _collections-top-path this-collection-path _user-specific?)
  (define native-libs-dir (build-path this-collection-path "native-libs"))
  (define candidates-base (build-path native-libs-dir "candidates"))
  (define env-lib-path (getenv "SCS_NATIVE_LIB_PATH"))
  ;; Copy every bundled shared library (matches lib*.dylib / lib*.so / .so.N,
  ;; and versioned names like libgfortran.5.dylib; skips static .a archives).
  ;; The candidate directory holds the SCS solvers plus their full runtime
  ;; closure (BLAS/LAPACK/gfortran/quadmath/gettext/iconv on macOS;
  ;; openblas/gfortran/quadmath/gomp/gcc_s on Linux), so we take all of them.
  (define pattern #rx"^lib.*\\.(dylib|so)($|\\.)")
  (define installed-pattern #rx"^libscsdir\\.(dylib|so)")
  (cond
    [env-lib-path
     (copy-native-libs! native-libs-dir (build-path env-lib-path "lib") pattern)]
    [(has-matching-files? native-libs-dir installed-pattern)
     (void)]
    [else
     (define name (candidate-name))
     (define dir (and name (build-path candidates-base name)))
     (unless (and dir (has-matching-files? dir installed-pattern))
       (error
        'pre-installer
        (string-append
         "SCS native library not found. Either:\n"
         "  1. Run: ./scripts/build-so.sh darwin|linux, then raco pkg install\n"
         "  2. Set SCS_NATIVE_LIB_PATH to a dir containing lib/libscsdir.*\n"
         "  3. Copy libscsdir.* manually to ~a")
        (path->string native-libs-dir)))
     (copy-native-libs! native-libs-dir dir pattern)]))
