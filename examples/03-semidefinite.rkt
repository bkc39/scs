#lang racket/base

;; 03 - Semidefinite program (requires the LAPACK-enabled SCS build).
;;
;; Over symmetric 2x2 matrices X = [[a b] [b c]]:
;;
;;   minimize  trace(X) = a + c   subject to  X >= 0 (PSD),  b = 1
;;
;; X PSD with b = 1 forces a*c >= 1, so a + c >= 2 with equality at a = c = 1.
;; Optimal (a, b, c) = (1, 1, 1).
;;
;; SCS's PSD cone takes the lower-triangle scaled vectorization
;; svec(X) = (a, sqrt(2)*b, c); the cone block A = -diag(1, sqrt(2), 1) makes the
;; slack equal that vector.

(require scs)

(provide run-example)

(define root2 (sqrt 2.0))

(define (run-example)
  (define A
    (scs:matrix 4 3
                ;; equality: b = 1
                0 1 0
                ;; psd block svec = (a, sqrt(2) b, c)
                -1 0 0
                0 (- root2) 0
                0 0 -1))
  (solve #:A A
         #:b #(1.0 0.0 0.0 0.0)
         #:c #(1.0 0.0 1.0)
         #:cone (make-cone #:zero 1 #:psd '(2))
         #:settings (make-settings #:eps-abs 1e-9 #:eps-rel 1e-9)))

(module+ main
  (define r (run-example))
  (printf "status: ~a\n" (scs-result-status r))
  (printf "x (a b c): ~a\n" (scs-result-x r)))

(module+ test
  (require rackunit)
  (define r (run-example))
  (check-true (solved? r))
  (define x (scs-result-x r))
  (check-= (vector-ref x 0) 1.0 1e-4)
  (check-= (vector-ref x 1) 1.0 1e-4)
  (check-= (vector-ref x 2) 1.0 1e-4))
