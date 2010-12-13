(define (self-relatively thunk)
  (if (current-eval-unit #f)
      (with-working-directory-pathname
       (directory-namestring (current-load-pathname))
       thunk)
      (thunk)))

(define (load-relative filename)
  (self-relatively (lambda () (load filename))))

(load-relative "../../testing/load")
(load-relative "matcher-test")
(load-relative "pattern-directed-invocation-test")
(load-relative "simplification-test")

(define (run-tests-and-exit)
  (let ((v (show-time run-registered-tests)))
    (newline)
    (flush-output)
    (%exit v)))
