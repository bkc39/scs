#lang racket/base

;; 02 - Second-order (Lorentz) cone.
;;
;;   minimize  t   subject to  ||(u, v)||_2 <= t,  u = 3,  v = 4
;;
;; Variables x = (t, u, v).  u, v are pinned by equality constraints; the SOC
;; block forces t >= sqrt(u^2 + v^2) = 5.  Optimal x = (5, 3, 4).
;;
;; The SOC membership is encoded by A = -I on the cone block (b = 0), so the
;; slack s = b - Ax = (t, u, v) lands in the cone.

(require scs)

(provide run-example)

(define (run-example)
  (define A
    (scs:matrix 5 3
                ;; equality: u = 3, v = 4
                0 1 0
                0 0 1
                ;; SOC block: s = (t, u, v)
                -1 0 0
                0 -1 0
                0 0 -1))
  (solve #:A A
         #:b #(3.0 4.0 0.0 0.0 0.0)
         #:c #(1.0 0.0 0.0)
         #:cone (make-cone #:zero 2 #:soc '(3))
         #:settings (make-settings #:eps-abs 1e-9 #:eps-rel 1e-9)))

(module+ main
  (define r (run-example))
  (printf "status: ~a\n" (scs-result-status r))
  (printf "x (t u v): ~a\n" (scs-result-x r)))

(module+ test
  (require rackunit)
  (define r (run-example))
  (check-true (solved? r))
  (define x (scs-result-x r))
  (check-= (vector-ref x 0) 5.0 1e-5)
  (check-= (vector-ref x 1) 3.0 1e-5)
  (check-= (vector-ref x 2) 4.0 1e-5))
