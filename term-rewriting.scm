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

;;; Make a term-rewriting system from a list of rules.  This is a
;;; facade for a rule application strategy from the combinators below.

(define (term-rewriting . rules) (rule-simplifier rules))
(define (rule-simplifier the-rules)
  (iterated-on-subexpressions (rule-list the-rules)))

;;;; Rule combinators

;;; Various patterns of rule application captured as combinators that
;;; take rules and produce rules (to wit, procedures that accept one
;;; input and return the result of transforming it, where returning
;;; the input itself signals match failure).

;; Apply several rules in series, returning the first success.
(define ((rule-list rules) data)
  (let per-rule ((rules rules))
    (if (null? rules)
	data
	(let ((answer ((car rules) data)))
	  (if (eqv? data answer)
	      (per-rule (cdr rules))
	      answer)))))

;; Apply several rules in series, threading the results.
(define ((in-order . the-rules) datum)
  (let loop ((datum datum) (the-rules the-rules))
    (if (null? the-rules)
        datum
        (loop ((car the-rules) datum) (cdr the-rules)))))
;; Apply one rule repeatedly until it doesn't match anymore.
(define ((iterated the-rule) data)
  (let loop ((data data) (answer (the-rule data)))
    (if (eqv? answer data)
        answer
        (loop answer (the-rule answer)))))

;; Apply one rule to all subexpressions of the input, bottom-up.
(define (on-subexpressions the-rule)
  (define (on-expr expression)
    (let ((subexpressions-done (try-subexpressions on-expr expression)))
      (the-rule subexpressions-done)))
  on-expr)

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
  (define (on-expr expression)
    (let ((subexpressions-done (try-subexpressions on-expr expression)))
      (let ((answer (the-rule subexpressions-done)))
	(if (eqv? answer subexpressions-done)
	    answer
	    (on-expr answer)))))
  on-expr)

;; Iterate one rule to convergence on all subexpressions of the input,
;; applying it on the way down as well as back up.
(define (top-down the-rule)
  (define (on-expr expression)
    (let ((answer (the-rule expression)))
      (if (eqv? answer expression)
          (let ((subexpressions-done (try-subexpressions on-expr expression)))
            (let ((answer (the-rule subexpressions-done)))
              (if (eqv? answer subexpressions-done)
                  answer
                  (on-expr answer))))
          (on-expr answer))))
  on-expr)
