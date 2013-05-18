;;; This file is part of Rules, a pattern matching, pattern dispatch,
;;; and term rewriting system for MIT Scheme.
;;; Copyright 2010 Alexey Radul.
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

;;;; Loading Rules

(define (self-relatively thunk)
  (if (current-eval-unit #f)
      (with-working-directory-pathname
       (directory-namestring (current-load-pathname))
       thunk)
      (thunk)))

(define (load-relative filename)
  (self-relatively (lambda () (load filename))))

(load-relative "support/auto-compilation")
(load-relative-compiled "support/utils")
(load-relative-compiled "support/eq-properties")
(if (lexical-unbound? (the-environment) 'make-generic-operator)
    (load-relative-compiled "support/ghelper"))
(load-relative-compiled "matcher")

(define (rule-memoize f) f)

(load-relative-compiled "pattern-directed-invocation")
(load-relative-compiled "simplification")
(load-relative-compiled "simplifiers")
