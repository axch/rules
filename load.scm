;;;; File:  load.scm -- Loader for rule system

(load "utils.scm")
(load "eq-properties")
(load "ghelper")
(load "matcher")

(define (rule-memoize f) f)

(load "pattern-directed-invocation")
(load "rules")
