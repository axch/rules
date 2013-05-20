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

;;; A rule, in this terminology, is a pattern and a handler.  The
;;; pattern determines the applicability of the rule and the match
;;; bindings that enable it, and the handler can compute an arbitrary
;;; value from them.  Once constructed, a rule is a procedure that
;;; accepts a datum, and returns either the datum if the pattern
;;; doesn't match or the value of the handler when applied to the
;;; dictionary if it does.  The input datum is used as the sentinel
;;; value for failure because in the context of term rewriting,
;;; succeeding with the input as the answer is equivalent to failing.

;;; The handler can reject a putative match by returning #f, which
;;; causes backtracking into the matcher, and may cause the handler to
;;; be called again with different bindings.  If the handler always
;;; returns #f, the rule may fail even though its pattern matched.
;;; The handler can force success with an arbitrary object (including
;;; #f) by returning the result of calling `succeed' on the value to
;;; return.

;;; For situations where it is desirable to distinguish rule failure
;;; from success with the input, the rule procedure accepts an
;;; optional second argument to use as a token to indicate failure.
;;; If the second argument is given, it is returned on failure, and
;;; the input datum (along with all other objects) indicates success.
;;; The token is not stored across invocations and is not passed to
;;; handlers.  It is up to the caller to make sure that this token is
;;; unique.

(define (make-rule pattern handler)
  (if (accepts-variables? handler)
      (make-rule pattern (accept-dictionary
			  handler (match:pattern-names pattern)))
      (let ((combinator (match:->combinators pattern)))
	(lambda (data #!optional fail-token)
	  (if (default-object? fail-token)
	      (set! fail-token data))
	  (interpret-success
           (or (combinator data '() handler)
               ;; Not fail-token because it might be a success object
               (make-success fail-token)))))))

;;; F is expected to be a procedure that binds the variables that
;;; appear in the match and uses them somehow.  This converts it into
;;; a success procedure that accepts the match dictionary.  Does not
;;; deal with optional and rest arguments to f.

(define (accept-dictionary f #!optional default-argl)
  (let ((argl (procedure-argl f default-argl)))
    (accepts-dictionary!
     (lambda (dict)
       (define (matched-value name)
	 (dict:value
	  (or (dict:lookup name dict)
	      (error "Handler asked for unknown name"
		     name dict))))
       (let ((argument-list (map matched-value argl)))
         (apply f argument-list))))))

(define-structure success
  value)

(define succeed make-success)

(define (interpret-success thing)
  (if (success? thing)
      (success-value thing)
      thing))

(define (accepts-variables? thing)
  (not (accepts-dictionary? thing)))

(define (accepts-dictionary? thing)
  (eq-get thing 'accepts-dictionary))

(define (accepts-dictionary! thing)
  (eq-put! thing 'accepts-dictionary #t)
  thing)

;;; The RULE macro is convenient syntax for writing rules.  A rule is
;;; written as a quoted pattern and an expression.  If the pattern
;;; matches, the expression will be evaluated in an environment that
;;; includes the bindings of the pattern variables.  If the expression
;;; returns #f, that will cause the pattern matcher to backtrack.
(define-syntax rule
  (sc-macro-transformer
   (lambda (form use-env)
     (let ((pattern (cadr form))
	   (handler-body (caddr form)))
       `(make-rule 
	 ,(close-syntax pattern use-env)
	 ,(compile-handler handler-body use-env
			   (match:pattern-names pattern)))))))

(define (compile-handler form env names)
  ;; See magic below
  (make-lambda names env
    (lambda (env*) (close-syntax form env*))))

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
#|
 (pp (syntax '(rule '(* (? a) (? b))
		    (and (expr<? a b)
                         `(* ,a ,b)))
             (the-environment)))

; (make-rule '(* (? a) (? b))
;  (lambda (b a)
;    (and (expr<? a b)
;         (list '* a b))))
;Unspecified return value
|#

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
