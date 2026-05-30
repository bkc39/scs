#lang racket/base

;; 04 - Exponential cone.
;;
;;   minimize  z   subject to  (x, y, z) in K_exp,  x = 1,  y = 1
;;
;; K_exp = closure of {(x, y, z) : y e^{x/y} <= z, y > 0}.  With x = y = 1 the
;; cone forces z >= e^1, so the optimum is z = e ~ 2.71828.
;;
;; Variables x = (x, y, z); x and y are pinned by equalities and the exp-cone
;; block (A = -I, b = 0) puts the slack (x, y, z) into K_exp.

(require scs)

(provide run-example)

(define (run-example)
  (define A
    (scs:matrix 5 3
                ;; equality: x = 1, y = 1
                1 0 0
                0 1 0
                ;; exp-cone block: s = (x, y, z)
                -1 0 0
                0 -1 0
                0 0 -1))
  (solve #:A A
         #:b #(1.0 1.0 0.0 0.0 0.0)
         #:c #(0.0 0.0 1.0)
         #:cone (make-cone #:zero 2 #:exp-primal 1)
         #:settings (make-settings #:eps-abs 1e-9 #:eps-rel 1e-9)))

(module+ main
  (define r (run-example))
  (printf "status: ~a\n" (scs-result-status r))
  (printf "x (x y z): ~a\n" (scs-result-x r))
  (printf "z vs e:    ~a vs ~a\n" (vector-ref (scs-result-x r) 2) (exp 1)))

(module+ test
  (require rackunit)
  (define r (run-example))
  (check-true (solved? r))
  (check-= (vector-ref (scs-result-x r) 2) (exp 1) 1e-4))
