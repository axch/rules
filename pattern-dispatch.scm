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

;;; A pattern directed operator is a collection of rules, one of which
;;; is expected to match any datum that the operator may be given.
;;; The operator tries the rules in order until the first matches, and
;;; returns the value given by that one; if none match, it errors out.

(define (make-pattern-operator rules)
  (define (operator self . arguments)
    (define (succeed value fail) value)
    (define (fail)
      (error "No applicable operations" self arguments))
    (try-rules arguments (reverse (entity-extra self)) succeed fail))
  (make-entity operator rules))

(define (pattern-dispatch . rules)
  (make-pattern-operator rules))

(define (try-rules data rules succeed fail)
  (let ((token (list 'fail)))
    (let per-rule ((rules rules))
      (if (null? rules)
          (fail)
          (let ((answer ((car rules) data token)))
            (if (eq? answer token)
                (per-rule (cdr rules))
                (succeed answer (lambda () (per-rule (cdr rules))))))))))

(define (attach-rule! operator rule)
  (set-entity-extra! operator
   (cons rule (entity-extra operator))))
