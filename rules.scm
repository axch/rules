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
;;; The token is not stored and is not passed to handlers.  It is up
;;; to the caller to make sure that this token is unique.

(define (make-rule pattern handler)
  (if (user-handler? handler)
      (make-rule pattern (user-handler->system-handler
			  handler (match:pattern-names pattern)))
      (let ((combinator (match:->combinators pattern)))
	(lambda (data #!optional fail-token)
	  (if (default-object? fail-token)
	      (set! fail-token data))
	  (interpret-success
           (or (combinator data '() handler)
               ;; Otherwise would screw up if the data was a success object
               (make-success fail-token)))))))

;;; The user-handler is expected to be a procedure that binds the
;;; variables that appear in the match and uses them somehow.  This
;;; converts it into a combinator that accepts the match dictionary,
;;; and success and failure continuations.  Does not deal with
;;; optional and rest arguments in the handler.

(define (user-handler->system-handler user-handler #!optional default-argl)
  (let ((handler-argl (procedure-argl user-handler default-argl)))
    (system-handler!
     (lambda (dict)
       (define (matched-value name)
	 (dict:value
	  (or (dict:lookup name dict)
	      (error "Handler asked for unknown name"
		     name dict))))
       (let* ((argument-list (map matched-value handler-argl)))
         (apply user-handler argument-list))))))

(define-structure success
  value)

(define succeed make-success)

(define (interpret-success thing)
  (if (success? thing)
      (success-value thing)
      thing))

(define (user-handler? thing)
  (not (system-handler? thing)))

(define (system-handler? thing)
  (eq-get thing 'system-handler))

(define (system-handler! thing)
  (eq-put! thing 'system-handler #t)
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
  ;; See magic in utils.scm
  (make-lambda names env
    (lambda (env*) (close-syntax form env*))))

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
