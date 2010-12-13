(in-test-group
 pattern-directed-invocation
 
 (define-test (quad-test)
   (interaction
    (define quad
      (make-pattern-operator
       (list
	(rule 
	 `((? a) (? b) (? c) (? x))
	 (+ (* a (expt x 2))
	    (* b x)
	    c))

	(rule
	 `((? a) (? x) (? x) + (? b) (? x) + (? c))
	 (+ (* a (expt x 2))
	    (* b x)
	    c)))))

    (quad 1 2 3 4)
    (produces 27)

    (quad 1 4 4 '+ 2 4 '+ 3)
    (produces 27)))

 (define-test (frob-test)
   (interaction
    (define frob
      (make-pattern-operator))

    (attach-rule! frob
     (rule
      '(a (?? x) (?? y) (?? x) c)
      (and (<= (length y) 2)
	   y)))

    (apply frob '(a b b b b b b c))
    (produces '(b b))))

 (define-test (factorial-1)
   (interaction
    (define factorial (make-pattern-operator))

    (attach-rule! factorial (rule '(0) 1))

    (attach-rule! factorial
		  (rule `((? n ,positive?))
			(* n (factorial (- n 1)))))

    (factorial 10)
    (produces 3628800)))
 
 (define-test (factorial-2)
   (interaction
    (define factorial (make-pattern-operator))

    (attach-rule! factorial
		  (make-rule '((? n))
			     (lambda (n) (* n (factorial (- n 1))))))

    (attach-rule! factorial
		  (make-rule '(0) (lambda () 1)))

    (factorial 10)
    (produces 3628800)))

)
