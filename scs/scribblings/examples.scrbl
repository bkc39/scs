#lang scribble/manual

@(require scribble/lp-include
          (for-label racket/base
                     scs))

@title[#:tag "examples" #:style 'toc]{Examples}

Each example below is a @deftech{literate program}: the prose and the code you
see are the @emph{same source} that lives in the package's
@filepath{scs/examples/} directory and is exercised by the test suite, so the
walkthroughs never drift from working code. Every example provides a
@racket[run-example] thunk; its companion harness in
@filepath{scs/examples/test/} drives it and checks the result (run with
@exec{raco test}).

The examples build up in three arcs. The @bold{foundations}
(@secref["ex-lp"] through @secref["ex-power"]) introduce one cone family at a
time through the high-level @racket[solve] interface: a linear program, then a
quadratic objective, then the second-order, exponential, semidefinite, and
power cones. The @bold{solver mechanics} (@secref["ex-indirect"],
@secref["ex-warm-start"]) cover choosing the indirect linear-system solver and
reusing a workspace across re-solves. The @bold{applications}
(@secref["ex-lasso"] through @secref["ex-mpc"]) assemble those pieces into
recognizable models --- regression, classification, finance, and control.

@local-table-of-contents[]

@; foundations
@lp-include["../examples/01-linear-program.rkt"]
@lp-include["../examples/02-quadratic-program.rkt"]
@lp-include["../examples/03-second-order-cone.rkt"]
@lp-include["../examples/04-exponential-cone.rkt"]
@lp-include["../examples/05-semidefinite.rkt"]
@lp-include["../examples/06-power-cone.rkt"]

@; solver mechanics
@lp-include["../examples/07-indirect-solver.rkt"]
@lp-include["../examples/08-warm-start-update.rkt"]

@; applications
@lp-include["../examples/09-lasso.rkt"]
@lp-include["../examples/10-elastic-net.rkt"]
@lp-include["../examples/11-max-entropy.rkt"]
@lp-include["../examples/12-support-vector-machine.rkt"]
@lp-include["../examples/13-portfolio.rkt"]
@lp-include["../examples/14-mpc.rkt"]
