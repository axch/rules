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

;;;; Matcher based on match combinators, CPH/GJS style.
;;;     Idea is in Hewitt's PhD thesis (1969).

;;; There are match procedures that can be applied to data items.  A
;;; match procedure either accepts or rejects the data it is applied
;;; to.  Match procedures can be combined to apply to compound data
;;; items.

;;; A match procedure takes a data item, a dictionary, and a success
;;; continuation.  The dictionary accumulates the assignments of match
;;; variables to values found in the data.  The success continuation
;;; takes the new dictionary as an argument.  If a match procedure
;;; fails it returns #f.

;;; Primitive match procedures

;; Match a pattern constant (by eqv?)
(define (match:eqv pattern-constant)
  (define (eqv-match data dictionary succeed)
    (and (eqv? data pattern-constant)
	 (succeed dictionary)))
  eqv-match)

;; Match a pattern variable, as long as the datum satisfies all the
;; restriction predicates.
(define (match:element variable restrictions)
  (define (ok? datum)
    (every (lambda (restriction)
	     (restriction datum))
	   restrictions))
  (define (element-match data dictionary succeed)
    (and (ok? data)
	 (let ((vcell (dict:lookup variable dictionary)))
	   (if vcell
	       (and (equal? (dict:value vcell) data)
		    (succeed dictionary))
	       (succeed (dict:bind variable data dictionary))))))
  element-match)

;;; The dictionary

(define (dict:bind variable data-object dictionary)
  (cons (list variable data-object) dictionary))

(define (dict:lookup variable dictionary)
  (assq variable dictionary))

;; I am choosing to have the dictionary hide the fact that segments
;; have a special representation.
(define (dict:value vcell)
  (interpret-segment (cadr vcell)))

(define (dictionary->entry-list dict)
  (map (lambda (entry)
	 (list (car entry) (interpret-segment (cadr entry))))
       dict))

;;; Segment variables introduce some additional trouble.  Unlike other
;;; matchers, a segment variable is not tested against a fixed datum
;;; that it either matches or not, but against a list such that it may
;;; match any prefix.  This means that in general, segment variables
;;; must search, trying one match and possibly backtracking.  There
;;; are, however, two circumstances when the search can be avoided: if
;;; the variable is already bound, the bound value needs to be checked
;;; against the data, but no guessing as to how much data to consume
;;; is required.  Also, if the segment variable is the last matcher in
;;; its enclosing list (which actually happens quite often!) then the
;;; list matcher already knows how much data must be matched, and no
;;; search is needed.

;;; How should the bound values of segment variables be represented?
;;; The naive approach would just be to copy the segment of the list
;;; that is bound --- that is, notionally, the value, after all.
;;; However, this introduces an unnecessary linear slowdown in the
;;; case when the current guess as to the length of the segment is
;;; proven false without needing to examine the bound variable, for
;;; instance if the next matcher doesn't match.  Therefore, segment
;;; variables should be represented as pointers to the beginning and
;;; end of the data in the segment, whence the actual list value can
;;; be derived when needed.

;;; Finally, the list matcher needs to behave differently when giving
;;; data to a segment as opposed to a regular matcher: the segment
;;; should be given the whole (remaining) list in contrast with just
;;; the first data item for the regular matcher, and the segment may
;;; (in fact, probably will) consume more than one element, so it
;;; needs to pass the data remaining to its success continuation.  All
;;; matchers could be made uniform by giving them all the interface of
;;; the segment matcher, but I think it's less ugly to take advantage
;;; of the fact that segment matchers can only occur as submatchers of
;;; list matchers and make their interface special.

;;; Segments

(define-structure (segment (constructor make-segment (head tail)) safe-accessors)
  head
  tail
  (body-cache #f))

(define (segment-body segment)
  (define (compute-segment-body)
    (if (null? tail)
	(segment-head segment)
	(let loop ((head (segment-head segment))
		   (tail (segment-tail segment)))
	  (cond ((eq? head tail)
		 '())
		((null? head)
		 (error "Tail pointer did not point into head's list" segment))
		(else
		 (cons (car head) (loop (cdr head) tail)))))))
  (if (segment-body-cache segment)
      (segment-body-cache segment)
      (let ((answer (compute-segment-body)))
	(set-segment-body-cache! segment answer)
	answer)))

(define (interpret-segment thing)
  (if (segment? thing)
      (segment-body thing)
      thing))


(define (match:segment variable)
  (define (segment-match data dictionary succeed)
    (and (list? data)
	 (let ((vcell (dict:lookup variable dictionary)))
	   (if vcell
	       (let lp ((data data)
			(pattern (dict:value vcell)))
		 (cond ((pair? pattern)
			(if (and (pair? data)
				 (equal? (car data) (car pattern)))
			    (lp (cdr data) (cdr pattern))
			    #f))
		       ((not (null? pattern)) #f)
		       (else (succeed dictionary data))))
	       (let lp ((tail data))
		 (or (succeed (dict:bind variable
					 (make-segment data tail)
					 dictionary)
			      tail)
		     (and (pair? tail)
			  (lp (cdr tail)))))))))
  (segment-matcher! segment-match)
  segment-match)

(define (match:list . match-combinators)
  (define (list-match data dictionary succeed)
    (let lp ((data data)
	     (matchers match-combinators)
	     (dictionary dictionary))
      (define (try-element submatcher)
	(submatcher (car data) dictionary
	  (lambda (new-dictionary)
	    (lp (cdr data) (cdr matchers) new-dictionary))))
      (define (try-segment submatcher)
	(submatcher data dictionary
          (lambda (new-dictionary #!optional remaining-data)
	    (if (default-object? remaining-data)
		(set! remaining-data '()))
	    (lp remaining-data (cdr matchers) new-dictionary))))
      (cond ((pair? matchers)
	     (if (segment-matcher? (car matchers))
		 (try-segment (car matchers))
		 (and (pair? data) (try-element (car matchers)))))
	    ((pair? data) #f)
	    ((null? data)
	     (succeed dictionary))
	    (else #f))))
  list-match)

;;; Sticky notes

(define (segment-matcher! thing)
  (eq-put! thing 'segment-matcher #t)
  thing)
(define (segment-matcher? thing)
  (eq-get thing 'segment-matcher))

;;; Syntax of matching is determined here.

(define (match:element? pattern)
  (and (pair? pattern)
       (eq? (car pattern) '?)))

(define (match:segment? pattern)
  (and (pair? pattern)
       (eq? (car pattern) '??)))

(define (match:variable-name pattern) (cadr pattern))
(define (match:restrictions pattern) (cddr pattern))

(define (match:list? pattern)
  (and (list? pattern)
       (or (null? pattern)
	   (not (memq (car pattern) '(? ??))))))

(define match:->combinators
  (make-generic-operator 1 'match:->combinators match:eqv))

(define (new-pattern-syntax! predicate interpreter)
  (defhandler match:->combinators
    interpreter
    predicate))

(defhandler match:->combinators
  (lambda (pattern) pattern)
  procedure?)

(defhandler match:->combinators
  (lambda (pattern)
    (match:element
     (match:variable-name pattern)
     (match:restrictions pattern)))
  match:element?)

(defhandler match:->combinators
  (lambda (pattern) (match:segment (match:variable-name pattern)))
  match:segment?)

;;; list-pattern->combinators is complicated because it detects the
;;; last submatcher in the pattern and, if it's a segment variable,
;;; arranges for it to avoid its search.
(define (list-pattern->combinators pattern)
  (define (last-list-submatcher subpattern)
    (if (match:segment? subpattern)
	(segment-matcher! (match:element (match:variable-name subpattern) '()))
	(match:->combinators subpattern)))
  (if (null? pattern)
      (match:eqv '())
      (apply match:list
	     (append (map match:->combinators (except-last-pair pattern))
		     (list (last-list-submatcher (car (last-pair pattern))))))))

(defhandler match:->combinators list-pattern->combinators match:list?)

(define (matcher pattern)
  (first-dictionary (match:->combinators pattern)))

(define (first-dictionary matcher)
  (lambda (datum)
    (matcher
     datum '()
     (lambda (dict)
       (dictionary->entry-list dict)))))

(define (for-each-matcher pattern)
  (for-each-dictionary (match:->combinators pattern)))

(define (for-each-dictionary matcher)
  (lambda (datum f)
    (matcher
     datum '()
     (lambda (dict)
       (f (dictionary->entry-list dict))
       #f))))

(define (all-results-matcher pattern)
  (all-dictionaries (match:->combinators pattern)))

(define (all-dictionaries matcher)
  (lambda (datum)
    (let ((results '()))
      ((for-each-dictionary matcher)
       datum
       (lambda (dict)
	 (set! results (cons dict results))))
      (reverse results))))

#|
 ((match:->combinators '(a ((? b) 2 3) 1 c))
  '(a (1 2 3) 1 c)
  '()
   (lambda (x) `(succeed ,x)))
 ;Value: (succeed ((b 1)))

 ((match:->combinators '(a ((? b) 2 3) (? b) c))
  '(a (1 2 3) 2 c)
  '()
   (lambda (x) `(succeed ,x)))
 ;Value: #f

 ((match:->combinators '(a ((? b) 2 3) (? b) c))
  '(a (1 2 3) 1 c)
  '()
   (lambda (x) `(succeed ,x)))
 ;Value: (succeed ((b 1)))


 ((match:->combinators '(a (?? x) (?? y) (?? x) c))
  '(a b b b b b b c)
  '()
  (lambda (x)
    (pp `(succeed ,x))
    #f))
 (succeed ((y (b b b b b b)) (x ())))
 (succeed ((y (b b b b)) (x (b))))
 (succeed ((y (b b)) (x (b b))))
 (succeed ((y ()) (x (b b b))))
 ;Value: #f

 ((matcher '(a ((? b) 2 3) (? b) c))
  '(a (1 2 3) 1 c))
 ;Value: ((b 1))
|#

;;; Nice pattern inspection procedure that will be used by the
;;; pattern-directed invocation system.

(define (match:pattern-names pattern)
  (let loop ((pattern pattern) (names '()))
    (cond ((or (match:element? pattern)
               (match:segment? pattern))
           (let ((name
		  (match:variable-name pattern)))
             (if (memq name names)
                 names
                 (cons name names))))
          ((list? pattern)
           (let elt-loop
	       ((elts pattern) (names names))
             (if (pair? elts)
                 (elt-loop (cdr elts)
			   (loop (car elts) names))
                 names)))
          (else names))))

#|
 (match:pattern-names '((? a) (?? b)))
 ;Value: (b a)
|#
