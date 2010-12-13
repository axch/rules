(declare (usual-integrations))

(define (rule-simplifier the-rules)
  (define (simplify-expression expression)
    (let ((subexpressions-simplified
	   (if (list? expression)
	       (map simplify-expression expression)
	       expression)))
      ((iterate-until-stable
	(lambda (subexpressions-simplified)
	  (try-rules subexpressions-simplified the-rules
		     (lambda (result fail) (succeed result))
		     (lambda () subexpressions-simplified))))
       subexpressions-simplified)))
  (rule-memoize simplify-expression))

(define (try-rules data rules succeed fail)
  (let per-rule ((rules rules))
    (if (null? rules)
	(fail)
	((car rules) data succeed
	 (lambda ()
	   (per-rule (cdr rules)))))))

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
   `((,null?   . ,(lambda (x y) #f))
     (,number? . ,<)
     (,symbol? . ,symbol<?)
     (,list?   . ,list<?))))

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
