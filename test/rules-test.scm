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

(in-test-group
 rules

 (let ((the-rule (rule '(foo (? x)) (succeed x))))
   (define-each-check
     (= 1 (the-rule '(foo 1)))
     (success? (the-rule `(foo ,(make-success 2))))
     (= 3 (success-value (the-rule `(foo ,(make-success 3)))))
     (success? (the-rule (make-success 4))) ; Should return the input, not 4
     )))
