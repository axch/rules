(declare (usual-integrations))

;;; RULE-SIMPLIFIER makes term-rewriting systems from collections of
;;; rules.  Given a collection of rules, the term-rewriting system
;;; will apply them repeatedly to all possible subexpressions of the
;;; given expression, and then to the expression itself, until no
;;; further rules match.  Of course, the rules in question should be
;;; arranged so as to ensure that this process terminates in a
;;; reasonable amount of time.

(define (rule-simplifier the-rules)
  (let ((unique-object (list)))
    (define (make-unfakeable-box thing)
      (cons unique-object thing))
    (define (unfakeable-box? thing)
      (and (pair? thing)
	   (eq? (car thing) unique-object)))
    (define unfakeable-contents cdr)
    (define (compute-simplify-expression expression)
      (let ((subexpressions-simplified
	     (if (list? expression)
		 (map simplify-expression expression)
		 expression)))
	(let ((answer (try-rules
		       subexpressions-simplified the-rules
		       (lambda (result fail) (make-unfakeable-box result))
		       (lambda () #f))))
	  (cond ((unfakeable-box? answer)
		 (simplify-expression (unfakeable-contents answer)))
		((not answer)
		 subexpressions-simplified)
		(else
		 (simplify-expression answer))))))
    (define simplify-expression (rule-memoize compute-simplify-expression))
    simplify-expression))

(define (list<? x y)
  (let ((nx (length x)) (ny (length y)))
    (cond ((< nx ny) #t)
	  ((> nx ny) #f)
	  (else
	   (let lp ((x x) (y y))
	     (cond ((null? x) #f)	; same
		   ((expr<? (car x) (car y)) #t)
		   ((expr<? (car y) (car x)) #f)
		   (else (lp (cdr x) (cdr y)))))))))

(define expr<?
  (make-entity
   (lambda (self x y)
     (let per-type ((types (entity-extra self)))
       (if (null? types)
	   (error "Unknown expression type -- expr<?" x y)
	   (let ((predicate? (caar types))
		 (comparator (cdar types)))
	     (cond ((predicate? x)
		    (if (predicate? y)
			(comparator x y)
			#t))
		   ((predicate? y) #f)
		   (else (per-type (cdr types))))))))
   `((,null?    . ,(lambda (x y) #f))
     (,boolean? . ,(lambda (x y) (and (eq? x #t) (eq? y #f))))
     (,number?  . ,<)
     (,symbol?  . ,symbol<?)
     (,list?    . ,list<?))))

(define (iterate-until-stable simplifier)
  (define (simp exp)
    (let ((newexp (simplifier exp)))
      (if (equal? exp newexp)
	  exp
	  (simp newexp))))
  simp)

(define compose
  (if (lexical-unbound? (the-environment) 'compose)
      (lambda fs
	(lambda (arg)
	  (let loop ((fs fs))
	    (if (null? fs)
		arg
		((car fs) (loop (cdr fs)))))))
      compose))
