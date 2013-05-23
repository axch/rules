;;; This file is part of Rules, an extensible pattern matching,
;;; pattern dispatch, and term rewriting system for MIT Scheme.
;;; Copyright 2010-2013 Alexey Radul, Massachusetts Institute of
;;; Technology
;;;
;;; Rules is free software; you can redistribute it and/or modify it
;;; under the terms of the GNU Affero General Public License as
;;; published by the Free Software Foundation; either version 3 of the
;;; License, or (at your option) any later version.
;;; 
;;; This code is distributed in the hope that it will be useful,
;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.
;;; 
;;; You should have received a copy of the GNU Affero General Public
;;; License along with Rules; if not, see
;;; <http://www.gnu.org/licenses/>.

(declare (usual-integrations))

;;;; Term rewriting

;;; Make a term-rewriting system from a collection of rules.  This is
;;; just a facade for a particular rule application strategy chosen
;;; from the combinators below.

(define (term-rewriting . rules)
  (rule-simplifier rules))

(define (rule-simplifier the-rules)
  (iterated-on-subexpressions (rule-list the-rules)))

;;;; Rule combinators

;;; Various patterns of rule application captured as combinators that
;;; take rules and produce rules (to wit, procedures that accept one
;;; input and return the result of transforming it, where returning
;;; the input itself signals match failure).

;; Apply several rules in series, returning the first result that
;; matches.
(define ((rule-list rules) data)
  (let per-rule ((rules rules))
    (if (null? rules)
	data
	(let ((answer ((car rules) data)))
	  (if (eqv? data answer)
	      (per-rule (cdr rules))
	      answer)))))

;; Apply several rules in series, threading the result of each into
;; the next.
(define ((in-order . the-rules) datum)
  (let loop ((the-rules the-rules)
             (datum datum))
    (if (null? the-rules)
        datum
        (loop (cdr the-rules) ((car the-rules) datum)))))

;; Apply one rule repeatedly until it doesn't match anymore.
(define ((iterated the-rule) data)
  (let loop ((data data)
             (answer (the-rule data)))
    (if (eqv? answer data)
        answer
        (loop answer (the-rule answer)))))

;; Apply one rule to all subexpressions of the input, bottom-up.
(define (on-subexpressions the-rule)
  (define (on-expression expression)
    (let ((subexpressions-done (try-subexpressions on-expression expression)))
      (the-rule subexpressions-done)))
  on-expression)

(define (try-subexpressions the-rule expression)
  (if (list? expression)
      (let ((subexpressions-tried (map the-rule expression)))
        (if (every eqv? expression subexpressions-tried)
            expression
            subexpressions-tried))
      expression))

;; Iterate one rule to convergence on all subexpressions of the input,
;; bottom up.  Note that subexpressions of a result returned by one
;; invocation of the rule may admit additional invocations, so we need
;; to recur again after every successful transformation.
(define (iterated-on-subexpressions the-rule)
  ;; Unfortunately, this is not just a composition of the prior two.
  (define (on-expression expression)
    (let ((subexpressions-done (try-subexpressions on-expression expression)))
      (let ((answer (the-rule subexpressions-done)))
	(if (eqv? answer subexpressions-done)
	    answer
	    (on-expression answer)))))
  on-expression)

;; Iterate one rule to convergence on all subexpressions of the input,
;; applying it on the way down as well as back up.
(define (top-down the-rule)
  (define (on-expression expression)
    (let ((answer (the-rule expression)))
      (if (eqv? answer expression)
          (let ((subexpressions-done
                 (try-subexpressions on-expression expression)))
            (let ((answer (the-rule subexpressions-done)))
              (if (eqv? answer subexpressions-done)
                  answer
                  (on-expression answer))))
          (on-expression answer))))
  on-expression)


(define (list<? x y)
  (let ((nx (length x)) (ny (length y)))
    (cond ((< nx ny) #t)
	  ((> nx ny) #f)
	  (else
	   (let lp ((x x) (y y))
	     (cond ((null? x) #f)	; same
		   ((expr<? (car x) (car y)) #t)
		   ((expr<? (car y) (car x)) #f)
		   (else (lp (cdr x) (cdr y)))))))))

(define expr<?
  (make-entity
   (lambda (self x y)
     (let per-type ((types (entity-extra self)))
       (if (null? types)
	   (error "Unknown expression type -- expr<?" x y)
	   (let ((predicate? (caar types))
		 (comparator (cdar types)))
	     (cond ((predicate? x)
		    (if (predicate? y)
			(comparator x y)
			#t))
		   ((predicate? y) #f)
		   (else (per-type (cdr types))))))))
   `((,null?    . ,(lambda (x y) #f))
     (,boolean? . ,(lambda (x y) (and (eq? x #t) (eq? y #f))))
     (,number?  . ,<)
     (,symbol?  . ,symbol<?)
     (,list?    . ,list<?))))
