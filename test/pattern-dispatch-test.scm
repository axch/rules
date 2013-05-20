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

(in-test-group
 pattern-dispatch
 
 (define-test (quad-test)
   (interaction
    (define quad
      (pattern-dispatch
       (rule 
        `((? a) (? b) (? c) (? x))
        (+ (* a (expt x 2))
           (* b x)
           c))

       (rule
        `((? a) (? x) (? x) + (? b) (? x) + (? c))
        (+ (* a (expt x 2))
           (* b x)
           c))))

    (quad 1 2 3 4)
    (produces 27)

    (quad 1 4 4 '+ 2 4 '+ 3)
    (produces 27)))

 (define-test (frob-test)
   (interaction
    (define frob
      (pattern-dispatch))

    (attach-rule! frob
     (rule
      '(a (?? x) (?? y) (?? x) c)
      (and (<= (length y) 2)
	   y)))

    (apply frob '(a b b b b b b c))
    (produces '(b b))))

 (define-test (factorial-1)
   (interaction
    (define factorial (make-pattern-operator '()))

    (attach-rule! factorial (rule '(0) 1))

    (attach-rule! factorial
		  (rule `((? n ,positive?))
			(* n (factorial (- n 1)))))

    (factorial 10)
    (produces 3628800)))
 
 (define-test (factorial-2)
   (interaction
    (define factorial (make-pattern-operator '()))

    (attach-rule! factorial
		  (make-rule '(0) (lambda () 1)))

    (attach-rule! factorial
		  (make-rule '((? n))
			     (lambda (n) (* n (factorial (- n 1))))))

    (factorial 10)
    (produces 3628800)))

)
