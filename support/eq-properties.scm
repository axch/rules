;;; This file is a supporting library for Rules, a pattern matching,
;;; pattern dispatch, and term rewriting system for MIT Scheme.
;;; Copyright Gerald Jay Sussman.
;;;
;;; This program is free software; you can redistribute it and/or
;;; modify it under the terms of the GNU Affero General Public License
;;; as published by the Free Software Foundation; either version 3 of
;;; the License, or (at your option) any later version.
;;; 
;;; This code is distributed in the hope that it will be useful,
;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.
;;; 
;;; You should have received a copy of the GNU Affero General Public
;;; License along with Rules; if not, see
;;; <http://www.gnu.org/licenses/>.

;;;; Traditional LISP property lists
;;;   extended to work on any kind of 
;;;   eq? data structure.

;;; Property lists are a way of creating data that
;;; looks like a record structure without
;;; commiting to the fields that will be used
;;; until run time.  The use of such flexible
;;; structures is frowned upon by most computer
;;; scientists, because it is hard to statically
;;; determine the bounds of the behavior of a
;;; program written using this stuff.  But it
;;; makes it easy to write programs that confuse
;;; such computer scientists.  I personally find
;;; it difficult to write without such crutches.
;;; -- GJS

(declare (usual-integrations))

(define eq-properties (make-eq-hash-table))

(define (eq-label! node . plist)
  (let loop ((plist plist))
    (cond ((null? plist) node)
	  ((null? (cdr plist)) (error "Malformed plist"))
	  (else
	   (eq-put! node (car plist) (cadr plist))
	   (loop (cddr plist))))))

(define (eq-put! node property value)
  (let ((plist
	 (hash-table/get eq-properties node '())))
    (let ((vcell (assq property plist)))
      (if vcell
	  (set-cdr! vcell value)
	  (hash-table/put! eq-properties node
	    (cons (cons property value) plist)))))
  node)

(define (eq-get node property)
  (let ((plist
	 (hash-table/get eq-properties node '())))
    (let ((vcell (assq property plist)))
      (if vcell
	  (cdr vcell)
	  #f))))

(define (eq-rem! node . properties)
  (for-each
   (lambda (property)
     (let ((plist
	    (hash-table/get eq-properties node '())))
       (let ((vcell (assq property plist)))
	 (if vcell
	     (hash-table/put! eq-properties node
			      (delq! vcell plist))))))
   properties)
  (if (null? (hash-table/get eq-properties node '()))
      (hash-table/remove! eq-properties node))
  node)


(define (eq-adjoin! node property new)
  (eq-put! node property
	   (lset-adjoin eq? (or (eq-get node property) '()) new))
  node)

(define (eq-plist node)
  (let ((plist
	 (hash-table/get eq-properties node #f)))
    (if plist (cons node plist) #f)))

(define (eq-clone! source target)
  (let ((plist (hash-table/get eq-properties source #f)))
    (if plist (hash-table/put! eq-properties target (list-copy plist))))))

;;; Path names are built with properties.

(define (eq-path path)
  (define (lp node)
    (if node
	(if (pair? path)
	    (eq-get ((eq-path (cdr path)) node)
		    (car path))
	    node)
	#f))
  lp)
