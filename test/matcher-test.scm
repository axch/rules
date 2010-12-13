(in-test-group
 matcher

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
   '((succeed ((y (b b b b b b)) (x ())))
     (succeed ((y (b b b b)) (x (b))))
     (succeed ((y (b b)) (x (b b))))
     (succeed ((y ()) (x (b b b)))))
   (let ((results '()))
     ((match:->combinators '(a (?? x) (?? y) (?? x) c))
      '(a b b b b b b c)
      '()
      (lambda (x)
	(set! results (cons `(succeed ,x) results))
	#f))
     (reverse results)))

  (equal?
   '((b 1))
   ((matcher '(a ((? b) 2 3) (? b) c))
    '(a (1 2 3) 1 c))))

)
