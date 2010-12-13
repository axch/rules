(in-test-group
 simplification

 (define-each-check
   (equal?
    '(+ (* w x) (* x y) (* x z))
    (simplify-algebra '(* (+ y (+ z w)) x)))

   (equal?
    '(* 3 x)
    (simplify-algebra '(+ (* 3 (+ x 1)) -3)))

   (equal? 0 (simplify-algebra '(+)))
   (equal? #t (simplify-logic '(and)))
   (equal? #f (simplify-logic '(or)))
   (equal?
   '(* 3 x)
   (simplify-algebra '(+ (* 3 (+ x 1)) -3
			 (* y (+ 1 2 -3) z))))
   (equal?
   '(/ (* r1 r2) (+ r1 r2))
   ((compose simplify-quotient ->quotient-of-sums)
    '(/ 1 (+ (/ 1 r1) (/ 1 r2))))))

 (define associate-addition
   (rule '(+ (? a) (+ (? b) (? c)))
	 `(+ (+ ,a ,b) ,c)))

 (define-test (rule-smoke)
   (assert-equal
    '(+ (+ 2 3) 4)
    (associate-addition '(+ 2 (+ 3 4)))))

 (define-test (rule-that-can-refuse)
   (define sort-numbers
     (rule '(+ (? a) (? b))
	   (and (> a b)
		`(+ ,b ,a))))
   (assert-equal
    '(+ 2 3)
    (sort-numbers '(+ 3 2)))
   (assert-false (sort-numbers '(+ 2 3))))
 (define-test (parametric-rule-smoke)
   (assert-equal
    #f
    (simplify-ors '(or))))

 (define-test (negation-pushing-smoke)
   (assert-equal
    '(and (not a) (not b))
    (simplify-negations '(not (or a b)))))

 (define-test (or-pushing)
   (assert-equal
    '(and (or (not (< -1/4 (- x2 x1)))
	      (and (not (< (- x2 x1) 1/4)) (not (< (- x2 x1) 0)))
	      (and (< (- x2 x1) 1/4) (not (< (- x2 x1) 0)))
	      (and (< -1/4 (- x2 x1)) (< (- x2 x1) 0)))
	  (or (< (- x2 x1) 0)
	      (and (not (< (- x2 x1) 1/4)) (not (< (- x2 x1) 0)))
	      (and (< (- x2 x1) 1/4) (not (< (- x2 x1) 0)))
	      (and (< -1/4 (- x2 x1)) (< (- x2 x1) 0))))
    (push-or-through-and
     '(or (and (not (< -1/4 (- x2 x1)))
	       (< (- x2 x1) 0))
	  (and (not (< (- x2 x1) 1/4))
	       (not (< (- x2 x1) 0)))
	  (and (< (- x2 x1) 1/4)
	       (not (< (- x2 x1) 0)))
	  (and (< -1/4 (- x2 x1))
	       (< (- x2 x1) 0))))))

 (define-test (cnf)
   (assert-true
    (->conjunctive-normal-form
     '(or (and (not (< -1/4 (- x2 x1)))
	       (< (- x2 x1) 0))
	  (and (not (< (- x2 x1) 1/4))
	       (not (< (- x2 x1) 0)))
	  (and (< (- x2 x1) 1/4)
	       (not (< (- x2 x1) 0)))
	  (and (< -1/4 (- x2 x1))
	       (< (- x2 x1) 0))))))

 (define-test (more-cnf)
   (assert-equal
    '(and (or a b)
	  (or a (not b))
	  (or b (not a))
	  (or (not a) (not b)))
    (->conjunctive-normal-form
     '(and (or a b)
	   (or a (not b))
	   (or (not a) b)
	   (or (not a) (not b))))))

 (define-test (scanning-for-duplicates)
   (define find-consecutive-dups
     (rule '((?? stuff1) (? x) (? x) (?? stuff2))
	   `(,@stuff1 ,x ,@stuff2)))
   (let ((items (iota 10))) ; linear
     (assert-equal
      items
      ((rule-simplifier (list find-consecutive-dups))
       items))))

 (define-test (removing-duplicates)
   (define find-consecutive-dups
     (rule '((?? stuff1) (? x) (? x) (?? stuff2))
	   `(,@stuff1 ,x ,@stuff2)))
   (let ((items (make-list 10 'foo))) ; TODO quadratic + gc pressure
     (assert-equal
      '(foo)
      ((rule-simplifier (list find-consecutive-dups))
       items))))

 (define-test (removing-distant-duplicates)
   (define find-consecutive-dups
     (rule '((?? stuff1) (? x) (? x) (?? stuff2))
	   `(,@stuff1 ,x ,@stuff2)))
   (let* ((len 10) ; TODO quadratic + gc pressure
	  (items (append (iota len) (make-list len 'foo))))
     (assert-equal
      (append (iota len) '(foo))
      ((rule-simplifier (list find-consecutive-dups))
       items))))
)
