#lang scribble/lp2

@(require (for-label racket/base
                     ffi/unsafe
                     scs
                     scs/foreign))

@section[#:tag "ex-warm-start"]{Warm starting with @racket[scs-update]}

When you solve a @emph{sequence} of problems that differ only in the right-hand
side @tt{b} or the objective @tt{c}, you can keep one solver workspace, swap in
the new data with @racket[scs-update], and re-solve @deftech{warm starting} from
the previous solution. This is much cheaper than rebuilding the workspace, and
it is the pattern behind the lasso (@secref["ex-lasso"]) and MPC
(@secref["ex-mpc"]) examples. It is driven through the
@racketmodname[scs/foreign] layer.

We reuse the linear program of @secref["ex-lp"], solving first with bounds
@tt{b = (1, 1)} (giving @tt{x = (1, 1)}), then updating to @tt{b = (2, 3)}
(giving @tt{x = (2, 3)}).

@chunk[<require>
(require ffi/unsafe
         scs
         scs/foreign)]

@chunk[<provide>
(provide run-example)]

@subsection{Allocating the solution and info structs}

The foreign layer writes results into caller-allocated buffers. @tt{ScsInfo}
holds two C strings (status and linear-system-solver name); we allocate backing
storage for them up front:

@chunk[<make-info>
(define info-str-type (_array _byte 128))

(define (make-info)
  (new-scs-info
   #:status (ptr-ref (malloc 'atomic-interior info-str-type) info-str-type 0)
   #:lin_sys_solver (ptr-ref (malloc 'atomic-interior info-str-type) info-str-type 0)))]

@subsection{Building the workspace}

@racket[scs:vector->float-ptr] copies a Racket vector into a freshly allocated
@tt{scs_float} array. @racket[retain!] records those buffers against the struct
that points at them so the garbage collector keeps them alive. @racket[scs-init]
factorizes the workspace once; the solution vectors @tt{x}, @tt{y}, @tt{s} are
plain @tt{scs_float} arrays.

@chunk[<setup>
  (define A
    (scs:matrix 4 2
                 1   0
                 0   1
                -1   0
                 0  -1))
  (define c  (scs:vector->float-ptr #(-1.0 -1.0)))
  (define b1 (scs:vector->float-ptr #(1.0 1.0 0.0 0.0)))
  (define data (retain! (make-scs-data 4 2 A #f b1 c) A b1 c))
  (define cone (make-cone #:positive 4))
  (define stgs (make-settings #:eps-abs 1e-9 #:eps-rel 1e-9))
  (define work (scs-init data cone stgs))
  (define sx (malloc 'atomic-interior _scs-float 2))
  (define sy (malloc 'atomic-interior _scs-float 4))
  (define ss (malloc 'atomic-interior _scs-float 4))
  (define sol (retain! (make-scs-solution sx sy ss) sx sy ss))
  (define info (make-info))]

@subsection{Solve, update, re-solve}

The first @racket[scs-solve] passes warm flag @racket[0] (cold start). Then
@racket[scs-update] swaps in the new @tt{b}, and the second @racket[scs-solve]
passes @racket[1] to warm start from the previous iterate:

@chunk[<run>
  (define flag1 (scs-solve work sol info 0))
  (define x1 (scs:float-ptr->vector (scs-solution-x sol) 2))

  (define b2 (scs:vector->float-ptr #(2.0 3.0 0.0 0.0)))
  (scs-update work b2 c)
  (define flag2 (scs-solve work sol info 1))
  (define x2 (scs:float-ptr->vector (scs-solution-x sol) 2))

  (list (list flag1 x1) (list flag2 x2))]

@chunk[<run-example>
(define (run-example)
  <setup>
  <run>)]

@bold{Running it.}

@racketblock[
(run-example)
(code:comment "'((1 #(1.0 1.0)) (1 #(2.0 3.0)))")
]

@chunk[<*>
  <require>
  <provide>
  <make-info>
  <run-example>]
