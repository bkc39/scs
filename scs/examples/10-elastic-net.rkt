#lang scribble/lp2

@(require (for-label racket/base
                     scs))

@section[#:tag "ex-elastic-net"]{Elastic net regression}

The @deftech{elastic net} is a linear regressor that blends ridge (L2) and
lasso (L1) regularization. Given a design matrix @tt{X} (one row per sample)
and targets @tt{y}, it fits weights @tt{w} minimizing

@nested[#:style 'inset]{
  @tt{‖X w − y‖₂² + λα‖w‖₂² + λ(1−α)‖w‖₁}
}

The @deftech{regularization strength} @tt{λ ≥ 0} controls the overall amount of
shrinkage, and the @deftech{mixing parameter} @tt{α ∈ [0, 1]} interpolates
between the two penalties: @tt{α = 1} is pure ridge, @tt{α = 0} is pure lasso
(@secref["ex-lasso"]), and intermediate values combine them. This example
exposes that as a reusable procedure,
@racket[(make-elastic-net X y #:lambda λ #:alpha α)], returning the fitted
@tt{w}.

@chunk[<require>
(require racket/list
         scs)]

@chunk[<provide>
(provide make-elastic-net run-example)]

@subsection{From the objective to a quadratic program}

Expanding the squared residual, @tt{‖X w − y‖₂² = wᵀ(XᵀX)w − 2(Xᵀy)ᵀw + yᵀy},
and folding in the ridge term @tt{λα‖w‖₂² = λα wᵀw}, the smooth part of the
objective is @tt{wᵀ(XᵀX + λα I)w − 2(Xᵀy)ᵀw} (the constant @tt{yᵀy} is
irrelevant to the minimizer).

The L1 term uses the @tech{absolute-value trick}: introduce @tt{t} with
@tt{|w_i| ≤ t_i}, written as the two inequalities @tt{w_i − t_i ≤ 0} and
@tt{−w_i − t_i ≤ 0}, and add @tt{λ(1−α)·Σ t_i} to the objective. Over the
stacked variable @tt{(w, t)} this is a quadratic cone program in SCS's standard
form @tt{½ vᵀP v + cᵀv}:

@itemlist[
 @item{@tt{P} has @tt{2(XᵀX + λα I)} on the @tt{w} block and zeros on the
       @tt{t} block (the factor 2 absorbs SCS's @tt{½}).}
 @item{@tt{c = (−2 Xᵀy, λ(1−α)·1)}.}
 @item{the @tt{2n} constraint rows are all positive-orthant.}
]

@subsection{Small matrix helpers}

We take @tt{X} as a list of rows and @tt{y} as a list, and compute the needed
Gram entries directly. @racket[col-dot] is the @tt{(i, j)} entry of @tt{XᵀX},
and @racket[col-y-dot] the @tt{i}th entry of @tt{Xᵀy}.

@chunk[<helpers>
(define (col-dot X i j)
  (for/sum ([row (in-list X)]) (* (list-ref row i) (list-ref row j))))

(define (col-y-dot X y i)
  (for/sum ([row (in-list X)] [yi (in-list y)]) (* (list-ref row i) yi)))

;; A dense row of width n2 with the given (index . value) entries, zeros elsewhere.
(define (sparse-row n2 entries)
  (for/list ([k (in-range n2)])
    (cond [(assoc k entries) => cdr] [else 0])))]

@subsection{Assembling and solving}

@chunk[<make-elastic-net>
(define (make-elastic-net X y #:lambda lam #:alpha alpha)
  (define n (length (car X)))      (code:comment "number of features")
  (define n2 (* 2 n))              (code:comment "variables (w, t)")
  ;; P: upper triangle of 2(XᵀX + lam*alpha*I) on the w block.
  (define P-triples
    (for*/list ([i (in-range n)] [j (in-range n)]
                #:when (<= i j)
                #:when (let ([v (+ (* 2.0 (col-dot X i j))
                                   (if (= i j) (* 2.0 lam alpha) 0.0))])
                         (not (zero? v))))
      (list i j (+ (* 2.0 (col-dot X i j))
                   (if (= i j) (* 2.0 lam alpha) 0.0)))))
  (define P (apply scs:sparse-matrix n2 n2 P-triples))
  ;; Constraints: w_i - t_i <= 0 and -w_i - t_i <= 0 for each i.
  (define rows
    (append*
     (for/list ([i (in-range n)])
       (list (sparse-row n2 (list (cons i 1) (cons (+ n i) -1)))
             (sparse-row n2 (list (cons i -1) (cons (+ n i) -1)))))))
  (define A (apply scs:matrix n2 n2 (append* rows)))
  (define c
    (list->vector
     (append (for/list ([i (in-range n)]) (* -2.0 (col-y-dot X y i)))
             (make-list n (* lam (- 1.0 alpha))))))
  (define result
    (solve #:A A
           #:b (make-list n2 0.0)
           #:c c
           #:P P
           #:cone (make-cone #:positive n2)
           #:settings (make-settings #:eps-abs 1e-9 #:eps-rel 1e-9)))
  (for/vector ([i (in-range n)]) (vector-ref (scs-result-x result) i)))]

@bold{Running it.}

On a small dataset, @tt{α = 1} recovers the closed-form ridge solution while
mixing in some L1 (@tt{α < 1}) shrinks the weights further:

@chunk[<run-example>
(define X '((1.0 0.0) (0.0 1.0) (1.0 1.0)))
(define y '(1.0 2.0 0.5))

(define (run-example)
  (list (make-elastic-net X y #:lambda 0.1 #:alpha 1.0)    (code:comment "ridge")
        (make-elastic-net X y #:lambda 0.2 #:alpha 0.5)))  (code:comment "elastic")]

@racketblock[
(car (run-example))   (code:comment "#(0.1906 1.0997), the ridge optimum")
]

@chunk[<*>
  <require>
  <provide>
  <helpers>
  <make-elastic-net>
  <run-example>]
