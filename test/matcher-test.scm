(in-test-group
 matcher

 (define (id x) x)

 (define-each-check

  (equal?
   '(succeed ((b 1)))
   ((match:->combinators '(a ((? b) 2 3) 1 c))
    '(a (1 2 3) 1 c)
    '()
    (lambda (x) `(succeed ,x))))

  (equal?
   '#f
   ((match:->combinators '(a ((? b) 2 3) (? b) c))
    '(a (1 2 3) 2 c)
    '()
    (lambda (x) `(succeed ,x))))

  (equal?
   '(succeed ((b 1)))
   ((match:->combinators '(a ((? b) 2 3) (? b) c))
    '(a (1 2 3) 1 c)
    '()
    (lambda (x) `(succeed ,x))))

  (equal?
   '(((y (b b b b b b)) (x ()))
     ((y (b b b b)) (x (b)))
     ((y (b b)) (x (b b)))
     ((y ()) (x (b b b))))
   ((all-dictionaries
     (match:->combinators '(a (?? x) (?? y) (?? x) c)))
    '(a b b b b b b c)))

  (not ((first-dictionary (match:->combinators '(a (?? x) (?? y) (?? x) c)))
	'(a b b b b b b a)))

  (equal?
   '((b 1))
   ((matcher '(a ((? b) 2 3) (? b) c))
    '(a (1 2 3) 1 c))))

 (define-test (smoke)
   (define matcher
     (match:->combinators '(+ (? a) (+ (? b) (? c)))))
   
   (check (equal? '((c 4) (b 3) (a 2))
		  (matcher '(+ 2 (+ 3 4)) '() id)))
   (check (not (matcher '(+ 2 (+ 3 4 5)) '() id))))

 (define-test (match-empty-list)
   (assert-equal
    '(()) ; One empty dictionary
    ((all-dictionaries (match:->combinators '()))
     '()))
   (assert-equal
    '() ; No dictionaries
    ((all-dictionaries (match:->combinators '()))
     '(foo))))

 (define-test (obvious-tail)
   (define matcher
     (match:->combinators '(and (?? stuff))))
   (let ((items (iota 10))) ; linear
     (assert-equal
      `(((stuff ,items)))
      ((all-dictionaries matcher)
       `(and ,@items)))))
)
