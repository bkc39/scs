#lang racket/base

(require ffi/unsafe
         ffi/unsafe/alloc
         ffi/unsafe/define
         ffi/unsafe/define/conventions
         racket/list
         racket/match
         syntax/parse/define
         (for-syntax ffi/unsafe
                     racket/base
                     racket/string
                     racket/syntax
                     racket/struct-info
                     syntax/stx))

(define-ffi-definer define-scs
  (ffi-lib (build-path "/"
                       "usr"
                       "local"
                       "lib"
                       "libscsdir"))
  #:make-c-id convention:hyphen->underscore)

(define (default-value-for-ctype type)
  (define layout
    (ctype->layout type))
  (define integer-types
    (list 'int8 'uint8 'int16 'uint16 'int32 'uint32 'int64 'uint64))
  (define string-types
    (list 'bytes 'string/ucs-4 'string/utf-16))
  (define pointer-types
    (list 'pointer 'fpointer))
  (cond
    [(member layout integer-types)
     0]
    [(member layout string-types)
     ""]
    [(member layout '(float double))
     0.0]
    [(member layout pointer-types)
     #f]
    [(eq? layout 'bool)
     #f]
    [(eq? layout 'void)
     (error "no default value for void")]
    [else
     (raise-argument-error 'default-value-for-type
                           "unrecognized type layout"
                           type)]))

(define-cstruct _scs-cone
  (;; number of linear equality constraints
   [z _int]
   ;; number of positive orthant cones
   [l _int]
   ;; upper box values
   [bu _pointer]
   ;; lower box values
   [bl _pointer]
   ;; total length of box cone
   [bsize _int]
   ;; array of second-order cone constraints
   [q _pointer]
   ;; length of second order cone array
   [qsize _int]
   ;; array of semidefinite cone constraints
   [s _pointer]
   ;; length of semidefinite constraints array
   [ssize _int]
   ;; number of dual exponential cone triples
   [ep _int]
   ;; number of dual exponential cone triples
   [ed _int]
   ;; array of power cone params
   [p _pointer]
   ;; number of primal and dual power cone triples
   [psize _int])
  #:malloc-mode 'atomic)

(define-cstruct _scs-matrix
  (;; matrix values: size number of non-zeros
   [x _pointer]
   ;; matrix row indices, size number of non-zeros
   [i _pointer]
   ;; matrix column pointers size `n+1`
   [p _pointer]
   ;; number of rows
   [m _int]
   ;; number of columns
   [n _int])
  #:malloc-mode 'atomic)

(define-syntax-parser define/fml
  [(_ nm:id
      (fmls ...)
      (body*:expr ...)
      (key:keyword [fml:id default-val:expr]) rest* ...);
   #'(define/fml nm (fmls ... key [fml default-val]) (body* ...) rest* ...)]
  [(_ nm:id (fmls ...) (body*:expr ...))
   #'(define (nm fmls ...)
       body* ...)])

(begin-for-syntax
  (define (trim-underscore id)
    (string-trim
     (symbol->string
      (syntax-e id))
     "_")))

(define-syntax-parse-rule
  (define-cstruct+kw-constructor id:id ([fld type opt ...] ...) prop ...)
  #:with type-name (datum->syntax #'id (trim-underscore #'id))
  #:with default-constructor-name (format-id #'id "make-~a" #'type-name)
  #:with kw-constructor-name (format-id #'id "new-~a" #'type-name)
  (begin
    (define-cstruct id ([fld type opt ...] ...) prop ...)
    (define/kw-with-type-defaults (kw-constructor-name [fld type] ...)
      (default-constructor-name
        fld
        ...))))


(begin-for-syntax
  (define ((id->keyword stx) field-id)
    (datum->syntax
     stx
     (string->keyword
      (symbol->string (syntax-e field-id))))))

(define-syntax-parse-rule
  (define/kw-with-type-defaults
    (nm:id [fld*:id type] ...) e:expr e*:expr ...)
  #:with (kw* ...) (stx-map (id->keyword #'nm) #'(fld* ...))
  (define/fml
    nm
    ()
    (e e* ...)
    (kw* [fld* (default-value-for-ctype type)])
    ...))

(define-cstruct+kw-constructor _test
  ([A _int]
   [B _size])
  #:malloc-mode 'atomic)

(module+ test
  (define t
    (new-test))
  (check-pred test? t)
  (set! t (new-test #:B 17))
  (check-pred test? t)
  (check-equal? (test-B t) 17)
  (set! t (new-test #:A -42))
  (check-pred test? t)
  (check-equal? (test-A t) -42))

(define-syntax-parse-rule (define/kw (nm:id arg*:id ...) e:expr e*:expr ...)
  #:with (kw* ...) (stx-map (id->keyword #'nm) #'(arg* ...))
  (define/fml nm () (e e* ...) (kw* [arg* #f]) ...))

(define (scs:matrix-alloc nrow ncol nnz)
  (make-scs-matrix
   (malloc 'atomic _double nnz)
   (malloc 'atomic _int nnz)
   (malloc 'atomic _int (+ ncol 1))
   nrow
   ncol))

(define (list->sparse-triple-list ncol xs)
  (define N
    (length xs))
  (for/list ([k (in-range N)]
              [x (in-list xs)]
              #:unless (zero? x))
     (define-values (i j)
       (quotient/remainder k ncol))
     (list i j x)))

(define (triple<? a b)
  (match* (a b)
    [((list i j _) (list u v _))
     (or (< j v)
         (< i u))]
    [(_ _)
     (error "not a triple")]))

(define (scs:matrix n m . xs)
  (apply scs:sparse-matrix
         (append (list n m)
                 (list->sparse-triple-list m xs))))

(define (scs:sparse-matrix n m . value-triples)
  (define nnz
    (length value-triples))
  (define M
    (scs:matrix-alloc n m nnz))

  (for/fold ([current-col 0])
            ([k (in-range nnz)]
             [vt (in-list (sort value-triples triple<?))])
    (match-define (list row col val)
      vt)
    (ptr-set! (scs-matrix-x M)
              _double
              k
              (exact->inexact val))
    (ptr-set! (scs-matrix-i M) _int k row)
    (when (> col current-col)
      (ptr-set! (scs-matrix-p M) _int col k))
    col)
  (ptr-set! (scs-matrix-p M) _int 0 0)
  (ptr-set! (scs-matrix-p M) _int m nnz)

  M)

(define (scs:matrix-p->vector M)
  (define plen
    (+ 1 (scs-matrix-n M)))
  (for/vector #:length plen
              ([idx (in-range plen)])
    (ptr-ref (scs-matrix-p M) _int idx)))

(define (scs:matrix-x->vector M)
  (scs:matrix-nnz-buffer->vector M scs-matrix-x _double))

(define (scs:matrix-nnz M)
  (ptr-ref (scs-matrix-p M)
           _int
           (scs-matrix-n M)))

(define (scs:matrix-nnz-buffer->vector M field-id type)
  (define nnz
    (scs:matrix-nnz M))
  (for/vector #:length nnz
              ([idx (in-range nnz)])
    (ptr-ref (field-id M) type idx)))

(define (scs:matrix-i->vector M)
  (scs:matrix-nnz-buffer->vector M scs-matrix-i _int))


(define (scs:matrix-ref M i j)
  (unless (and (< i (scs-matrix-m M))
               (< j (scs-matrix-n M)))
    (error "scs:matrix-ref - index out of bounds"))
  (or
   (for/first ([idx (in-range (ptr-ref (scs-matrix-p M) _int j)
                              (ptr-ref (scs-matrix-p M) _int (+ j 1)))]
               #:when (= i (ptr-ref (scs-matrix-i M)
                                    _int
                                    idx)))
     (ptr-ref (scs-matrix-x M)
              _double
              idx))
   ;; return 0 if not found in the sparse matrix format
   0.0))

(define-cstruct _scs-data
  (;; A has `m` rows
   [m _int]
   ;; A has `n` cols, P has `n` cols and `n` rows
   [n _int]
   ;; A is supplied in CSC format size `m` x `n`
   [A _scs-matrix-pointer]
   ;; P is supplied in CSC format size `n` x `n`. must be PSD. Only
   ;; pass in upper triangular entries. If `P = 0` then set `P =
   ;; SCS_NULL`
   [P _scs-matrix-pointer]
   ;; dense array for b (size `m`)
   [b _pointer]
   ;; dense array foor c (size `n`)
   [c _pointer])
  #:malloc-mode 'atomic)

(define-cstruct+kw-constructor _scs-settings
  (;; whether to heuristically rescale the data before solve
   [normalize _int]
   ;; initial dual scaling factor
   [scale _double]
   ;; whether to adaptively update `scale`
   [adaptive_scale _int]
   ;; primal constraint scaling factor
   [rho_x _double]
   ;; maximum iterations to take
   [max_iters _int]
   ;; absolute convergence tolerance
   [eps_abs _double]
   ;; relative convergence tolerance
   [eps_rel _double]
   ;; infeasible convergence tolerance
   [eps_infeas _double]
   ;; Doublas-Rachford relaxation parameter
   [alpha _double]
   ;; time limit in secs (can be fractional
   [time_limit_secs _double]
   ;; whether to log progress to stdout
   [verbose _int]
   ;; whether to use warm start (put initial guess in ScsSolution struct
   [warm_start _int]
   ;; memory for acceleration
   [acceleration_lookback _int]
   ;; interval to apply acceleration
   [acceleration_interval _int]
   ;; if set will dump raw prob data to this file
   [write_data_filename _string]
   ;; if set will log data to this csv file (makes SCS slow)
   [log_csv_filename _string])
  #:malloc-mode 'atomic)

(define-scs scs-set-default-settings
  (_fun _scs-settings-pointer -> _void))

(define (make-scs-default-settings)
  (define stgs
    (new-scs-settings))
  (scs-set-default-settings stgs)
  (set-scs-settings-verbose! stgs 0)
  stgs)

(define-cstruct _scs-solution
  (;; primal variable
   [x _pointer]
   ;; dual variable
   [y _pointer]
   ;; slack variable
   [s _pointer])
  #:malloc-mode 'atomic)

(define (scs:solution m)
  (make-scs-solution
   (malloc 'atomic _double m)
   (malloc 'atomic _double m)
   (malloc 'atomic _double m)))

(define-cstruct+kw-constructor _scs-info
  (;; number of iterations taken
   [iter _int]
   ;; status string
   [status (_array _byte 128)]
   ;; linear system solver used
   [lin_sys_solver (_array _byte 128)]
   ;; status as scs_int
   [status_val _int]
   ;; number of updates to scale
   [scale_updates _int]
   ;; primal objective value
   [pobj _double]
   ;; dual objective value
   [dobj _double]
   ;; primal equality residual
   [res_pri _double]
   ;; dual equality residual
   [res_dual _double]
   ;; duality gap
   [gap _double]
   ;; infeasibility cert residual
   [res_infeas _double]
   ;; unbounded cert residual
   [res_unbdd_a _double]
   ;; unbounded cert residual
   [res_unbdd_p _double]
   ;; time taken for setup phase (ms)
   [setup_time _double]
   ;; time taken for solve (ms)
   [solve_time _double]
   ;; final scale parameter
   [scale _double]
   ;; complementary slackness
   [comp_slack _double]
   ;; number of rejected AA steps
   [rejected_accel_steps _int]
   ;; number of rejected AA steps
   [accepted_accel_steps _int]
   ;; total time (ms) spent in the linear solver
   [lin_sys_time _double]
   ;; total time (ms) spent in the cone projection
   [cone_time _double]
   ;; total time (ms) spend in the acceleration routine
   [accel_time _double])
  #:malloc-mode 'atomic)

(define (make-scs-info/tmp status lin-sys-solver)
  (new-scs-info
   #:status status
   #:lin_sys_solver lin-sys-solver))

(define _scs-work-pointer (_cpointer 'SCS_WORK))

(define-scs scs-finish
  (_fun _scs-work-pointer
        -> _void)
  #:wrap (deallocator))

(define-scs scs-init
  (_fun _scs-data-pointer
        _scs-cone-pointer
        _scs-settings-pointer
        -> _scs-work-pointer)
  #:wrap (allocator scs-finish))

(define-scs scs-solve
  (_fun _scs-work-pointer
        _scs-solution-pointer
        _scs-info-pointer
        _int
        -> _int))

(module+ test
  (require rackunit)

  (define (vector->cptr v)
    (define ptr
      (malloc 'atomic _double (vector-length v)))

    (for ([val (in-vector v)]
          [idx (in-naturals)])
      (ptr-set! ptr _double idx (exact->inexact val)))
    ptr)

  (define (cptr/len->vector cptr len)
    (for/vector #:length len
                ([idx (in-range len)])
      (ptr-ref cptr _double idx)))

  (define-check (check-near/vector? x y tol)
    (unless (= (vector-length x)
               (vector-length y))
      (fail-check))

    (<
     (for/sum ([xi (in-vector x)]
               [yi (in-vector y)]
               #:do [(define d (- xi yi))])
       (* d d))
     tol))

  (check-pred cpointer?
              (vector->cptr #(1 2 3)))

  ;; 2 variables 3 constraints
  (define-values (example-m example-n)
    (values 2 3))

  ;; linear constraints
  (define A
    (scs:matrix 3 2
                ;; ---
                -1 1
                 1 0
                 0 1))

  (check-equal? (scs-matrix-m A) 3)
  (check-equal? (scs-matrix-n A) 2)

  (check-equal? (scs:matrix-p->vector A)
                #(0 2 4))
  (check-equal? #(-1.0 1.0 1.0 1.0)
                (scs:matrix-x->vector A))
  (check-equal? #(0 1 0 2)
                (scs:matrix-i->vector A))
  (check-equal? (scs:matrix-ref A 1 0)
                1.0)
  (check-equal? (scs:matrix-ref A 1 1)
                0.0)
  (check-equal? (scs:matrix-ref A 2 0)
                0.0)

  ;; quadratic in objective -- upper triangle only
  (define P
    (scs:sparse-matrix
     example-m example-m
     '(0 0 3)
     '(0 1 -1)
     '(1 1 2)))

  (check-equal? (scs:matrix-ref P 0 0)
                3.0)
  (check-equal? (scs:matrix-ref P 1 0)
                0.0)

  ;; RHS for Ax <= b linear constraints
  (define b
    (vector->cptr #(-1.0 0.3 -0.5)))
  ;; linear coefficient term in objective
  (define c
    (vector->cptr #(-1 -1)))

  (define d
    (make-scs-data
     3
     2
     A
     P
     b
     c))

  (define k
    (make-scs-cone
     1
     2
     #f
     #f
     0
     #f
     0
     #f
     0
     0
     0
     #f
     0))

  (define stgs
    (make-scs-default-settings))
  (set-scs-settings-eps_abs! stgs 1e-9)
  (set-scs-settings-eps_rel! stgs 1e-9)

  (check-equal? (scs-settings-verbose stgs) 0)

  (define workspace
    (scs-init d k stgs))

  (define solution
    (scs:solution example-m))
  (define _info-str
    (_array _byte 128))
  (define status-ptr
    (malloc 'atomic _info-str))
  (define lin-sys-solver-ptr
    (malloc 'atomic _info-str))
  (define info
    (make-scs-info/tmp
     (ptr-ref status-ptr _info-str 0)
     (ptr-ref lin-sys-solver-ptr _info-str 0)))

  (define exit-flag
    (scs-solve workspace solution info 0))
  (check-equal? exit-flag 1)
  (check-near/vector? (cptr/len->vector (scs-solution-x solution)
                                  2)
                      #(0.3 -0.7)
                      1e-9))
