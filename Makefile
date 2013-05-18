### This file is part of Rules, a pattern matching, pattern dispatch,
### and term rewriting system for MIT Scheme.
### Copyright 2013 Alexey Radul.
###
### Rules is free software; you can redistribute it and/or modify it
### under the terms of the GNU Affero General Public License as
### published by the Free Software Foundation; either version 3 of the
### License, or (at your option) any later version.
### 
### This code is distributed in the hope that it will be useful,
### but WITHOUT ANY WARRANTY; without even the implied warranty of
### MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
### GNU General Public License for more details.
### 
### You should have received a copy of the GNU Affero General Public
### License along with Rules; if not, see
### <http://www.gnu.org/licenses/>.

test:
	mit-scheme --compiler -heap 6000 --batch-mode --no-init-file --eval '(set! load/suppress-loading-message? #t)' --eval '(begin (load "load") (load "test/load") (run-tests-and-exit))'

FILES = matcher.scm pattern-directed-invocation.scm simplification.scm simplifiers.scm load.scm

# TODO Strip the license statements from the code files?
workbook.ps: $(FILES)
	enscript -M letter -fCourier-Bold12 -o workbook.ps --file-align=2 README  --color --highlight $(FILES)

.PHONY: test
