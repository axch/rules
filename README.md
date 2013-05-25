Rules
=====

The Rules software is an engine for

- defining [patterns](#patterns) like `(+ 0 (? x))`, which means "Match any list of
  length 3 that begins with the symbol `+` and the number `0`, and
  call its third element `x`";
- using them to define [rules](#rules) like `(rule (+ 0 (? x)) x)`,
  which means "If you get such a list, return its third element
  (otherwise return your input)"; and
- composing such rules into [pattern-dispatch](#pattern-dispatch) operators and
  [term rewriting](#term-rewriting) systems.

In addition, Rules

- is [extensible](#extension) to more kinds of patterns;
- includes example term-rewriting [simplifiers](#simplifiers) for logic and algebra;
  and
- is itself meant as a [pedagogical illustration](http://web.mit.edu/~axch/www/rules/workbook.pdf)
  of a way to write such engines.

Table of Contents
-----------------

1. [Introduction](#introduction)
2. [Installation](#installation)
3. [Patterns](#patterns)
    - [Examples](#examples)
    - [Concepts](#concepts)
    - [Pattern Language](#pattern-language)
    - [Matching](#matching)
3. [Rules](#rules)
4. [Pattern Dispatch](#pattern-dispatch)
5. [Term Rewriting](#term-rewriting)
    - [Simplifiers](#simplifiers)
6. [Extension](#extension)
    - [Implementing Custom Matcher Combinators](#implementing-custom-matcher-combinators)
    - [Custom Combinators in Patterns](#custom-combinators-in-patterns)
    - [A Note on Segment Matching](#a-note-on-segment-matching)
7. [Other Pattern Matching Systems](#other-pattern-matching-systems)
8. [Developer Documentation](#developer-documentation)
    - [Portability](#portability)
9. [Bugs](#bugs)
10. [Unimplemented Features](#unimplemented-features)
11. [Author](#author)
12. [History](#history)
13. [License](#license)

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
    (rule '(0)                          ; If the whole argument list is a single 0
          1)                            ; the answer is 1
    (rule `((? n ,positive?))           ; If a single positive n
          (* n (factorial (- n 1))))))  ; use the formula
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

Pattern Language
----------------

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

Matching
--------

Patterns can be compiled into matcher procedures that accept a datum
and do something with the (possibly empty) set of bindings that make
the datum match the pattern.

- `(matcher <pattern>)`

  Returns a procedure that accepts one object and returns an
  association list mapping the names of the variables in the pattern
  to pieces of the object such that the pattern and the object become
  `equal?` upon substituting those bindings into the pattern.  If no
  such mapping exists, the procedure returns `#f`.

- `(for-each-matcher <pattern>)`

  Returns a procedure that, given an object and a procedure, applies
  the procedure it is given to each possible association list of
  bindings of variable names to pieces of the object that make the
  pattern match.  This procedure does not return anything useful.

- `(all-results-matcher <pattern>)`

  Returns a procedure that, given an object, returns a (possibly
  empty) list of all association lists of bindings of variable names
  to pieces of the object that make the pattern match.


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
operator will attempt the rules in order, and return the first result
if any rule matches.  If no rule matches, a pattern-dispatch operator
signals an error.  This is a case where the distinction between a rule
not matching and a rule matching and returning its input is
significant.

- `(pattern-dispatch <rule> ...)`

  Returns a pattern-dispatch operator whose initial set of rules is
  given by the arguments.  These rules will be tried left-to-right.

- `(attach-rule! <operator> <rule>)`

  Adds another rule to an existing pattern-dispatch operator.  The
  new rule will be tried last.


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
  if no rules match, returns its input unchanged (up to `eqv?`).  Of
  course, the rules in question should be arranged so as to ensure
  that this process terminates in a reasonable amount of time.

  For purposes of determining substructure, the input is interpreted
  as an expression tree: to wit, an arbitrarily deep list of lists (as
  opposed to a tree of pairs).  For example, given the input
  `(* (+ a b) (+ c d))`, the rules would be applied to `*`, `+`, `a`,
  `b`, `(+ a b)`, `(+ c d)`, the input itself, and any results (and
  subexpressions thereof) the rules may produce from such
  applications.

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
concisely in `term-rewriting.scm`.

Simplifiers
-----------

Mostly by way of example, Rules includes several term-rewriting
systems for simplifying albegraic and logical expressions, in
`simplifiers.scm`.  For instance,

```scheme
(simplify-algebra
 '(+ (* 3 (+ x y 1))
     -3
     (* y (+ 1 2 -3) z)))
 ===> (+ (* 3 x) (* 3 y))
```


Extension
=========

The pattern matching system of Rules is extensible, permitting the
addition of custom matcher combinators and custom pattern syntax for
them.

Pattern matchers in Rules nest because of an interface that allows a
matcher for a compound (like a list) to combine matchers for the
pieces as black boxes and expose the same interface.  That's why they
are called _combinators_.

Implementing Custom Matcher Combinators
---------------------------------------

To be precise, a matcher combinator in Rules is a procedure of three
arguments: the `datum`, the `dictionary`, and the `success`
continuation procedure.  The `datum` is the portion of the data that
the combinator is expected to match against, the `dictionary` is a data structure
that represents the bindings made so far, and the `success` procedure
represents the behavior of the rest of the matcher after this combinator.
To wit, the `success` procedure accepts a dictionary (possibly
augmented with any additional bindings this combinator chooses to
make) and returns either `#f` to indicate that the rest of the matcher
fails to match with those bindings, or a dictionary to indicate success
(which should include bindings for all pattern variables occurring
in the whole pattern).

The matcher combinator is expected to return `#f` if the matcher
consisting of itself and its success procedure fails to match the
given datum with the given dictionary, and a dictionary of bindings if
it succeeds.  (Matchers for data segments have a slightly different
interface, [below](#a-note-on-segment-matching).)  Giving a combinator access to the rest of
the matcher like this enables guessing different possible bindings and
intercepting failures in order to backtrack (see `match:segment` in
`patterns.scm`).

For example, here is one way to make a matcher combinator for matching
a pattern constant:

```scheme
(define (constant-matcher pattern-constant)
  (lambda (data dictionary succeed)
    (and (eqv? data pattern-constant)
         (succeed dictionary))))
```

The returned procedure closes over the constant it is looking for.
When it gets data, it checks that the data is `eqv?` to the constant.
If not, the whole match from this point fails (because there is
nothing the subsequent matchers can do about this datum being
different from the desired constant).  If the data is `eqv?` to the
constant, this combinator defers completely to the sequel.

The dictionary is an associative structure for accessing previously
made bindings and making new ones.

- `(dict:lookup <variable> <dictionary>)`

  Looks up the given `variable` (usually a symbol) in the given
  `dictionary` and returns the value cell (see `dict:value`) if found
  or `#f` if not.  Does not directly return the value held in the
  value cell to be able to distinguish between no binding and a
  binding to `#f`.

- `(dict:value <value-cell>)`

  Returns the value held in the given value cell.

- `(dict:bind <variable> <object> <dictionary>)`

  Returns the new dictionary that results from adding to the given one
  a binding for the `variable` to the `object`.  The input
  `dictionary` is not mutated.

Custom Combinators in Patterns
------------------------------

Any procedure that implements the interface of a matcher combinator
can be used directly in a pattern. For example (note the quasiquote)

```scheme
`(,(constant-matcher '+) (? x) (? y))  ; matches like '(+ (? x) (? y))
```

This fact is useful even without custom matcher combinators, to
abstract over patterns (see, for example, `simplifiers.scm`).

The pattern compiler (that builds matcher combinators out of patterns)
can also be extended, to recognize additional syntax for custom
combinators:

- `(new-pattern-syntax! <predicate> <procedure>)`

  Adds a clause to the pattern compiler.  The clause is applicable to
  any piece of syntax for which the given `predicate` returns a true
  value; if so, that piece of syntax is compiled to the combinator
  returned from invoking `procedure`, passing that syntax as its only
  argument.  Note that if the `predicate` matches syntax intended to
  be compound, it is up to the `procedure` to compile its parts into
  submatcher combinators and compose them appropriately.  See
  `list-pattern->combinators` in `patterns.scm` for an example.

- `(match:->combinators <pattern>)`

  Compiles the given pattern to a matcher combinator, respecting all
  syntax definitions given by `new-pattern-syntax` to date.

A Note on Segment Matching
--------------------------

Combinators that match sublists (rather than individual data items)
necessarily have a somewhat different interface, because the number of
items that the segment matcher consumes impacts the remaining data
available for its success continuation to match.

The data that is passed to a segment matcher is always a list, and the
segment matcher's success continuation accepts a second argument.  The
segment matcher is to match some prefix of the list, and pass the
remainder in to its success continuation in addition to the
(augmented) dictionary.  For an example, see `match:segment` in
`patterns.scm`.  Note that in order for any enclosing compound
combinators to be able to distinguish segment matchers from regular
matchers (in order to pass them the appropriate arguments), the former
must be marked by invoking the procedure `segment-matcher!` upon them.

- `(make-segment <list> <list>)`

  An abstraction for designating segments of lists without copying
  them (until needed).  A segment is defined as all the elements of
  the first argument list, except those in the second, which must be a
  suffix thereof.  Creating a segment is an O(1) operation.  If a
  segment is placed in a dictionary (with `dict:bind`) then
  `dict:value` will retrieve it as a regular list (the requisite
  copying will be performed at most once).


Other Pattern Matching Systems
==============================

In general programming language discourse, the term "pattern matching"
usually means something a little different from what's going on here.
Typically, the allowable patterns are less general, allowing the
matching to be implemented more efficiently, at the cost of
expressiveness.  Also typically, the patterns are embedded in some
larger control construct, without allowing standalone matchers or
rules to have an existence of their own.  This obscures the essential
semantic similarity of pattern dispatch with term rewriting; but may
be appropriate in order to permit deep inspection of the patterns for
high matching performance.

The examples I have in mind are

- In Haskell, Scala, and presumably other members of the ML family,
  pattern matching is embedded into the structure of the language,
  essentially such that every function is a pattern-dispatch operator
  (except that further rules cannot be added to a defined operator after the fact).
  Patterns and rules do not have an independent existence, except
  insofar as a pattern-dispatch operator with exactly one rule can be
  thought of as being the same as a rule (which is not quite right,
  because they do not treat match failures gracefully).

  The pattern matching in these languages is restricted relative to
  Rules in that all pattern variables must be distinct (obviating the
  need to check repeated ones for equality), there are no segment
  variables, and there is no notion of backtracking in the matcher
  (though there is an option for "rule bodies" to reject a match, in
  the form of guard clauses).  On the other hand, user-defined product
  types are automatically added as additional patterns, giving smooth
  integration between construction and destructuring of algebraic data
  types.

  User extensibility of the pattern system (aside from the automatic
  introduction of products) is given by view patterns in Haskell (and
  presumably similar constructs in other descendants of ML) and by
  extractor classes in Scala.

- Prolog deeply integrates the notion of unification, which is like
  pattern matching except that the "data" can be a pattern also --
  unification computes the most general common specializer of two
  patterns.  If one of the inputs to the unification algorithm happens
  to have no variables in it, unification amounts to pattern matching.
  I do not actually know the relative expressiveness of the patterns
  in Prolog vs Rules.  Prolog already has pervasive backtracking, so
  it is quite possible that the patterns admit multiple unifications,
  which may need to be searched.

- Racket's `match` facility is very similar to the pattern matching in
  Rules, though instead of segment variables they have a concept of
  repeating subpatterns of lists.  Again, patterns and rules appear
  only as clauses of variants of the `match` form and have no
  independent existence, so effectively can only be used in what
  amounts to anonymous, non-extensible pattern-dispatch operators.

- Racket also ships with a term-rewriting library named `redex`.  As
  far as I can tell, the clauses of `match` have no relationship to
  the rules used by `redex`.

- My own [`pattern-case`](http://github.com/axch/pattern-case) library
  is an implementation of ML-style pattern matching in MIT Scheme, and
  the same remarks about its relative expressiveness to Rules apply.
  The fact that I wrote two of these things tells you that I think
  there is room for different renditions of pattern matching in the
  same programming environment.


Developer Documentation
=======================

The developer documentation is the source code and the commentary
therein.

- Interesting stuff

  - `patterns.scm`: Pattern matcher in the combinator style, and a
    compiler for it.
  - `rules.scm`: Rules.
  - `pattern-dispatch.scm`: Composition of rules into pattern-dispatch
    operators.
  - `term-rewriting.scm`: Composition of rules into a term rewriting
    engine and a few useful variations on the theme.
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


Bugs
====

The procedures returned by the [term-rewriting
combinators](#term-rewriting) do not obey exactly the same interface
as rules, in that they do not accept the optional argument that allows
the user of a rule to tell the difference between the rule failing to
match and matching but returning identically the input.  This could be
viewed as a bug.


Unimplemented Features
======================

More Matchers
-------------

There are plenty of additional matcher types that may
be worth implementing.  For example, something akin to the repetition
operator of regular expressions, that accumulates the values from
successive matches as lists of matched items.  That was the point of
making this machine extensible -- go nuts.

More Backtracking
-----------------

In principle, the same mechanism used to control
backtracking in the pattern matcher can be extended to the bodies of
rules, so that said bodies can offer retractable substitutions that
can be changed if they are found unacceptable later.  For this system,
I decided not to mess with that -- unlimited chronological
backtracking leads to well known trouble, and I feel that such an
extension would be better done by first embedding a general-purpose
backtracking mechanism into the programming language (in which the
pattern matchers can then be rewritten).  If you feel that you want
this, I hope the present system can serve as a useful example for
writing your own.

Specificity Dispatch
--------------------

In principle, pattern-dispatch operators can
analyze the rules they are dispatching with and select the most
specific of matching rules (rather than the first added) to apply.
Implementing this in the present system is impeded by the fact that
rules are opaque, so there is actually no way to examine two rules and
determine whether one is more specific than another.  That much could
be fixed, but the extensibility of the pattern matcher to arbitrary
user-supplied matchers, as well as the ability of user-supplied rule
bodies to reject matches for arbitrarily complex reasons, makes
specificity dispatch impossible in general (without requiring some
kind of additional user-supplied information about the relationships
of any new matchers and any restriction predicates to each other).

Better Performance
------------------

Though some attention has been given to making sure that at
least common rules will have the asymptotic performace one would wish,
further performance improvements are possible:

- In principle, once there is only one segment variable left among the
  subpatterns of a list pattern, no search is necessary to determine
  how many elements of the list to match it with.  At the moment this
  optimization is only applied in the common case that the segment
  variable in question is the last subpattern in the list.

- If a segment variable is not used a the rule's body, much work could
  be saved by not copying it before evaluating said body.  This would
  be very easy to implement in a lazy programming language, but in
  Scheme it would require a static dead-variable analysis of the body
  expression.

- In principle, `rule-list` and `pattern-dispatch` could eliminate the
  work of matching common prefixes of multiple rules by using a trie
  structure to match all their rules at once.  Implementing this is
  impeded in the present program by the fact that rules are opaque, so
  there is actually no way to know whether two rules would start with
  the same tests or not.  That much could be fixed; but the fact that
  the pattern language allows user extension with arbitrary matchers
  further limits the ultimate applicability of this extension.

- In principle, much work could be done to optimize the rule
  application order used by `term-rewriting`; especially by examining
  the rules and computing the circumstances under which applications
  of them can produce results upon which further rules may be
  applicable.  In the present program this is impeded by the
  above-mentioned opacity of rules, and also by the fact that in
  principle the rule bodies are arbitrary Scheme expressions that can
  return anything.


Author
======

Alexey Radul, <axch@mit.edu>


History
=======

The idea of compiling patterns to collections of combinator procedures
goes at least as far back as Carl Hewitt's 1969 PhD thesis, though he
did not implement it.

The progenitor of the current program was originally written by Gerald
Jay Sussman in 1983 -- an appropriate source file had this to say:

> This is a descendent of the infamous 6.001 rule interpreter,
> originally written by GJS for a lecture in the faculty course held
> at MIT in the summer of 1983, and subsequently used and tweaked from
> time to time.  This subsystem has been a serious pain in the ass,
> because of its expressive limitations, but I have not had the guts
> to seriously improve it since its first appearance. -- GJS
>
> January 2006.  I have the guts now! The new matcher is based on
> combinators and is in matcher.scm.  -- GJS

I myself got involved when I was a teaching assistant for Professor
Sussman's Advanced Symbolic Programming course at MIT; my inspiration
was to clean up all the internal and external interfaces, and
understand what the essential pieces were and what they were good for.
After a couple iterations between 2008 and 2010, I was able to produce
a reasonably pretty version of this program, showcasing the
relationships between patterns, rules, pattern dispatch, term
rewriting, and simplification.


License
=======

This file is part of Rules, an extensible pattern matching, pattern
dispatch, and term rewriting system for MIT Scheme.
Copyright 2013 Alexey Radul.

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
