#lang scribble/lp2

@(require (for-label racket/base
                     scs))

@section[#:tag "ex-portfolio"]{Portfolio optimization}

Markowitz @deftech{portfolio optimization} chooses asset weights @tt{w} that
minimize risk for a required return:

@nested[#:style 'inset]{
  minimize    @tt{wᵀΣ w} @linebreak[]
  subject to  @tt{1ᵀw = 1}, @tt{μᵀw ≥ r}, @tt{w ≥ 0}
}

where @tt{Σ} is the return covariance, @tt{μ} the expected returns, @tt{r} a
target return, and @tt{w ≥ 0} forbids short positions (a @deftech{long-only}
portfolio). This is a quadratic program touching three cone types at once: an
equality (the budget), an inequality (the return floor), and the nonnegativity
orthant. We expose @racket[(optimize-portfolio Sigma mu #:min-return r)].

@chunk[<require>
(require racket/list
         scs)]

@chunk[<provide>
(provide optimize-portfolio run-example)]

@bold{Standard form.}

The objective @tt{wᵀΣ w} is @tt{½ wᵀP w} with @tt{P = 2Σ}, and @tt{c = 0}. The
constraints, in cone order, are one @tech{zero cone} row for the budget, then
positive-orthant rows for the return floor (@tt{−μᵀw ≤ −r}) and the long-only
bounds (@tt{−w_i ≤ 0}):

@chunk[<helpers>
(define (sparse-row n entries)
  (for/list ([k (in-range n)])
    (cond [(assoc k entries) => cdr] [else 0])))]

@chunk[<optimize-portfolio>
(define (optimize-portfolio Sigma mu #:min-return r)
  (define n (length mu))
  ;; P = 2*Sigma, upper triangle.
  (define P
    (apply scs:sparse-matrix n n
           (for*/list ([i (in-range n)] [j (in-range n)]
                       #:when (<= i j)
                       #:when (not (zero? (list-ref (list-ref Sigma i) j))))
             (list i j (* 2.0 (list-ref (list-ref Sigma i) j))))))
  (define budget (make-list n 1.0))                 (code:comment "1ᵀw = 1")
  (define return-row (for/list ([m (in-list mu)]) (- m))) (code:comment "-μᵀw <= -r")
  (define long-only                                 (code:comment "-w_i <= 0")
    (for/list ([i (in-range n)]) (sparse-row n (list (cons i -1)))))
  (define A
    (apply scs:matrix (+ n 2) n
           (append budget return-row (append* long-only))))
  (define b (append (list 1.0 (- r)) (make-list n 0.0)))
  (define result
    (solve #:A A
           #:b b
           #:c (make-list n 0.0)
           #:P P
           #:cone (make-cone #:zero 1 #:positive (+ n 1))
           #:settings (make-settings #:eps-abs 1e-9 #:eps-rel 1e-9)))
  (scs-result-x result))]

@bold{Running it.}

Two uncorrelated assets, the second less risky, with a return floor that binds.
The minimum-risk feasible portfolio splits evenly: @tt{w = (0.5, 0.5)}.

@chunk[<run-example>
(define Sigma '((2.0 0.0) (0.0 1.0)))    (code:comment "covariance")
(define mu    '(0.2 0.1))                (code:comment "expected returns")

(define (run-example)
  (optimize-portfolio Sigma mu #:min-return 0.15))]

@racketblock[
(run-example)   (code:comment "#(0.5 0.5)")
]

@chunk[<*>
  <require>
  <provide>
  <helpers>
  <optimize-portfolio>
  <run-example>]
