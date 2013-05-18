Introduction
============


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
