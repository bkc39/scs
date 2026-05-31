#lang scribble/lp2

@(require (for-label racket/base
                     scs))

@section[#:tag "ex-svm"]{Support vector machine}

A soft-margin @deftech{support vector machine} (SVM) is the classic
classification QP. Given labelled points @tt{(x_i, y_i)} with @tt{y_i ∈ {−1,
+1}}, it fits a separating hyperplane @tt{wᵀx + b} by solving

@nested[#:style 'inset]{
  minimize    @tt{½‖w‖₂² + C·Σ ξ_i} @linebreak[]
  subject to  @tt{y_i (wᵀx_i + b) ≥ 1 − ξ_i}, @tt{ξ_i ≥ 0}
}

The slacks @tt{ξ_i} (the @deftech{hinge losses}) let points fall inside or past
the margin at a cost @tt{C}. This example exposes
@racket[(train-svm data #:C C)], returning the fitted @tt{w} and @tt{b}.

@chunk[<require>
(require racket/list
         scs)]

@chunk[<provide>
(provide train-svm run-example)]

@subsection{Variables and standard form}

Stack the unknowns as @tt{v = (w, b, ξ)} with @tt{d} weights, one intercept,
and @tt{m} slacks. The objective is quadratic only in @tt{w}, so @tt{P} is the
identity on the @tt{w} block (giving @tt{½‖w‖₂²}) and zero elsewhere, and
@tt{c} places @tt{C} on each @tt{ξ}. Both constraint families become
positive-orthant rows once moved to @tt{Ax ≤ b} form: the margin constraint
@tt{y_i(wᵀx_i + b) + ξ_i ≥ 1} negates to

@nested[#:style 'inset]{
  @tt{−y_i x_iᵀ w − y_i b − ξ_i ≤ −1}
}

and @tt{ξ_i ≥ 0} is @tt{−ξ_i ≤ 0}.

@chunk[<helpers>
;; A dense row of width n with the given (index . value) entries.
(define (sparse-row n entries)
  (for/list ([k (in-range n)])
    (cond [(assoc k entries) => cdr] [else 0])))]

@chunk[<train-svm>
(define (train-svm data #:C [C 1.0])
  (define m (length data))
  (define d (length (caar data)))     (code:comment "feature dimension")
  (define n (+ d 1 m))                (code:comment "(w, b, slacks)")
  (define b-col d)                    (code:comment "column of the intercept b")
  (define (slack-col i) (+ d 1 i))    (code:comment "column of slack i")
  ;; P: identity on the w block -> (1/2)||w||^2.
  (define P
    (apply scs:sparse-matrix n n
           (for/list ([j (in-range d)]) (list j j 1.0))))
  ;; Two constraint rows per sample.
  (define rows
    (append*
     (for/list ([pt (in-list data)] [i (in-naturals)])
       (define xs (car pt))
       (define y (cadr pt))
       (define margin
         (sparse-row n (append (for/list ([f (in-range d)])
                                 (cons f (* (- y) (list-ref xs f))))
                               (list (cons b-col (- y))
                                     (cons (slack-col i) -1)))))
       (define nonneg (sparse-row n (list (cons (slack-col i) -1))))
       (list margin nonneg))))
  (define A (apply scs:matrix (* 2 m) n (append* rows)))
  (define rhs
    (append* (for/list ([_ (in-range m)]) (list -1.0 0.0))))
  (define c
    (list->vector (append (make-list (+ d 1) 0.0) (make-list m C))))
  (define result
    (solve #:A A
           #:b rhs
           #:c c
           #:P P
           #:cone (make-cone #:positive (* 2 m))
           #:settings (make-settings #:eps-abs 1e-9 #:eps-rel 1e-9)))
  (define x (scs-result-x result))
  (values (for/vector ([j (in-range d)]) (vector-ref x j))
          (vector-ref x b-col)))]

@bold{Running it.}

On a small symmetric, linearly separable set the max-margin hyperplane is
vertical: @tt{w = (0.5, 0)}, @tt{b = 0}.

@chunk[<run-example>
(define dataset
  '(((2.0 1.0)  1) ((2.0 -1.0)  1)
    ((-2.0 1.0) -1) ((-2.0 -1.0) -1)))

(define (run-example)
  (define-values (w b) (train-svm dataset #:C 1.0))
  (list w b))]

@racketblock[
(run-example)   (code:comment "(list #(0.5 0.0) 0.0)")
]

@chunk[<*>
  <require>
  <provide>
  <helpers>
  <train-svm>
  <run-example>]
