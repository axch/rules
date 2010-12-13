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
    (produces '(b b)))))


