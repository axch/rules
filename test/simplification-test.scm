(in-test-group
 simplification

 (define-each-check

   (equal?
    '(+ (+ (* x y) (* x z)) (* w x))
    (algebra-1 '(* (+ y (+ z w)) x)))

   (equal?
    '(+ (* w x) (* x y) (* x z))
    (algebra-2 '(* (+ y (+ z w)) x)))

   (equal?
    '(* 3 x)
    (algebra-2 '(+ (* 3 (+ x 1)) -3)))))
