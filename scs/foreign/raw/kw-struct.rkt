#lang racket/base

;; Metaprogramming used by the raw struct layer.
;;
;; `define-cstruct+kw-constructor` defines a `define-cstruct` plus a
;; keyword-argument constructor (`new-<name>`) whose every field defaults to a
;; type-appropriate zero/empty value.  SCS's settings/info structs have many
;; fields; this lets callers build one while specifying only the fields they
;; care about (e.g. `(new-scs-settings #:eps_abs 1e-9)`).

(require ffi/unsafe
         syntax/parse/define
         (for-syntax racket/base
                     racket/string
                     racket/syntax
                     syntax/stx))

(provide define-cstruct+kw-constructor
         define/kw
         default-value-for-ctype)

;; A neutral default value for a ctype, used to fill omitted keyword fields.
(define (default-value-for-ctype type)
  (define layout
    (ctype->layout type))
  (define integer-types
    (list 'int8 'uint8 'int16 'uint16 'int32 'uint32 'int64 'uint64))
  (define string-types
    (list 'bytes 'string/ucs-4 'string/utf-16))
  (define pointer-types
    (list 'pointer 'fpointer))
  (cond
    [(member layout integer-types)
     0]
    [(member layout string-types)
     ""]
    [(member layout '(float double))
     0.0]
    [(member layout pointer-types)
     #f]
    [(eq? layout 'bool)
     #f]
    [(eq? layout 'void)
     (error "no default value for void")]
    [else
     (raise-argument-error 'default-value-for-type
                           "unrecognized type layout"
                           type)]))

;; Helper that threads a `define` whose trailing keyword formals are appended
;; one at a time, producing a function with optional keyword arguments.
(define-syntax-parser define/fml
  [(_ nm:id
      (fmls ...)
      (body*:expr ...)
      (key:keyword [fml:id default-val:expr]) rest* ...)
   #'(define/fml nm (fmls ... key [fml default-val]) (body* ...) rest* ...)]
  [(_ nm:id (fmls ...) (body*:expr ...))
   #'(define (nm fmls ...)
       body* ...)])

(begin-for-syntax
  (define (trim-underscore id)
    (string-trim
     (symbol->string
      (syntax-e id))
     "_")))

(define-syntax-parse-rule
  (define-cstruct+kw-constructor id:id ([fld type opt ...] ...) prop ...)
  #:with type-name (datum->syntax #'id (trim-underscore #'id))
  #:with default-constructor-name (format-id #'id "make-~a" #'type-name)
  #:with kw-constructor-name (format-id #'id "new-~a" #'type-name)
  (begin
    (define-cstruct id ([fld type opt ...] ...) prop ...)
    (define/kw-with-type-defaults (kw-constructor-name [fld type] ...)
      (default-constructor-name
        fld
        ...))))

(begin-for-syntax
  (define ((id->keyword stx) field-id)
    (datum->syntax
     stx
     (string->keyword
      (symbol->string (syntax-e field-id))))))

(define-syntax-parse-rule
  (define/kw-with-type-defaults
    (nm:id [fld*:id type] ...) e:expr e*:expr ...)
  #:with (kw* ...) (stx-map (id->keyword #'nm) #'(fld* ...))
  (define/fml
    nm
    ()
    (e e* ...)
    (kw* [fld* (default-value-for-ctype type)])
    ...))

;; Like `define`, but every formal becomes a keyword argument defaulting to #f.
(define-syntax-parse-rule (define/kw (nm:id arg*:id ...) e:expr e*:expr ...)
  #:with (kw* ...) (stx-map (id->keyword #'nm) #'(arg* ...))
  (define/fml nm () (e e* ...) (kw* [arg* #f]) ...))

(module+ test
  (require rackunit)

  (define-cstruct+kw-constructor _kw-struct-self-test
    ([A _int]
     [B _size])
    #:malloc-mode 'atomic)

  (define t (new-kw-struct-self-test))
  (check-pred kw-struct-self-test? t)
  (set! t (new-kw-struct-self-test #:B 17))
  (check-pred kw-struct-self-test? t)
  (check-equal? (kw-struct-self-test-B t) 17)
  (set! t (new-kw-struct-self-test #:A -42))
  (check-pred kw-struct-self-test? t)
  (check-equal? (kw-struct-self-test-A t) -42))
