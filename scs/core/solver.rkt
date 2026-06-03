#lang racket/base

;; High-level solver object and the `scs-result` struct, documented in the scs
;; Scribble reference.  A `scs-solver` owns the SCS workspace, the solution and
;; info buffers, and the problem data, so user code never allocates or frees
;; native memory.  `solve` (solve.rkt) is a thin one-shot wrapper over this.
;;
;; The workspace is GC-reclaimed (scs-init is wrapped with a finalizer); holding
;; the solver alive keeps the workspace and the retained data/buffers alive.

(require ffi/unsafe
         racket/format
         racket/string
         "../foreign/raw/library.rkt"
         "../foreign/raw/retain.rkt"
         "../foreign/raw/solver.rkt"
         "../foreign/raw/structs.rkt"
         "matrix.rkt"
         "settings.rkt")

(provide (struct-out scs-result)
         solved?
         infeasible?
         unbounded?
         result-objective
         result-status
         scs-solver?
         make-solver
         solver-solve!
         solver-update!)

;; SCS exit flags (subset; see SCS's glbopts.h).  scs-result-exit-flag carries
;; one of these.
(define SCS-SOLVED 1)
(define SCS-UNBOUNDED -1)
(define SCS-INFEASIBLE -2)

;; At most this many entries of x are shown in a result's one-line summary.
(define max-x-shown 6)

;; A one-line, human-readable summary, e.g.
;;   #<scs-result solved pobj=1.0000 iter=60 x=#(1.0 1.0)>
(define (summarize-x x)
  (define n (vector-length x))
  (cond
    [(<= n max-x-shown)
     (format "#(~a)" (string-join (map ~a (vector->list x)) " "))]
    [else
     (define shown
       (for/list ([i (in-range max-x-shown)]) (~a (vector-ref x i))))
     (format "#(~a ... ~a more)"
             (string-join shown " ") (- n max-x-shown))]))

(struct scs-result
  (exit-flag status status-val x y s pobj dobj gap iter solve-time setup-time)
  #:transparent
  #:methods gen:custom-write
  [(define (write-proc r port _mode)
     (fprintf port "#<scs-result ~a pobj=~a iter=~a x=~a>"
              (scs-result-status r)
              (~r (scs-result-pobj r) #:precision 4)
              (scs-result-iter r)
              (summarize-x (scs-result-x r))))])

;; SCS returns 1 (SCS_SOLVED) on success.
(define (solved? r)
  (= (scs-result-exit-flag r) SCS-SOLVED))

;; The problem was proven primal-infeasible / unbounded.
(define (infeasible? r)
  (= (scs-result-exit-flag r) SCS-INFEASIBLE))

(define (unbounded? r)
  (= (scs-result-exit-flag r) SCS-UNBOUNDED))

;; The primal objective value (cvxpy's prob.value); an alias for readability.
(define (result-objective r)
  (scs-result-pobj r))

;; The human-readable status string, e.g. "solved".
(define (result-status r)
  (scs-result-status r))

;; A live solver.  `run`/`upd` are the direct or indirect C entry points; `data`
;; (and through it A, P, and the b/c buffers) is retained so it outlives the
;; workspace.  `b`/`c` track the current right-hand side / objective pointers so
;; an update can leave one side unchanged; `warm?` flips to #t after the first
;; solve so subsequent solves warm start.
(struct scs-solver
  (work sol info m n run upd data [b #:mutable] [c #:mutable] [warm? #:mutable]))

(define info-str-type (_array _byte 128))

;; Read a NUL-terminated C char[128] field into a Racket string.
(define (status-array->string arr)
  (define bs
    (let loop ([i 0] [acc '()])
      (cond
        [(>= i 128) (reverse acc)]
        [else
         (define b (array-ref arr i))
         (if (zero? b) (reverse acc) (loop (add1 i) (cons b acc)))])))
  (bytes->string/utf-8 (list->bytes bs)))

;; ScsInfo's status / lin_sys_solver are char[128]; new-scs-info cannot default
;; an array field, so seed them with zeroed buffers SCS will overwrite.
(define (make-info)
  (define status-ptr (malloc 'atomic-interior info-str-type))
  (define lin-ptr (malloc 'atomic-interior info-str-type))
  (new-scs-info #:status (ptr-ref status-ptr info-str-type 0)
                #:lin_sys_solver (ptr-ref lin-ptr info-str-type 0)))

;; x has length n (variables); y and s have length m (constraints).  The
;; solution struct retains its arrays so they outlive it.
(define (make-solution m n)
  (define x (malloc 'atomic-interior _scs-float n))
  (define y (malloc 'atomic-interior _scs-float m))
  (define s (malloc 'atomic-interior _scs-float m))
  (retain! (make-scs-solution x y s) x y s))

;; Turn the filled-in info/solution buffers into an scs-result.
(define (build-result info sol m n flag)
  (scs-result
   flag
   (status-array->string (scs-info-status info))
   (scs-info-status_val info)
   (float-ptr->vector (scs-solution-x sol) n)
   (float-ptr->vector (scs-solution-y sol) m)
   (float-ptr->vector (scs-solution-s sol) m)
   (scs-info-pobj info)
   (scs-info-dobj info)
   (scs-info-gap info)
   (scs-info-iter info)
   (scs-info-solve_time info)
   (scs-info-setup_time info)))

;; Build a solver for minimize (1/2) x'Px + c'x s.t. Ax + s = b, s in cone.
;; Allocates and retains everything internally; no user malloc.  See the scs
;; Scribble reference for the keyword arguments.
(define (make-solver #:A A
                     #:b b
                     #:c c
                     #:cone cone
                     #:P [P #f]
                     #:settings [settings #f]
                     #:indirect? [indirect? #f])
  (define m (scs-matrix-m A))   ; rows of A: number of constraints
  (define n (scs-matrix-n A))   ; cols of A: number of variables
  (define b-ptr (vector->float-ptr b))
  (define c-ptr (vector->float-ptr c))
  ;; retain A, P, and the b/c buffers for the lifetime of the data struct
  (define data (retain! (make-scs-data m n A P b-ptr c-ptr) A P b-ptr c-ptr))
  (define stgs (or settings (make-settings)))
  (define init (if indirect? scs-init/indirect scs-init))
  (define run (if indirect? scs-solve/indirect scs-solve))
  (define upd (if indirect? scs-update/indirect scs-update))
  (define work (init data cone stgs))
  (scs-solver work (make-solution m n) (make-info) m n run upd data
              b-ptr c-ptr #f))

;; Solve (or re-solve) with the current data.  `warm` defaults to a cold start
;; on the first solve and a warm start (reusing the previous iterate) on every
;; solve after that; pass #:warm-start 0/1 to force it.
(define (solver-solve! s #:warm-start [warm #f])
  (define flag
    ((scs-solver-run s)
     (scs-solver-work s) (scs-solver-sol s) (scs-solver-info s)
     (cond [(integer? warm) warm]
           [(scs-solver-warm? s) 1]
           [else 0])))
  (set-scs-solver-warm?! s #t)
  (build-result (scs-solver-info s) (scs-solver-sol s)
                (scs-solver-m s) (scs-solver-n s) flag))

;; Update the right-hand side b and/or the objective c in place, for a cheap
;; warm-started re-solve.  Only b/c can change (not A, P, or the cone).  b/c are
;; plain vectors or lists; an omitted side keeps its current value.
(define (solver-update! s #:b [b #f] #:c [c #f])
  (define b-ptr
    (cond [b (define p (vector->float-ptr b)) (set-scs-solver-b! s p) p]
          [else (scs-solver-b s)]))
  (define c-ptr
    (cond [c (define p (vector->float-ptr c)) (set-scs-solver-c! s p) p]
          [else (scs-solver-c s)]))
  ;; keep the new buffers alive as long as the solver (hence the workspace)
  (retain! s b-ptr c-ptr)
  ((scs-solver-upd s) (scs-solver-work s) b-ptr c-ptr)
  (void))

(module+ test
  (require rackunit
           "cone.rkt")

  ;; LP from example 01/08: maximize x0+x1 s.t. x_i in [0, b_i].
  (define A (matrix 4 2  1 0  0 1  -1 0  0 -1))
  (define s
    (make-solver #:A A
                 #:b #(1.0 1.0 0.0 0.0)
                 #:c #(-1.0 -1.0)
                 #:cone (make-cone #:positive 4)
                 #:settings (make-settings #:eps-abs 1e-9 #:eps-rel 1e-9)))

  ;; cold solve -> x = (1, 1)
  (define r1 (solver-solve! s))
  (check-true (solved? r1))
  (check-false (infeasible? r1))
  (check-false (unbounded? r1))
  (check-= (vector-ref (scs-result-x r1) 0) 1.0 1e-6)
  (check-= (vector-ref (scs-result-x r1) 1) 1.0 1e-6)

  ;; ergonomics: aliases and a readable one-line summary
  (check-equal? (result-objective r1) (scs-result-pobj r1))
  (check-equal? (result-status r1) (scs-result-status r1))
  (let ([printed (format "~a" r1)])
    (check-regexp-match #rx"scs-result" printed)
    (check-regexp-match (regexp (regexp-quote (scs-result-status r1))) printed)
    (check-regexp-match #rx"pobj=" printed))

  ;; update only b, warm re-solve -> x = (2, 3)
  (solver-update! s #:b #(2.0 3.0 0.0 0.0))
  (define r2 (solver-solve! s))
  (check-true (solved? r2))
  (check-= (vector-ref (scs-result-x r2) 0) 2.0 1e-6)
  (check-= (vector-ref (scs-result-x r2) 1) 3.0 1e-6))
