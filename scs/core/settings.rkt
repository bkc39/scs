#lang racket/base

;; make-settings: an ScsSettings with SCS's defaults plus caller overrides;
;; documented in the scs Scribble guide ("Settings").  verbose is off by default
;; (the C default is on) so the library stays quiet unless asked.

(require "../foreign/raw/solver.rkt"
         "../foreign/raw/structs.rkt")

(provide make-settings)

(define (make-settings #:verbose? [verbose? #f]
                       #:normalize? [normalize? #t]
                       #:max-iters [max-iters #f]
                       #:eps-abs [eps-abs #f]
                       #:eps-rel [eps-rel #f]
                       #:eps-infeas [eps-infeas #f]
                       #:time-limit-secs [time-limit-secs #f]
                       #:warm-start? [warm-start? #f])
  (define stgs (new-scs-settings))
  (scs-set-default-settings stgs)
  (set-scs-settings-verbose! stgs (if verbose? 1 0))
  (set-scs-settings-normalize! stgs (if normalize? 1 0))
  (set-scs-settings-warm_start! stgs (if warm-start? 1 0))
  (when max-iters (set-scs-settings-max_iters! stgs max-iters))
  (when eps-abs (set-scs-settings-eps_abs! stgs (exact->inexact eps-abs)))
  (when eps-rel (set-scs-settings-eps_rel! stgs (exact->inexact eps-rel)))
  (when eps-infeas (set-scs-settings-eps_infeas! stgs (exact->inexact eps-infeas)))
  (when time-limit-secs
    (set-scs-settings-time_limit_secs! stgs (exact->inexact time-limit-secs)))
  stgs)
