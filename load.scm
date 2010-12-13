;;;; File:  load.scm -- Loader for rule system

(define (self-relatively thunk)
  (if (current-eval-unit #f)
      (with-working-directory-pathname
       (directory-namestring (current-load-pathname))
       thunk)
      (thunk)))

(define (load-relative filename)
  (self-relatively (lambda () (load filename))))

(load-relative "support/auto-compilation")
(load-relative-compiled "support/utils")
(load-relative-compiled "support/eq-properties")
(if (lexical-unbound? (the-environment) 'make-generic-operator)
    (load-relative-compiled "support/ghelper"))
(load-relative-compiled "matcher")

(define (rule-memoize f) f)

(load-relative-compiled "pattern-directed-invocation")
(load-relative-compiled "simplification")
(load-relative-compiled "simplifiers")
