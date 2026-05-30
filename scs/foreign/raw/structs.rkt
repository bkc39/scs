#lang racket/base

;; FFI cstruct definitions mirroring the SCS public C API (scs.h, SCS 3.2.11).
;; Layouts must match the installed library exactly; see AGENTS.md for the
;; scs_int width / spectral-cone caveats.

(require ffi/unsafe
         "kw-struct.rkt"
         "library.rkt")

(provide (all-defined-out))

;; All SCS structs and the buffers they point at are handed to C, so they must
;; live in non-moving memory: 'atomic-interior is GC-managed but the collector
;; never relocates it.  Plain 'atomic memory MOVES, which would leave the raw
;; addresses stored in these structs (and held by the C solver) dangling after
;; an unrelated allocation triggers a GC.

;; ScsCone -- rows of A must appear in this exact order.
;; NOTE: cs/cssize (complex semidefinite cones) were added in SCS 3.2.4 between
;; ssize and ep.  The spectral-cone fields (USE_SPECTRAL_CONES) are NOT present
;; because the nixpkgs build does not compile them in.
(define-cstruct _scs-cone
  (;; number of linear equality constraints (primal zero, dual free)
   [z _scs-int]
   ;; number of positive orthant cones
   [l _scs-int]
   ;; upper box values
   [bu _pointer]
   ;; lower box values
   [bl _pointer]
   ;; total length of box cone (includes scale t)
   [bsize _scs-int]
   ;; array of second-order cone constraints
   [q _pointer]
   ;; length of second-order cone array
   [qsize _scs-int]
   ;; array of semidefinite cone constraints
   [s _pointer]
   ;; length of semidefinite constraints array
   [ssize _scs-int]
   ;; array of complex semidefinite cone constraints (added in SCS 3.2.4)
   [cs _pointer]
   ;; length of complex semidefinite constraints array
   [cssize _scs-int]
   ;; number of primal exponential cone triples
   [ep _scs-int]
   ;; number of dual exponential cone triples
   [ed _scs-int]
   ;; array of power cone params
   [p _pointer]
   ;; number of primal and dual power cone triples
   [psize _scs-int])
  #:malloc-mode 'atomic-interior)

;; ScsMatrix -- compressed sparse column (CSC), zero-based indexing.
(define-cstruct _scs-matrix
  (;; matrix values: size = number of non-zeros
   [x _pointer]
   ;; matrix row indices, size = number of non-zeros
   [i _pointer]
   ;; matrix column pointers, size = n+1
   [p _pointer]
   ;; number of rows
   [m _scs-int]
   ;; number of columns
   [n _scs-int])
  #:malloc-mode 'atomic-interior)

;; ScsData -- problem data.
(define-cstruct _scs-data
  (;; A has m rows
   [m _scs-int]
   ;; A has n cols, P has n cols and n rows
   [n _scs-int]
   ;; A in CSC format, size m x n
   [A _scs-matrix-pointer]
   ;; P in CSC format, size n x n (PSD, upper triangle only); SCS_NULL if absent.
   ;; Plain _pointer so it accepts both a scs-matrix instance and #f (NULL).
   [P _pointer]
   ;; dense array for b (size m)
   [b _pointer]
   ;; dense array for c (size n)
   [c _pointer])
  #:malloc-mode 'atomic-interior)

;; ScsSettings -- solver configuration.  `new-scs-settings` builds one with all
;; fields zeroed; pair with scs-set-default-settings to populate real defaults.
(define-cstruct+kw-constructor _scs-settings
  (;; whether to heuristically rescale the data before solve
   [normalize _scs-int]
   ;; initial dual scaling factor
   [scale _scs-float]
   ;; whether to adaptively update scale
   [adaptive_scale _scs-int]
   ;; primal constraint scaling factor
   [rho_x _scs-float]
   ;; maximum iterations to take
   [max_iters _scs-int]
   ;; absolute convergence tolerance
   [eps_abs _scs-float]
   ;; relative convergence tolerance
   [eps_rel _scs-float]
   ;; infeasible convergence tolerance
   [eps_infeas _scs-float]
   ;; Douglas-Rachford relaxation parameter
   [alpha _scs-float]
   ;; time limit in secs (can be fractional)
   [time_limit_secs _scs-float]
   ;; whether to log progress to stdout
   [verbose _scs-int]
   ;; whether to use warm start (initial guess in ScsSolution)
   [warm_start _scs-int]
   ;; memory for acceleration
   [acceleration_lookback _scs-int]
   ;; interval to apply acceleration
   [acceleration_interval _scs-int]
   ;; if set, dump raw prob data to this file
   [write_data_filename _string]
   ;; if set, log data to this csv file (makes SCS slow)
   [log_csv_filename _string])
  #:malloc-mode 'atomic-interior)

;; ScsSolution -- primal/dual/slack solution arrays.
(define-cstruct _scs-solution
  (;; primal variable
   [x _pointer]
   ;; dual variable
   [y _pointer]
   ;; slack variable
   [s _pointer])
  #:malloc-mode 'atomic-interior)

;; ScsInfo -- solve summary at termination.
(define-cstruct+kw-constructor _scs-info
  (;; number of iterations taken
   [iter _scs-int]
   ;; status string
   [status (_array _byte 128)]
   ;; linear system solver used
   [lin_sys_solver (_array _byte 128)]
   ;; status as scs_int
   [status_val _scs-int]
   ;; number of updates to scale
   [scale_updates _scs-int]
   ;; primal objective value
   [pobj _scs-float]
   ;; dual objective value
   [dobj _scs-float]
   ;; primal equality residual
   [res_pri _scs-float]
   ;; dual equality residual
   [res_dual _scs-float]
   ;; duality gap
   [gap _scs-float]
   ;; infeasibility cert residual
   [res_infeas _scs-float]
   ;; unbounded cert residual
   [res_unbdd_a _scs-float]
   ;; unbounded cert residual
   [res_unbdd_p _scs-float]
   ;; time taken for setup phase (ms)
   [setup_time _scs-float]
   ;; time taken for solve (ms)
   [solve_time _scs-float]
   ;; final scale parameter
   [scale _scs-float]
   ;; complementary slackness
   [comp_slack _scs-float]
   ;; number of rejected AA steps
   [rejected_accel_steps _scs-int]
   ;; number of accepted AA steps
   [accepted_accel_steps _scs-int]
   ;; total time (ms) in the linear solver
   [lin_sys_time _scs-float]
   ;; total time (ms) in the cone projection
   [cone_time _scs-float]
   ;; total time (ms) in the acceleration routine
   [accel_time _scs-float])
  #:malloc-mode 'atomic-interior)
