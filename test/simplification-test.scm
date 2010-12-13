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
   )

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

 (define-test (scanning-for-duplicates)
   (define find-consecutive-dups
     (rule '((?? stuff1) (? x) (? x) (?? stuff2))
	   `(,@stuff1 ,x ,@stuff2)))
   (let ((items (iota 10))) ; TODO quadratic
     (assert-equal
      items
      ((rule-simplifier (list find-consecutive-dups))
       items))))

 (define-test (removing-duplicates)
   (define find-consecutive-dups
     (rule '((?? stuff1) (? x) (? x) (?? stuff2))
	   `(,@stuff1 ,x ,@stuff2)))
   (let ((items (make-list 10 'foo))) ; TODO cubic + gc pressure
     (assert-equal
      '(foo)
      ((rule-simplifier (list find-consecutive-dups))
       items))))

 (define-test (removing-distant-duplicates)
   (define find-consecutive-dups
     (rule '((?? stuff1) (? x) (? x) (?? stuff2))
	   `(,@stuff1 ,x ,@stuff2)))
   (let* ((len 10) ; TODO cubic + gc pressure
	  (items (append (iota len) (make-list len 'foo))))
     (assert-equal
      (append (iota len) '(foo))
      ((rule-simplifier (list find-consecutive-dups))
       items))))
)
