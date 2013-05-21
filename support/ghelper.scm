;;; This file is a supporting library for Rules, an extensible pattern
;;; matching, pattern dispatch, and term rewriting system for MIT
;;; Scheme.
;;; Copyright Gerald Jay Sussman.
;;;
;;; This program is free software; you can redistribute it and/or
;;; modify it under the terms of the GNU Affero General Public License
;;; as published by the Free Software Foundation; either version 3 of
;;; the License, or (at your option) any later version.
;;; 
;;; This code is distributed in the hope that it will be useful,
;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.
;;; 
;;; You should have received a copy of the GNU Affero General Public
;;; License along with Rules; if not, see
;;; <http://www.gnu.org/licenses/>.

;;;;           Most General Generic-Operator Dispatch

(declare (usual-integrations))

;;; Generic-operator dispatch is implemented here by a discrimination
;;; list, where the arguments passed to the operator are examined by
;;; predicates that are supplied at the point of attachment of a
;;; handler (by ASSIGN-OPERATION).

;;; To be the correct branch all arguments must be accepted by
;;; the branch predicates, so this makes it necessary to
;;; backtrack to find another branch where the first argument
;;; is accepted if the second argument is rejected.  Here
;;; backtracking is implemented by OR.

;;; The discrimination list has the following structure: it is a
;;; possibly improper alist whose "keys" are the predicates that are
;;; applicable to the first argument.  If a predicate matches the
;;; first argument, the cdr of that alist entry is a discrimination
;;; list for handling the rest of the arguments.  If a discrimination
;;; list is improper, then the cdr at the end of the backbone of the
;;; alist is the default handler to apply (all remaining arguments are
;;; implicitly accepted).

(define (make-generic-operator arity #!optional name default-operation)
  (guarantee-exact-positive-integer arity 'make-generic-operator)
  (if (not (fix:fixnum? arity))
      (error:bad-range-argument arity 'make-generic-operator))
  (if (not (default-object? name))
      (guarantee-symbol name 'make-generic-operator))
  (if (not (default-object? default-operation))
      (guarantee-procedure-of-arity default-operation
				    arity
				    'make-generic-operator))
  (define (find-branch tree arg win)
    (let loop ((tree tree))
      (cond ((pair? tree)
	     (or (and ((caar tree) arg)
		      (win (cdar tree)))
		 (loop (cdr tree))))
	    ((null? tree)
	     #f)
	    (else tree))))
  (define (identity x) x)
  (let ((record (make-operator-record arity)))
    (define (general-find-handler arguments)
      (let loop ((tree (operator-record-tree record))
		 (args arguments))
	(find-branch tree (car args)
		     (if (pair? (cdr args))
			 (lambda (branch)
			   (loop branch (cdr args)))
			 identity))))
    (define operator
      (case arity
	((1)
	 (lambda (arg)
	   ((find-branch (operator-record-tree record) arg identity)
	    arg)))
	((2)
	 (lambda (arg1 arg2)
	   ((find-branch (operator-record-tree record) arg1
			 (lambda (branch)
			   (find-branch branch arg2 identity)))
	    arg1 arg2)))
	(else
	 (lambda arguments
	   (if (not (fix:= (length arguments) arity))
	       (error:wrong-number-of-arguments operator arity arguments))
	   (apply (general-find-handler arguments)
		  arguments)))))
    (set! default-operation
      (if (default-object? default-operation)
	  (named-lambda (no-handler . arguments)
	    (no-way-known operator name arguments))
	  default-operation))
    (set-operator-record-finder! record general-find-handler)
    (set-operator-record! operator record)
    (if (not (default-object? name))
	(set-operator-record! name record))
    (assign-operation operator default-operation)
    operator))

(define *generic-operator-table*
  (make-eq-hash-table))

(define (get-operator-record operator)
  (hash-table/get *generic-operator-table* operator #f))

(define (set-operator-record! operator record)
  (hash-table/put! *generic-operator-table* operator record))

(define (make-operator-record arity) (list arity #f '()))
(define (operator-record-arity record) (car record))
(define (operator-record-finder record) (cadr record))
(define (set-operator-record-finder! record finder) (set-car! (cdr record) finder))
(define (operator-record-tree record) (caddr record))
(define (set-operator-record-tree! record tree) (set-car! (cddr record) tree))

(define (generic-operator-arity operator)
  (let ((record (get-operator-record operator)))
    (if record
        (operator-record-arity record)
        (error "Not an operator:" operator))))

;;; The way the binding and searching interact is that the handler
;;; this assigns ends up being highest priority, unless its predicate
;;; list is a proper prefix of a previously assigned predicate list.
;;; In that case, the new handler is provably less specific than the
;;; old one, so does not take priority.
(define (assign-operation operator handler . argument-predicates)
  (let ((record (get-operator-record operator))
	(arity (length argument-predicates)))
    (if record
	(begin
	  (if (not (fix:<= arity (operator-record-arity record)))
	      (error "Incorrect operator arity:" operator))
	  (bind-in-tree
	   argument-predicates
	   handler
	   (operator-record-tree record)
	   (lambda (new)
	     (set-operator-record-tree! record new))))
	(error "Assigning a handler to an undefined generic operator"
	       operator)))
  operator)

(define defhandler assign-operation)

(define (bind-in-tree keys handler tree replace!)
  (let loop ((keys keys) (tree tree) (replace! replace!))
    (if (pair? keys)
	;; There are argument predicates left
	(let find-key ((tree* tree))
	  (if (pair? tree*)
	      (if (eq? (caar tree*) (car keys))
		  ;; There is already some discrimination list keyed
		  ;; by this predicate: adjust it according to the
		  ;; remaining keys
		  (loop (cdr keys)
			(cdar tree*)
			(lambda (new)
			  (set-cdr! (car tree*) new)))
		  (find-key (cdr tree*)))
	      (let ((better-tree
		     (cons (cons (car keys) '()) tree)))
		;; There was no entry for the key I was looking for.
		;; Create it at the head of the alist and try again.
		(replace! better-tree)
		(loop keys better-tree replace!))))
	;; Ran out of argument predicates
	(if (pair? tree)
	    ;; There is more discrimination list here, because my
	    ;; predicate list is a proper prefix of the predicate list
	    ;; of some previous assign-operation.  Insert the handler
	    ;; at the end, causing it to implicitly accept any
	    ;; arguments that fail all available tests.
	    (let ((p (last-pair tree)))
	      (if (not (null? (cdr p)))
		  (warn "Replacing a default handler:" (cdr p) handler))
	      (set-cdr! p handler))
	    (begin
	      ;; There is no discrimination list here, because my
	      ;; predicate list is not the proper prefix of that of
	      ;; any previous assign-operation.  This handler becomes
	      ;; the discrimination list, accepting further arguments
	      ;; if any.
	      (if (not (null? tree))
		  (warn "Replacing a handler:" tree handler))
	      (replace! handler))))))

;;; When in doubt, dike it out. -- Greenblatt
#|
  ;;; Failures make it to here.  Time to DWIM, with apologies to Warren
  ;;; Teitelman.  Can we look at some argument as a default numerical
  ;;; expression?

  (define (no-way-known operator name arguments)
    (let ((new-arguments (map dwim arguments)))
      (if (equal? arguments new-arguments)
	  (error "Generic operator inapplicable:" operator name arguments))
      (apply operator new-arguments)))

  (define (dwim argument)
    (if (pair? argument)
	(cond ((memq (car argument) type-tags)
	       argument)
	      ((memq (car argument) generic-numerical-operators)
	       (apply (eval (car argument) generic-environment)
		      (cdr argument)))
	      (else
	       argument))
	argument))
|#
(define (no-way-known operator name arguments)
  (error "Generic operator inapplicable:" name arguments))

;;; A debugging aid

(define (get-handler operator . arguments)
  (let ((record (get-operator-record operator)))
    (if record
	(let ((handler-finder (operator-record-finder record)))
	  (handler-finder arguments))
	(error "Not a generic operator" operator))))

#|
(get-handler '+ (up 1 2) (up 3 4))
#| structure+structure |#
|#
