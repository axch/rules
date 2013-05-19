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
therefore easier to get it right.  Much the same thing happens with
local optimization passes in compilers.

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

Examples
--------

Here is a pattern that might be used for constant folding:

```scheme
`(* (? x ,number?) (? y ,number?))
```

This means, in detail:

- Match a list of exactly three elements
- Whose first element is the symbol `*`
- Whose second element produces true when given to the procedure
  `number?`
  - Which bind to the name `x`
- Whose third element also produces true when given to the procedure
  `number?`
  - Which bind to the name `y`

Here is a pattern that might be used for simplification:

```scheme
'(+ (?? stuff) (? x) (? x) (?? more))
```

In brief, it means "find a pair of consecutive identical terms
anywhere in a sum".  In detail:

- Match a list
- Whose first element is the symbol `+`
- That has some elements after the first
  - Which bind to the name `stuff`
- Such that there is an element after `stuff`
  - Which bind to the name `x`
- Such that there is an element after `x`
  - Such that this element is `equal?` to `x`
- And bind any subsequent elements of the list to the name `more`.

Note that the matcher will search over all possible lengths for the
`stuff` list to find a match (but the length of the `more` list can be
deduced, because it must take whatever is left in the sum).

Concepts
--------

A pattern gives a shape for a piece of data, with some "holes" --
_variables_ -- for components of the data that may vary.  A successful
match entails a binding of data components to variables such that, if
the variables are replaced with their bindings, the pattern and the
data become `equal?`.  If no such binding is possible, the match
fails.

Patterns are recursive, meaning that a pattern for a compound
structure like a list is built out of patterns for its pieces.  This
allows patterns to recognize very specific, complex shapes in their
data, and extract deeply nested data components.

Sublists of unknown length may be matched with _segment variables_,
which entail search within the matcher to find a matching assignment.

Unlike other pattern matching systems, *variables may appear more than
once* in a pattern.  This just means that each occurrence of the same
variable must correspond to `equal?` data for a successful match.

Reference
---------

Patterns are Scheme list structure, interpreted according to the
following rules:

- `(? <symbol> <procedure> ...)`: Pattern variable

  The symbol serves as the variable's name.  The optional procedures
  are used as predicates that restrict the possible data this variable
  may be bound to.  This pattern matches any datum that passes all of
  the predicates, and binds the given name to that datum.  If any
  predicate returns `#f` on the datum, this pattern fails to match.
  In the common case of no predicates, this pattern always matches.

- `(?? <symbol>)`: Segment variable

  This pattern must occur as a subpattern of a list pattern.  The
  symbol serves as the variable's name.  This pattern matches a
  sublist of the enclosing list of any length (including zero) and
  binds that sublist to the given name.

- `(<pattern> ...)`: List

  A list whose first symbol is neither `?` nor `??` is a pattern that
  matches a list if and only if the elements of the data list match
  the subpatterns of the list pattern (in order).  In this case, the
  list pattern binds all the variables bound by its subpatterns.  If
  more than one subpattern binds the same name, those data must agree
  (up to `equal?`).  Variable-length lists can be matched using
  segment variables.

- `<procedure>`: Explicit combinator

  A Scheme procedure that appears as a pattern is taken to be a
  matcher combinator (see [Extension](#extension)).  In particular, to
  match the literal list `(? x)` (which, if used as a pattern, would
  become a variable), you can use ``(,(match:eqv '?) x)`.

- `<object>`: Constant

  Any other Scheme object is a pattern constant that matches only
  itself (up to `eqv?`).

Rules
=====

A rule is a pairing of a pattern and an expression to evaluate if the
pattern matches (the _body_).  The useful thing about rules is that
the body expression has access to the bindings of the variables
matched by the pattern.

- `(rule <pattern> <expression>)`: Rule macro

  Returns a procedure that accepts one argument and tries to match the
  `pattern` against that argument.  If the match succeeds, evaluates
  the `expression` in an environment extended with the bindings
  determined by the match and returns the result.  If the match fails,
  returns the original input unchanged (up to `eqv?`).

In order to support conditions on the applicability of rules that are
inconvenient to capture in the pattern, the body may return `#f` to
force the rule application to backtrack back into the matcher (or
fail).

- `(rule <pattern> <expression>)`: Rule macro (cont'd)

  If the `expression` returns `#f`, the rule procedure interprets that
  particular match of the pattern as having failed after all, and
  evaluates the `expression` with the bindings from another match, if
  any.  If the `expression` returns `#f` for all sets of bindings that
  cause the pattern to match, the rule procedure returns its input
  unchanged.

Unfortunately, this means that special measures are necessary to allow
the body of a rule to cause the rule procedure to return `#f`.

- `(succeed <thing>)`: Procedure

  A helper procedure to allow the body of a rule to cause its
  enclosing rule invocation to return any`thing`, including `#f`.

- `(rule <pattern> <expression>)`: Rule macro (cont'd)

  If the `expression` returns the result of calling `succeed` on an
  object, the rule procedure returns that object (even if the object
  is `#f`, which the rule procedure would otherwise interpret as a
  command to try a different match).

For purposes of term rewriting, a "rule firing" that didn't change the
input is equivalent to the rule not having fired at all.  In other
circumstances, however, it is sometimes necessary to distinguish
between a rule matching and intentionally returning its input vs a
rule not matching at all.  For this purpose, rule procedures actually
accept an optional second argument, which, if supplied, acts as a
token to return on failing to match (instead of the input).

- `(rule <pattern> <expression>)`: Rule macro (cont'd)

  The returned rule procedure accepts an optional second argument.  If
  supplied, this argument is returned (instead of the first argument)
  on failure to match the pattern (or on exhaustion of backtracking
  options).

Where there is a macro, there should generally be a procedure that
does the same thing:

- `(make-rule <pattern> <procedure>)`: Rule constructor

  Returns a rule procedure that matches its input against the
  `pattern` and calls the `procedure` with the resulting bindings as
  follows: every required formal parameter to the `procedure` is
  passed the binding of the pattern variable of the same name from the
  match.  The `procedure` is otherwise treated the same way as the
  body expression of a rule made by the `rule` macro is treated:
  backtracking on `#f`, forcing return with `succeed`, etc.


Pattern Dispatch
================

A _pattern-dispatch operator_ (like the `factorial` example in the
[Introduction](#introduction)) is a collection of rules, one of which
is expected to match any datum that the operator may be given.  The
operator will attempt the rules in some unspecified order, and return
the result if any rule matches (which result is unspecified if more
than one rule matches).  If no rule matches, a pattern-dispatch
operator signals an error.  This is a case where the distinction
between a rule not matching and a rule matching and returning its
input is significant.

- `(pattern-dispatch <rule> ...)`

  Returns a pattern-dispatch operator whose initial set of rules is
  given by the arguments.

- `(attach-rule! <operator> <rule>)`

  Adds another rule to an existing pattern-dispatch operator.

Term Rewriting
==============

Something like a peephole optimizer or a symbolic simplifier applies
its rules to any sub-element of its input, replacing that part with
the result of the rule; and keeps doing so until no rules apply
anywhere within the input, in which case it returns the final result.
Such a thing is called a _term-rewriting system_.  Rules provides a
collection of combinators for making term rewriting systems and
similar operators out of rules.

Note that the results of all the procedures in this section look like
rules, in the sense that they try to match something according to some
pattern and return their input on failure, so these combinators nest.

- `(term-rewriting <rule> ...)`

  Returns a term-rewriting procedure that applies the given rules.
  The returned procedure accepts one argument, and applies any of its
  rules at any matching point that occurs inside the list structure of
  its argument, repeatedly replacing the match with the result of the
  rule, until no rules apply.  Returns the final result.  (Does not
  mutate its input unless the bodies of the rules do.)  In particular,
  if no rules match, returns its input unchanged (up to `eqv?`).

  For purposes of determining substructure, the input is interpreted
  as an expression tree: to wit, an arbitrarily deep list of lists (as
  opposed to a tree of pairs).  For example, given the input
  `(* (+ a b) (+ c d))`, the rule would be applied to `*`, `+`, `a`,
  `b`, `(+ a b)`, `(+ c d)`, the input itself, and any results the
  rule may produce from such applications.

- `(rule-list <list of rules>)`

  Returns a procedure that tries each of its rules in order on its
  input (not subexpressions thereof) until one matches, and returns
  the result.  Returns the input (up to `eqv?`) if no rules match.

  Note: the returned procedure is slightly different from a
  pattern-dispatch operator, in that it does not error out on failure,
  but returns its input.

- `(in-order <list of rules>)`

  Returns a procedure that accepts one argument and applies each rule
  in the list to it once, in the order given, passing the results from
  one rule to the next (whether the rules match or not).  The effect
  is actually the same as composing the rules as functions, in the
  proper order.  Note: if none of the rules match, the net result is
  returning the input unchanged (up to `eqv?`).

- `(iterated <rule>)`

  Returns a procedure that repeatedly applies its rule to its input,
  and returns the final result.  The input is not mutated (unless by
  the body of the rule).  If the rule never matches, the procedure
  returns its input unchanged (up to `eqv?`).

  Note: This is most useful with rules that are not idempotent, such
  as may arise as the outputs of the other combinators, like
  `rule-list`.

- `(on-subexpressions <rule>)`

  Returns a procedure that applies its rule to every point in the list
  structure of its input, bottom-up, including the input itself, and
  returns the final result.  If the rule matches any subexpression,
  the rule's result is placed in the appropriate place before matching
  the expression it was a subexpression of.  The input is not mutated
  (unless by the body of the rule).  If the rule never matches, the
  procedure returns its input unchanged (up to `eqv?`).  This is
  different from `term-rewriting` because it applies the rule only
  once at each point, whether it matches or not.

- `(iterated-on-subexpressions <rule>)`

  Like `on-subexpressions`, except the returned procedure iterates on
  each subexpression before trying a larger result.  Note that not
  just the rule is iterated, but the rule is first reapplied to
  subexpressions of the result, because the rule can produce structure
  whose subexpressions might match the rule.  If the system defined by
  the rule is confluent, this should produce the same result as
  `(iterated (on-subexpressions <rule>))`, but matches are attempted
  in a different order, leading to different performance
  characteristics (and potentially different end results if the rule
  is not confluent).

- `(top-down <rule>)`

  Like `iterated-on-subexpressions`, but also applies the rule
  repeatedly to the whole input before recurring to subexpressions.

Iteration patterns are hard to describe in words.  If you are still
confused about the rule application order of `on-subexpressions`,
`iterated-on-subexpressions`, or `top-down`, they are defined quite
concisely in `simplification.scm`.

Extension
=========

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
