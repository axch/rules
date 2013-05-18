Introduction
============

Rules are a pervasive human device for describing processes.  It is
therefore a source of great programming power to concisely instruct
the computer "If you see a situation like X, do Y."

Consider the usual definition of the factorial function `n!`

- 0! = 1
- n! = n * (n-1)! for positive n

We are used to programming this with an `if` statement, but we can
also think of factorial as the union of two separate rules, which
might be rendered in prefix notation as

```scheme
(define factorial
  (pattern-dispatch
    (rule 0
          1)
    (rule `(? n ,positive?)
          (* n (factorial (- n 1))))))
```

In the case of factorial, this representation doesn't buy us much, but
for a more complex function, this kind of pattern-dispatched operator
can be much clearer than a nest of `if`s.  Being able to distribute
clauses to the places in the program where they are relevant is also a
source of power: object-oriented method dispatch can be seen as a form
of pattern dispatch, where the patterns are retricted to be "are you
an instance of this class?"

To take a more elaborate example of the use of rules, a symbolic
simplifier for algebraic expressions needs to know many things like

- Replace instances of "(+ 0 x)" with "x" (for any expression x)
- Replace instances of "(* n1 n2)" with their product (for literal
  numbers n1, n2)
- If you see sin^2(x) and cos^2(x) in the same sum, turn them into
  1
- ...

Writing them out as an explicit list of concise rules like this:

```scheme
(rule '(+ 0 (? x))
      x)

(rule `(* (? n1 ,number?) (? n2 ,number?))
      (* n1 n2))              ; multiply

(rule '(+ (?? t1) (expt (sin (? theta)) 2) (?? t2) (expt (cos (? theta)) 2) (?? t3))
      `(+ 1 ,@t1 ,@t2 ,@t3))  ; build a list with a + in front
```
makes it easier to see what the simplifier is actually doing, and
therefore easier to get it right.

The Rules software is an engine for

- defining patterns like `(+ 0 (? x))`, which means "Match any list of
  length 3 that begins with the symbol `+` and the number `0`, and
  call its third element `x`";
- using them to define rules like `(rule (+ 0 (? x)) x)`, which means
  "If you see such a list, return its third element, otherwise leave
  it"; and
- composing such rules into pattern-dispatch operators and term
  rewriting systems.

In addition, Rules

- is extensible to more kinds of patterns;
- includes example term-rewriting simplifiers for logic and algebra;
  and
- is itself meant as a pedagogical illustration of a way to write such
  engines.

Installation
============

Just `git clone` this repository,
```scheme
(load "rules/load")
```
and hack away.

If you want to develop Rules, you will want to also get the unit test
framework that Rules uses.  Type `git submodule init` and `git
submodule update`.

Patterns
========

```scheme
`(+ (? x ,number?) (? y ,number?))
```

Developer Documentation
=======================

The developer documentation is the source code and the commentary
therein.

- Interesting stuff

  - `matcher.scm`: Pattern matcher in the combinator style, and a
    compiler for it.
  - `pattern-directed-invocation.scm`: Rules, and composition thereof
    into pattern-dispatch operators.
  - `simplification.scm`: Definition of a term rewriting engine and a
    few useful variations on the theme.
  - `simplifiers.scm`: Simplification of algebraic and logical
    expressions by means of term rewriting.

- Support

  - `support/auto-compilation.scm`: Automatically invoke the MIT
    Scheme compiler, if necessary and possible, to (re)compile files
    before loading them.  This has nothing to do with Pattern Case,
    but I figured copying it in was easier than making an external
    dependency.
  - `support/eq-properties.scm`: A generalization of Lisp property
    lists to any Scheme object (identifiable by eq?); used internally
    for tagging certain procedures as to the interface they expect.
  - `support/ghelper.scm`: A predicate dispatch system, used to
    implement the pattern compiler.
  - `support/utils.scm`: A little magic to make the macrology work
    out.
  - `load.scm`: Orchestrate the loading sequence.  Nothing interesting
    to see here.
  - `Makefile`: Run the test suite.  Note that there is no "build" as
    such; source is automatically recompiled at loading time as
    needed.
  - `LICENSE`: The AGPLv3, under which Pattern Case is licensed.

- Test suite

  - Run it with `make test`.
  - The `test/` directory contains the actual test suite.
  - The `testing/` directory is a git submodule pointed at the [Test
    Manager](http://github.com/axch/test-manager/) framework that the
    test suite relies upon.

Portability
-----------

Rules is written in MIT Scheme with no particular portability
considerations in mind.  It is a language extension at heart, so the
`rule` macro is quite important to its spirit.  Rules should not be
too difficult to port to any Scheme system that has the facilities to
implement `rule` (notably a macro system permitting controlled
non-hygiene).  I expect Rules to run unmodified on any platform MIT
Scheme supports.

Unimplemented Features
======================

- Trie implemetation of rule-list TODO

Author
======

Alexey Radul, <axch@mit.edu>

License
=======

This file is part of Rules, a pattern matching, pattern dispatch,
and term rewriting system for MIT Scheme.
Copyright 2010 Alexey Radul.

Rules is free software; you can redistribute it and/or modify it under
the terms of the GNU Affero General Public License as published by the
Free Software Foundation; either version 3 of the License, or (at your
option) any later version.

Rules is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
for more details.

You should have received a copy of the GNU Affero General Public
License along with Pattern Case; if not, see
<http://www.gnu.org/licenses/>.