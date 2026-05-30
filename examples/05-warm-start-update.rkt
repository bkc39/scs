#lang racket/base

;; 05 - Warm starting with scs_update (foreign layer).
;;
;; Reuse a single solver workspace across two solves of the LP from example 01,
;; changing only the right-hand side b between them.  scs-update swaps the
;; workspace's b/c in place; the second scs-solve is warm started (warm = 1) from
;; the previous solution.
;;
;;   x0 <= b0, x1 <= b1, x0 >= 0, x1 >= 0,  maximize x0 + x1  =>  x = (b0, b1)
;;
;; First b = (1, 1) -> x = (1, 1); after update b = (2, 3) -> x = (2, 3).

(require ffi/unsafe
         scs
         scs/foreign)

(provide run-example)

(define info-str-type (_array _byte 128))

(define (make-info)
  (new-scs-info
   #:status (ptr-ref (malloc 'atomic info-str-type) info-str-type 0)
   #:lin_sys_solver (ptr-ref (malloc 'atomic info-str-type) info-str-type 0)))

(define (run-example)
  (define A
    (scs:matrix 4 2
                ;; ---
                1 0
                0 1
                -1 0
                0 -1))
  (define c (vector->scs-float-ptr #(-1.0 -1.0)))
  (define b1 (vector->scs-float-ptr #(1.0 1.0 0.0 0.0)))
  (define data (make-scs-data 4 2 A #f b1 c))
  (define cone (make-cone #:positive 4))
  (define stgs (make-settings #:eps-abs 1e-9 #:eps-rel 1e-9))
  (define work (scs-init data cone stgs))
  (define sol
    (make-scs-solution (malloc 'atomic _scs-float 2)
                       (malloc 'atomic _scs-float 4)
                       (malloc 'atomic _scs-float 4)))
  (define info (make-info))

  (define flag1 (scs-solve work sol info 0))
  (define x1 (scs-float-ptr->vector (scs-solution-x sol) 2))

  ;; Change the bounds to b = (2, 3) and re-solve, warm started.
  (define b2 (vector->scs-float-ptr #(2.0 3.0 0.0 0.0)))
  (scs-update work b2 c)
  (define flag2 (scs-solve work sol info 1))
  (define x2 (scs-float-ptr->vector (scs-solution-x sol) 2))

  (list (list flag1 x1) (list flag2 x2)))

(module+ main
  (for ([step (in-list (run-example))]
        [label (in-list '("initial" "after update"))])
    (printf "~a: flag=~a x=~a\n" label (car step) (cadr step))))

(module+ test
  (require rackunit)
  (define steps (run-example))
  (define first-step (car steps))
  (define second-step (cadr steps))
  (check-equal? (car first-step) 1)
  (check-= (vector-ref (cadr first-step) 0) 1.0 1e-6)
  (check-= (vector-ref (cadr first-step) 1) 1.0 1e-6)
  (check-equal? (car second-step) 1)
  (check-= (vector-ref (cadr second-step) 0) 2.0 1e-6)
  (check-= (vector-ref (cadr second-step) 1) 3.0 1e-6))
