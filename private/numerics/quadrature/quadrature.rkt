#lang racket/base

;; TODO implement 'rational.rkt'
;; TODO test
;; TODO api

(require mechanics)
;(provide/api
;  make-definite-integrator
;  #:contract (-> TODO)
;  #:doc "TODO"
;)

;; -----------------------------------------------------------------------------

(require
  racket/match
;  (only-in "rational.rkt"
;    integrate-closed-closed
;    integrate-closed-closed-1
;    integrate-open-closed
;    integrate-open-closed-1
;    integrate-closed-open
;    integrate-closed-open-1
;    integrate-open-open
;    integrate-open-open-1
;   )
)

;; =============================================================================

;; (define-type Method (U open closed-closed closed-open open-closed open-open romberg bulirsch-stoer)

;; TODO document
(struct definite-integrator (
  integrand ;; (U #f TODO)
  lower-limit ;; (U #f TODO)
  upper-limit ;; (U #f TODO)
  error ;; Flonum
  method ;; Method
) #:mutable ;; All fields can be mutated
  #:property prop:procedure ;; "Applying" an integrator evaluates it
  (lambda (self) (apply-definite-integrator self))
)

;; Create a new integrator.
;; By default, all fields initialized to #f
(define (make-definite-integrator #:integrand [i #f]
                                  #:lo [ll #f]
                                  #:hi [ul #f]
                                  #:epsilon [eps 1.0e-10] ;; TODO machine-e
                                  #:method [m 'open])
  (definite-integrator i ll ul eps m))

;; Evaluate a definite integral
;; (-> definite-integrator TODO)
(define (apply-definite-integrator di)
  (match-define (definite-integrator i ll ul e m) di)
  (evaluate-definite-integral i #:lo ll #:hi ul #:method m #:epsilon e))

;; -----------------------------------------------------------------------------

(define (evaluate-definite-integral integrand
                                    #:method method
                                    #:lo lower-limit-exact
                                    #:hi upper-limit-exact
                                    #:epsilon eps-exact)
  (define lo (exact->inexact lower-limit-exact))
  (define hi (exact->inexact upper-limit-exact))
  (define eps (exact->inexact epsilon))
  (if (or (inf? lo) (inf? hi))
    (evaluate-improper-integral integrand method lo hi eps)
    ;;bg; do we really need all these different functions?
    (case method
     [(open)
      (integrate-open integrand lo hi eps)]
     [(closed-closed)
      (integrate-closed-closed-1 integrand lo hi eps)]
     [(closed-open)
      (integrate-closed-open-1 integrand lo hi eps)]
     [(open-closed)
      (integrate-open-closed-1 integrand lo hi eps)]
     [(open-open)
      (integrate-open-open integrand lo hi eps)]
     [(romberg)
      (romberg-quadrature integrand lo hi eps)]
     [(bulirsch-stoer)
      (bulirsch-stoer-quadrature integrand lo hi eps)]
     [else
      (error 'evaluate-definite-integral (format "Unknown method '~a'" method))])]))

;; (-> Method Integrand TODO TODO Flonum Flonum)
(define (evaluate-improper-integral method integrand lo hi eps)
  (define (new-integrand theta)
    (/ (integrand (tan theta))
       (square (cos theta))))
  (define oo/co? (or (eq? method 'open-open) (eq? method 'closed-open)))
  (define oo/oc? (or (eq? method 'open-open) (eq? method 'open-closed)))
  ;;bg; refactor into a match
  (match (cons lo hi)
   [(cons (neg-inf) (pos-inf))
    (integrate-open-open new-integrand -pi/2 +pi/2 eps)]
   [(cons (neg-inf) (neg-inf))
    0.0]
   [(cons (neg-inf) _)
    (if oo/co? ;;bg; is this a scmutils typo?
        (integrate-open-open new-integrand -pi/2 (atan hi) eps)
        (integrate-open-closed new-integrant -pi/2 (atan hi) eps))]
   [(cons (pos-inf) (pos-inf))
    0.0]
   [(cons (pos-inf) (neg-inf))
    (- (integrate-open-open new-integrand -pi/2 +pi/2 eps))]
   [(cons (pos-inf) _)
    (if oo/oc?
        (- (integrate-open-open new-integrand (atan hi) -pi/2 eps))
        (- (integrate-closed-open new-integrand (atan hi) +pi/2 eps)))]
   [(cons _ (pos-inf))
    (if oo/oc?
        (integrate-open-open new-integrand (atan lo) +pi/2 eps)
        (integrate-closed-open new-integrand (atan lo) +pi/2 eps))]
   [(cons _ (neg-inf))
    (if oo/oc?
        (- (integrate-open-open new-integrand -pi/2 (atan lo) eps))
        (- (integrate-closed-open new-integrand -pi/2 (atan lo) eps)))]
   [_ (error 'improper-integral (format "Bad bounds: expected -inf or +inf, but got lo=~a and hi=~a" lo hi))]))

;; Simpler version from Press et~al.
(define *improper-integral-breakpoint* (make-parameter 1.0))
(define (evaluate-improper-integral/press method integrand hi lo eps)
  (define (new-integrand theta)
      (/ (integrand (/ 1.0 theta))
         (square theta theta)))
  (match (cons lo hi)
   [(cons (neg-inf) (neg-inf))
    0.0]
   [(cons (neg-inf) (pos-inf))
    (+ (integrate-closed-open new-integrand (/ -1.0 (*improper-integral-breakpoint*)) 0.0 eps)
       (integrate-closed-closed integrand (- (*improper-integral-breakpoint*)) (*improper-integral-breakpoint*) eps)
       (integrate-open-closed new-integrand 0.0 (/ 1.0 (*improper-integral-breakpoint*)) eps))]
    [(cons (neg-inf) _)
     (if (<= hi (- (*improper-integral-breakpoint*)))
       (integrate-open-open new-integrand (/ -1.0 hi) 0.0 eps)
       (+ (integrate-closed-open new-integrand (/ -1.0 (*improper-integral-breakpoint*)) 0.0 eps)
          (integrate-closed-open integrand (- (*improper-integral-breakpoint*)) hi eps)))]
   [(cons (pos-inf) (neg-inf))
    (- (+ (integrate-closed-open new-integrand (/ -1.0 (*improper-integral-breakpoint*)) 0.0 eps)
          (integrate-closed-closed integrand (- (*improper-integral-breakpoint*)) (*improper-integral-breakpoint*) eps)
          (integrate-open-closed new-integrand 0.0 (/ 1.0 (*improper-integral-breakpoint*)) eps)))]
   [(cons (pos-inf) (pos-inf))
     0.0]
   [(cons (pos-inf) _)
    (if (>= hi (*improper-integral-breakpoint*))
      (- (integrate-open-open new-integrand (/ 1.0 hi) 0.0 eps))
      (- (+ (integrate-closed-open new-integrand (/ 1.0 (*improper-integral-breakpoint*)) 0.0 eps)
            (integrate-closed-open integrand (*improper-integral-breakpoint*) hi eps))))]
   [(cons _ (neg-inf))
    (if (<= lo (- (*improper-integral-breakpoint*)))
        (integrate-open-open new-integrand (/ -1.0 lo) 0.0 eps)
        (+ (integrate-closed-open new-integrand (/ -1.0 (*improper-integral-breakpoint*)) 0.0 eps)
           (integrate-closed-open integrand (*improper-integral-breakpoint*) lo eps)))]
   [(cons _ (pos-inf))
    (if (>= lo (*improper-integral-breakpoint*))
        (integrate-open-open new-integrand 0.0 (/ 1.0 lo) eps)
        (+ (integrate-open-closed integrand lo (*improper-integral-breakpoint*) eps)
           (integrate-open-closed new-integrand 0.0 (/ 1.0 (*improper-integral-breakpoint*)) eps)))]
   [_ (error 'improper-integral/press (format "Bad bounds: expect -inf or +inf, got lo=~a and hi=~a" lo hi))]))

;;bg; idk...
;(define (bulirsch-stoer-quadrature f t1 t2 eps)
;  ((advance-generator
;    (bulirsch-stoer-lisptran
;     ;; state = #(t int) ==> dstate = #(1.0 ,(integral f t1 t))
;     (lambda (state dstate)
;       (vector-set! dstate 0 1.0)
;       (vector-set! dstate 1 (f (vector-ref state 0))))
;     2
;     eps))
;    (vector t1 0.0)
;    (- t2 t1)
;    (/ (- t2 t1) 2)
;    (- t2 t1)
;    (lambda (ns dt h cont) (cont))
;    (lambda (ns dt sdt) (vector-ref ns 1))))

;; =============================================================================

;(module+ test
;  (require rackunit)
;
;  ;; -- bug in SICM: this should be pi, but converges too slowly
;  ;; -- ... I do not like the use of symbols
;  ;(* 2
;  ;   ((make-definite-integrator
;  ;     (lambda->numerical-procedure
;  ;      '(lambda (x) (/ (sin x) x)))
;  ;     0.0
;  ;     inf
;  ;     .01)
;  ;    'integral))
;
;  ;(define (pi-test)
;  ;  (define witch
;  ;    (lambda->numerical-procedure
;  ;      '(lambda (x)
;  ;        (/ 4.0 (+ 1.0 (* x x))))))
;  ;  (define integrator (make-definite-integrator))
;  ;  (integrator 'set-method! 'romberg)
;  ;  (integrator 'set-error! 1e-12)
;  ;  (integrator 'set-integrand! witch)
;  ;  (integrator 'set-lower-limit! 0.0)
;  ;  (integrator 'set-upper-limit! 1.0)
;  ;  (check-equal? (integrator 'integral) 3.141592653589793))
;  ;(pi-test)
;
;  (define (foo-test)
;    (define (foo n)
;      (define int
;        (make-definite-integrator
;          (lambda (x) (expt (log (/ 1 x)) n))
;          0.0
;          1.0
;          1e-121))
;      (int 'set-method! 'open-closed)
;      (int 'integral))
;    (define cod* '(1. .9999999999979357
;                   1.9999999999979101
;                   5.99999999999799
;                   23.999999999997893
;                   119.99999999999828))
;    (for ([d (in-range 0 6)]
;          [c (in-list cod*)])
;      (check-equal? (foo d) c)))
;  (foo-test)
;
;  (define (bar-test)
;    (define int
;      (make-definite-integrator
;        (lambda (x) (* (exp (- x)) (log x)))
;        0.0
;        inf
;        1e-11))
;    (int 'set-method! 'open-open)
;    (check-equal? (int 'integral) -.5772156648993277))
;  (bar-test)
;)