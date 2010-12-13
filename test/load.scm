(define (self-relatively thunk)
  (if (current-eval-unit #f)
      (with-working-directory-pathname
       (directory-namestring (current-load-pathname))
       thunk)
      (thunk)))

(define (load-relative filename)
  (self-relatively (lambda () (load filename))))

(define (first-dictionary matcher)
  (lambda (datum)
    (matcher datum '() 
	     (lambda (dict)
	       (interpret-segments-in-dictionary dict)))))

(define (all-dictionaries matcher)
  (lambda (datum)
    (let ((results '()))
      (matcher
       datum
       '()
       (lambda (dict)
	 (set! results (cons dict results))
	 #f))
      (map interpret-segments-in-dictionary
	   (reverse results)))))

(define (assert-same-dictionary-lists expected got)
  (assert-equal (length expected) (length got))
  (assert-true (every dict:equal? expected got)))

(load-relative "../../testing/load")
(load-relative "matcher-test")
(load-relative "pattern-directed-invocation-test")
(load-relative "simplification-test")

(define (run-tests-and-exit)
  (let ((v (show-time run-registered-tests)))
    (newline)
    (flush-output)
    (%exit v)))
