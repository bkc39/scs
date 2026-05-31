#lang racket/base

;; Live cross-validation of every example against the upstream Python `scs`.
;;
;; For each example we call its Racket `run-example`, run the adjacent Python
;; reproduction (scs/examples/NN-*.py, which prints {"values": [...]}), and
;; check the two solutions agree.  Python `scs`/`numpy`/`scipy` live only in the
;; `nix develop` shell, so when python3 can't `import scs` this test SKIPS
;; (prints a notice, no failures) -- keeping `raco test` and `nix build` green.
;;
;; Run for real inside `nix develop`:  raco test scs/tests/python-cross-test.rkt

(module+ test
  (require racket/list
           racket/port
           racket/runtime-path
           racket/system
           json
           rackunit
           "../main.rkt")

  (define-runtime-path examples-dir "../examples")

  (define python (find-executable-path "python3"))

  (define (python-scs-available?)
    (and python
         (parameterize ([current-output-port (open-output-nowhere)]
                        [current-error-port (open-output-nowhere)])
           (system* python "-c" "import scs"))))

  ;; Run a Python example file and return its {"values": [...]} as a list.
  (define (python-values rkt-name)
    (define py (build-path examples-dir (string-append rkt-name ".py")))
    (define out (open-output-string))
    (define ok?
      (parameterize ([current-output-port out]
                     [current-error-port (open-output-nowhere)])
        (system* python (path->string py))))
    (unless ok?
      (error 'python-cross-test "python failed for ~a" rkt-name))
    (hash-ref (read-json (open-input-string (get-output-string out))) 'values))

  ;; The Racket `run-example` result, flattened to the same ordering the
  ;; matching Python file prints.
  (define (x-list r) (vector->list (scs-result-x r)))

  ;; (name racket-adapter [tolerance])
  (define specs
    (list
     (list "01-linear-program"          x-list)
     (list "02-quadratic-program"       x-list)
     (list "03-second-order-cone"       x-list)
     (list "04-exponential-cone"        x-list)
     (list "05-semidefinite"            x-list)
     (list "06-power-cone"              x-list)
     (list "07-indirect-solver"         x-list)
     (list "08-warm-start-update"
           (lambda (rows) (append* (map (lambda (s) (vector->list (cadr s))) rows))))
     (list "09-lasso"
           (lambda (rows) (append* (map (lambda (row) (vector->list (caddr row))) rows))))
     (list "10-elastic-net"
           (lambda (ws) (append* (map vector->list ws))))
     (list "11-max-entropy"             x-list)
     (list "12-support-vector-machine"
           (lambda (wb) (append (vector->list (car wb)) (list (cadr wb)))))
     (list "13-portfolio"
           (lambda (w) (vector->list w)))
     (list "14-mpc"
           (lambda (rows) (map caddr rows)))))

  (define default-tol 1e-4)

  (cond
    [(not (python-scs-available?))
     (printf "[python-cross-test] skipped: python3 `scs` not available ~a\n"
             "(run inside `nix develop`)")]
    [else
     (for ([spec (in-list specs)])
       (define name (car spec))
       (define adapter (cadr spec))
       (define tol (if (>= (length spec) 3) (caddr spec) default-tol))
       (define run (dynamic-require (build-path examples-dir
                                                (string-append name ".rkt"))
                                    'run-example))
       (define racket-vals (adapter (run)))
       (define py-vals (python-values name))
       (test-case name
         (check-equal? (length racket-vals) (length py-vals)
                       (format "~a: value count differs" name))
         (define max-delta
           (for/fold ([m 0.0])
                     ([rv (in-list racket-vals)]
                      [pv (in-list py-vals)]
                      [i (in-naturals)])
             (check-= rv pv tol (format "~a index ~a" name i))
             (max m (abs (- rv pv)))))
         (printf "[python-cross-test] ~a: racket vs python  max|Δ|=~a  OK\n"
                 name max-delta)))]))
