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

(declare (usual-integrations))

;;; This procedure was dredged from the dark recesses of Edwin.  Many
;;; computer scientists would claim that it should never have been
;;; allowed to see the light of day.

(define (procedure-argl proc #!optional default-argl)
  "Returns the arg list of PROC.
   Grumbles if PROC is an undocumented primitive."
  (if (primitive-procedure? proc)
      (let ((doc-string
	     (primitive-procedure-documentation proc)))
	(if doc-string
	    (let ((newline
		   (string-find-next-char doc-string #\newline)))
	      (if newline
		  (string-head doc-string newline)
		  doc-string))
	    (string-append
	     (write-to-string proc)
	     " has no documentation string.")))
      (let ((code (procedure-lambda proc)))
	(if code
	    (lambda-components* code
	      (lambda (name required optional rest body)
		name body
		(append required
		 (if (null? optional) '() `(#!OPTIONAL ,@optional))
		 (if rest `(#!REST ,rest) '()))))
	    (if (default-object? default-argl)
		"No debugging information available for this procedure."
		default-argl)))))

;;; Magic!

(define (make-lambda bvl use-env generate-body)
  (capture-syntactic-environment
   (lambda (transform-env)
     (close-syntax
      `(,(close-syntax 'lambda transform-env)
	,bvl
	,(capture-syntactic-environment
	  (lambda (use-env*)
	    (close-syntax (generate-body use-env*)
			  transform-env))))
      use-env))))
